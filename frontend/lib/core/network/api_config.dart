import 'package:flutter/foundation.dart';

class ApiConfig {
  static const String _override = .fromEnvironment('API_BASE_URL');

  static final String baseUrl = _override.isNotEmpty
      ? _override
      : (!kIsWeb && defaultTargetPlatform == .android)
      ? 'http://10.0.2.2:3000'
      : 'http://localhost:3000';
}
