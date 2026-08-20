import 'package:dio/dio.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';
import '../../domain/entities/app_notification.dart';
import '../../domain/repos/notifications_repo.dart';
import '../notifications_endpoints.dart';

class ApiNotificationsRepo implements NotificationsRepo {
  final ApiClient apiClient;

  ApiNotificationsRepo({required this.apiClient});

  @override
  Future<NotificationsPage> getNotifications() async {
    try {
      final response = await apiClient.get(NotificationsEndpoints.base);
      final notifications =
          (response.data['notifications'] as List<dynamic>?) ?? [];
      return NotificationsPage(
        notifications: notifications
            .map((n) => AppNotification.fromJson(n as Map<String, dynamic>))
            .toList(),
        unreadCount: (response.data['unreadCount'] as num?)?.toInt() ?? 0,
      );
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    } catch (e) {
      throw Exception('Fetching notifications failed: $e');
    }
  }

  @override
  Future<void> markAllRead() async {
    try {
      await apiClient.patch(NotificationsEndpoints.readAll);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    } catch (e) {
      throw Exception('Marking notifications read failed: $e');
    }
  }
}
