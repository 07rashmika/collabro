import 'package:equatable/equatable.dart';

enum AppNotificationType {
  connectionRequest,
  connectionAccepted,
  sessionInvite,
}

class AppNotification extends Equatable {
  final String id;
  final AppNotificationType type;
  final bool isRead;
  final DateTime createdAt;
  final String? connectionId;
  final String? connectionStatus;
  final String? sessionId;
  final String? sessionTitle;
  final String actorId;
  final String actorName;

  const AppNotification({
    required this.id,
    required this.type,
    required this.isRead,
    required this.createdAt,
    required this.actorId,
    required this.actorName,
    this.connectionId,
    this.connectionStatus,
    this.sessionId,
    this.sessionTitle,
  });

  bool get isActionableRequest =>
      type == .connectionRequest && connectionStatus == 'PENDING';

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final actor = json['actor'] as Map<String, dynamic>;
    final connection = json['connection'] as Map<String, dynamic>?;
    final session = json['session'] as Map<String, dynamic>?;
    final type = switch (json['type']) {
      'CONNECTION_REQUEST' => AppNotificationType.connectionRequest,
      'SESSION_INVITE' => AppNotificationType.sessionInvite,
      _ => AppNotificationType.connectionAccepted,
    };
    return AppNotification(
      id: json['id'] as String,
      type: type,
      isRead: json['isRead'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
      connectionId: json['connectionId'] as String?,
      connectionStatus: connection?['status'] as String?,
      sessionId: json['sessionId'] as String?,
      sessionTitle: session?['title'] as String?,
      actorId: actor['id'] as String,
      actorName: actor['name'] as String,
    );
  }

  @override
  List<Object?> get props => [
    id,
    type,
    isRead,
    createdAt,
    connectionId,
    connectionStatus,
    sessionId,
    sessionTitle,
    actorId,
    actorName,
  ];
}

class NotificationsPage extends Equatable {
  final List<AppNotification> notifications;
  final int unreadCount;

  const NotificationsPage({
    required this.notifications,
    required this.unreadCount,
  });

  @override
  List<Object?> get props => [notifications, unreadCount];
}
