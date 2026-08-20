import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'api_config.dart';
import 'secure_storage_keys.dart';
import 'token_refresher.dart';

//single networking chokepoint: owns the base URL, attaches the access
//token to every request, unwraps the backend's response envelope (if
//present), and transparently refreshes + retries on a 401.
class ApiClient {
  final Dio _dio;
  final FlutterSecureStorage _storage;
  late final TokenRefresher _tokenRefresher;
  bool _isRefreshing = false;

  ApiClient({Dio? dio, FlutterSecureStorage? storage})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: ApiConfig.baseUrl,
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 10),
            ),
          ),
      _storage = storage ?? const FlutterSecureStorage() {
    _tokenRefresher = TokenRefresher(storage: _storage);
    debugPrint('[ApiClient] baseUrl = ${ApiConfig.baseUrl}');
    if (kDebugMode) {
      _dio.interceptors.add(
        LogInterceptor(requestBody: true, responseBody: true),
      );
    }
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _storage.read(key: SecureStorageKeys.accessToken);
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onResponse: (response, handler) {
          final data = response.data;
          if (data is Map &&
              data['success'] == true &&
              data.containsKey('data')) {
            response.data = data['data'];
          }
          handler.next(response);
        },
        onError: (error, handler) async {
          final alreadyRetried =
              error.requestOptions.extra['_hasRetried'] == true;
          if (error.response?.statusCode == 401 &&
              !_isRefreshing &&
              !alreadyRetried) {
            _isRefreshing = true;
            try {
              final refreshed = await _tokenRefresher.refresh();
              _isRefreshing = false;
              if (refreshed) {
                error.requestOptions.extra['_hasRetried'] = true;
                final retryResponse = await _dio.fetch(error.requestOptions);
                return handler.resolve(retryResponse);
              }
            } catch (_) {
              _isRefreshing = false;
              await _storage.deleteAll();
            }
          }
          handler.next(error);
        },
      ),
    );
  }

  Future<Response> get(String path, {Map<String, dynamic>? query}) =>
      _dio.get(path, queryParameters: query);

  Future<Response> post(String path, {dynamic data, Options? options}) =>
      _dio.post(path, data: data, options: options);

  Future<Response> patch(String path, {dynamic data}) =>
      _dio.patch(path, data: data);

  Future<Response> delete(String path, {dynamic data}) =>
      _dio.delete(path, data: data);
}
