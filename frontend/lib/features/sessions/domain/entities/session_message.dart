import 'package:equatable/equatable.dart';

class SessionMessage extends Equatable {
  final String id;
  final String sessionId;
  final String content;
  final String senderId;
  final String senderName;
  final String? senderAvatarUrl;
  final DateTime createdAt;

  const SessionMessage({
    required this.id,
    required this.sessionId,
    required this.content,
    required this.senderId,
    required this.senderName,
    this.senderAvatarUrl,
    required this.createdAt,
  });

  factory SessionMessage.fromJson(
    Map<String, dynamic> json, {
    required String sessionId,
  }) {
    final sender = json['sender'] as Map<String, dynamic>;
    return SessionMessage(
      id: json['id'] as String,
      sessionId: sessionId,
      content: json['content'] as String,
      senderId: sender['id'] as String,
      senderName: sender['name'] as String,
      senderAvatarUrl: sender['avatarUrl'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  factory SessionMessage.fromSignalingJson(Map<String, dynamic> json) {
    return SessionMessage(
      id: json['id'] as String,
      sessionId: json['sessionId'] as String,
      content: json['content'] as String,
      senderId: json['senderId'] as String,
      senderName: json['senderName'] as String,
      senderAvatarUrl: json['senderAvatarUrl'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  @override
  List<Object?> get props => [
    id,
    sessionId,
    content,
    senderId,
    senderName,
    senderAvatarUrl,
    createdAt,
  ];
}
