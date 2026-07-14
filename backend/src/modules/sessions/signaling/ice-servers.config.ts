// STUN-only ICE configuration — no TURN relay. Calls between two clients on
// restrictive/carrier-grade NATs may fail to connect; acceptable for now and
// swappable later (e.g. for a TURN provider) without an app release since
// this is served to clients, never hardcoded on the frontend.
export const ICE_SERVERS = [
  { urls: "stun:stun.l.google.com:19302" },
  { urls: "stun:stun1.l.google.com:19302" },
];
