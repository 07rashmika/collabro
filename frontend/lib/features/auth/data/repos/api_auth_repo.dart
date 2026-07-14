import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/secure_storage_keys.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/repos/auth_repo.dart';
import '../auth_endpoints.dart';

class ApiAuthRepo implements AuthRepo {
  final ApiClient apiClient;
  final FlutterSecureStorage storage;

  ApiAuthRepo({required this.apiClient, required this.storage});

  @override
  Future<AppUser> loginWithEmailPassword(String email, String password) async {
    try {
      final response = await apiClient.post(
        AuthEndpoints.login,
        data: {'email': email, 'password': password},
      );

      final data = response.data;
      await _persistTokens(data['accessToken'], data['refreshToken']);
      return AppUser.fromJson(data['user']);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    } catch (e) {
      throw Exception('Login failed: $e');
    }
  }

  @override
  Future<AppUser> registerWithEmailPassword(
    String name,
    String email,
    String password,
  ) async {
    try {
      final response = await apiClient.post(
        AuthEndpoints.register,
        data: {'name': name, 'email': email, 'password': password},
      );

      final data = response.data;
      await _persistTokens(data['accessToken'], data['refreshToken']);
      return AppUser.fromJson(data['user']);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    } catch (e) {
      throw Exception('Registration failed: $e');
    }
  }

  @override
  Future<void> logout() async {
    try {
      await apiClient.post(AuthEndpoints.logout);
    } catch (_) {
      // Best-effort: even if the server call fails, clear local session.
    } finally {
      await storage.deleteAll();
    }
  }

  @override
  Future<AppUser?> getCurrentUser() async {
    final token = await storage.read(key: SecureStorageKeys.accessToken);
    if (token == null) return null;

    try {
      final response = await apiClient.get(AuthEndpoints.currentUser);
      return AppUser.fromJson(response.data);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    } catch (e) {
      throw Exception('Get current user failed: $e');
    }
  }

  Future<void> _persistTokens(String access, String refresh) async {
    await storage.write(key: SecureStorageKeys.accessToken, value: access);
    await storage.write(key: SecureStorageKeys.refreshToken, value: refresh);
  }
}
