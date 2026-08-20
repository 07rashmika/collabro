import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'api_config.dart';
import 'secure_storage_keys.dart';

class TokenRefresher {
  final FlutterSecureStorage storage;

  const TokenRefresher({required this.storage});

  Future<bool> refresh() async {
    final refreshToken = await storage.read(
      key: SecureStorageKeys.refreshToken,
    );
    if (refreshToken == null) return false;

    try {
      final response = await Dio(
        BaseOptions(baseUrl: ApiConfig.baseUrl),
      ).post('/auth/refresh', data: {'refreshToken': refreshToken});
      final newAccess = response.data['accessToken'] as String;
      final newRefresh = response.data['refreshToken'] as String;
      await storage.write(key: SecureStorageKeys.accessToken, value: newAccess);
      await storage.write(
        key: SecureStorageKeys.refreshToken,
        value: newRefresh,
      );
      return true;
    } catch (e) {
      return false;
    }
  }
}
