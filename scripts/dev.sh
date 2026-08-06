#!/usr/bin/env bash
# Runs the backend API, the ml-service summarizer, and the Flutter app on
# whichever Android/iOS emulator(s) or physical device(s) are currently
# connected, together — so the summarization feature doesn't fail just
# because ml-service was never started, and the mobile app doesn't need a
# separate `flutter run` per device. Ctrl+C stops everything.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKEND_DIR="$ROOT_DIR/backend"
ML_DIR="$ROOT_DIR/ml-service"
FRONTEND_DIR="$ROOT_DIR/frontend"

if [ ! -x "$ML_DIR/.venv/bin/uvicorn" ]; then
  echo "error: ml-service virtualenv not found at $ML_DIR/.venv" >&2
  echo "       set it up first — see ml-service/README.md" >&2
  exit 1
fi

if [ ! -d "$BACKEND_DIR/node_modules" ]; then
  echo "error: backend dependencies not installed — run 'npm install' in backend/ first" >&2
  exit 1
fi

# `kill 0` (send to this script's own process group) catches most of what
# we background below, but npm/nodemon specifically detach `ts-node` into a
# *new* process group of their own to manage restarts — a plain `kill 0`
# leaves that one running after this script exits. So every backgrounded
# job's PID is tracked and killed two ways on exit: once as `-$pid` (reaches
# a detached job's own group, since a detached process's pgid equals its
# own pid) and once as a plain `$pid` (covers jobs that stayed in this
# script's group, where `-$pid` wouldn't resolve to anything) — plus `kill 0`
# as a final catch-all.
pids=()
reversed_serials=()
cleanup() {
  for serial in "${reversed_serials[@]:-}"; do
    [ -z "$serial" ] && continue
    adb -s "$serial" reverse --remove tcp:3000 2>/dev/null || true
  done
  for pid in "${pids[@]:-}"; do
    [ -z "$pid" ] && continue
    kill -- "-$pid" 2>/dev/null || true
    kill "$pid" 2>/dev/null || true
  done
  kill 0 2>/dev/null || true
}
trap cleanup EXIT INT TERM

(cd "$ML_DIR" && exec .venv/bin/uvicorn main:app --port 8000) &
pids+=("$!")
(cd "$BACKEND_DIR" && exec npm run dev) &
pids+=("$!")

# The app's default API base URL (see frontend/lib/core/network/api_config.dart)
# is 10.0.2.2 for Android or localhost otherwise — both are loopback aliases
# that only resolve to *this* machine from an emulator/simulator, which
# shares its network stack with the host. A physical device is a separate
# machine that needs a different way to reach the host:
#   - Android: `adb reverse` tunnels the device's own localhost:3000 to this
#     host's localhost:3000 over the existing USB/adb connection — works
#     regardless of Wi-Fi topology (different subnet, AP client isolation,
#     phone on mobile data, etc.), so it's used unconditionally over guessing
#     a LAN IP.
#   - iOS: no USB-tunnel equivalent here, so it falls back to this host's LAN
#     IP — only works if the device is actually on the same, non-isolated
#     network as this machine.
LAN_IP="$(hostname -I 2>/dev/null | awk '{print $1}')"
if [ -z "$LAN_IP" ]; then
  echo "[dev.sh] Could not detect a LAN IP — a physical iOS device will fail to reach the backend." >&2
  echo "          Find it yourself (e.g. 'ip addr') and run:" >&2
  echo "          cd frontend && flutter run -d <device_id> --dart-define=API_BASE_URL=http://<your-lan-ip>:3000" >&2
fi

# Only Android/iOS targets count as "the mobile app" here — `flutter
# devices` also lists desktop/web targets (linux, chrome, ...) which this
# script has no business auto-launching.
if ! command -v flutter >/dev/null 2>&1; then
  echo "[dev.sh] flutter not found on PATH — skipping mobile app launch." >&2
elif ! flutter_devices_json="$(flutter devices --machine 2>/dev/null)"; then
  echo "[dev.sh] 'flutter devices' failed — skipping mobile app launch." >&2
else
  # id<TAB>platform<TAB>isPhysical, so a physical device (isPhysical=1) can
  # be pointed at the host below while an emulator/simulator (isPhysical=0)
  # keeps the working default.
  mobile_devices="$(python3 -c '
import json, sys
try:
    devices = json.loads(sys.argv[1])
except Exception:
    devices = []
for d in devices:
    platform = d.get("targetPlatform") or ""
    if platform.startswith("android") or platform.startswith("ios"):
        device_id = d["id"]
        is_physical = 0 if d.get("emulator") else 1
        print(f"{device_id}\t{platform}\t{is_physical}")
' "$flutter_devices_json")"

  if [ -z "$mobile_devices" ]; then
    echo "[dev.sh] No Android/iOS emulator or device connected — start one and re-run to launch the app automatically (backend + ml-service still started)." >&2
  else
    while IFS=$'\t' read -r device_id platform is_physical; do
      [ -z "$device_id" ] && continue
      run_args=(-d "$device_id")
      if [ "$is_physical" = "1" ] && [[ "$platform" == android* ]] && command -v adb >/dev/null 2>&1; then
        if adb -s "$device_id" reverse tcp:3000 tcp:3000 2>/dev/null; then
          reversed_serials+=("$device_id")
          run_args+=(--dart-define="API_BASE_URL=http://localhost:3000")
          echo "[dev.sh] Launching Flutter app on physical Android device: $device_id (tunneled to localhost:3000 via adb reverse)"
        else
          echo "[dev.sh] 'adb reverse' failed for $device_id — falling back to LAN IP, which only works if it's on the same, non-isolated network." >&2
          run_args+=(--dart-define="API_BASE_URL=http://$LAN_IP:3000")
        fi
      elif [ "$is_physical" = "1" ] && [ -n "$LAN_IP" ]; then
        run_args+=(--dart-define="API_BASE_URL=http://$LAN_IP:3000")
        echo "[dev.sh] Launching Flutter app on physical device: $device_id (API_BASE_URL=http://$LAN_IP:3000)"
      else
        echo "[dev.sh] Launching Flutter app on device: $device_id"
      fi
      # A plain backgrounded `flutter run` gets stdin redirected to
      # /dev/null (bash's standard behavior for async jobs in a script) —
      # flutter_tools expects a real terminal and can misbehave (seen
      # in practice: it can silently die right after installing the APK,
      # with no error printed) without one. `script` allocates a
      # pseudo-terminal for it, which fixes this without needing actual
      # keyboard input. Interactive hot-reload keys (r/R) still won't reach
      # it — Ctrl+C via this script tears it down cleanly either way; for
      # interactive hot reload, run `flutter run -d <device_id>` yourself
      # in its own terminal instead.
      if command -v script >/dev/null 2>&1; then
        (cd "$FRONTEND_DIR" && exec script -qec "flutter run $(printf '%q ' "${run_args[@]}")" /dev/null) &
      else
        (cd "$FRONTEND_DIR" && exec flutter run "${run_args[@]}") &
      fi
      pids+=("$!")
    done <<< "$mobile_devices"
  fi
fi

wait
