import 'package:flutter/foundation.dart';

class ApiConfig {
  // Backend mounts feature routes directly at root (e.g. /auth, /users) —
  // there is no /api prefix.
  //
  // 'localhost' only reaches the host machine from the host itself. The
  // Android emulator's own loopback is 10.0.2.2; iOS simulators and desktop
  // share the host's network stack so 'localhost' works there. Override
  // with --dart-define=API_BASE_URL=... for a physical device (use your
  // machine's LAN IP) or a real backend.
  static const String _override = String.fromEnvironment('API_BASE_URL');

  static final String baseUrl = _override.isNotEmpty
      ? _override
      : (!kIsWeb && defaultTargetPlatform == TargetPlatform.android)
      ? 'http://10.0.2.2:3000'
      : 'http://localhost:3000';
}
