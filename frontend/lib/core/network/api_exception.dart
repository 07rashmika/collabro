import 'package:dio/dio.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, {this.statusCode});

  factory ApiException.fromDioError(DioException e) {
    if (e.response == null) {
      final isTimeout = e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.connectionError;
      return ApiException(
        isTimeout
            ? 'Could not connect to the server. Check your connection and try again.'
            : 'Something went wrong. Please try again.',
      );
    }

    return ApiException(
      _extractMessage(e.response!.data),
      statusCode: e.response!.statusCode,
    );
  }

  static String _extractMessage(dynamic data) {
    if (data is! Map) return 'Something went wrong. Please try again.';

    // Zod's z.treeifyError shape: { errors: [...], properties: { field: { errors: [...] } } }
    final errors = data['errors'];
    if (errors is Map) {
      final properties = errors['properties'];
      if (properties is Map) {
        for (final value in properties.values) {
          if (value is Map &&
              value['errors'] is List &&
              (value['errors'] as List).isNotEmpty) {
            return (value['errors'] as List).first.toString();
          }
        }
      }
      if (errors['errors'] is List && (errors['errors'] as List).isNotEmpty) {
        return (errors['errors'] as List).first.toString();
      }
    }

    if (data['message'] != null) return data['message'].toString();
    return 'Something went wrong. Please try again.';
  }

  @override
  String toString() => message;
}
