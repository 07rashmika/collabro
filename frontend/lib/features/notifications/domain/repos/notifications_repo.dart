import '../entities/app_notification.dart';

abstract class NotificationsRepo {
  Future<NotificationsPage> getNotifications();
  Future<void> markAllRead();
}
