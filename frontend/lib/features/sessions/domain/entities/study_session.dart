import 'package:equatable/equatable.dart';

import 'package:frontend/features/skills/domain/entities/skill.dart';

enum SessionType {
  text,
  video;

  static SessionType fromJson(String value) =>
      value == 'VIDEO' ? SessionType.video : SessionType.text;

  String toJson() => this == SessionType.video ? 'VIDEO' : 'TEXT';
}

enum SessionStatus {
  active,
  closed;

  static SessionStatus fromJson(String value) =>
      value == 'CLOSED' ? SessionStatus.closed : SessionStatus.active;
}

class SessionParticipant extends Equatable {
  final String userId;
  final String name;
  final String email;
  final DateTime joinedAt;

  const SessionParticipant({
    required this.userId,
    required this.name,
    required this.email,
    required this.joinedAt,
  });

  factory SessionParticipant.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>;
    return SessionParticipant(
      userId: user['id'] as String,
      name: user['name'] as String,
      email: user['email'] as String,
      joinedAt: DateTime.parse(json['joinedAt'] as String),
    );
  }

  @override
  List<Object?> get props => [userId, name, email, joinedAt];
}

class StudySession extends Equatable {
  final String id;
  final String title;
  final SessionType type;
  final SessionStatus status;
  final String? summary;
  final String creatorId;
  final String creatorName;
  final List<SessionParticipant> participants;
  final int messageCount;
  final DateTime? scheduledAt;
  // Null for a private session viewed by a non-creator — the backend only
  // sends the join code to the creator, or to anyone if the session is public.
  final String? joinCode;
  final bool hasPassword;
  final bool isPublic;
  final bool savedByMe;
  final List<Skill> tags;
  final DateTime createdAt;
  final DateTime updatedAt;

  const StudySession({
    required this.id,
    required this.title,
    required this.type,
    required this.status,
    required this.creatorId,
    required this.creatorName,
    required this.participants,
    required this.messageCount,
    required this.hasPassword,
    required this.isPublic,
    required this.savedByMe,
    required this.tags,
    required this.createdAt,
    required this.updatedAt,
    this.summary,
    this.scheduledAt,
    this.joinCode,
  });

  StudySession copyWith({bool? savedByMe}) {
    return StudySession(
      id: id,
      title: title,
      type: type,
      status: status,
      creatorId: creatorId,
      creatorName: creatorName,
      participants: participants,
      messageCount: messageCount,
      hasPassword: hasPassword,
      isPublic: isPublic,
      savedByMe: savedByMe ?? this.savedByMe,
      tags: tags,
      createdAt: createdAt,
      updatedAt: updatedAt,
      summary: summary,
      scheduledAt: scheduledAt,
      joinCode: joinCode,
    );
  }

  factory StudySession.fromJson(Map<String, dynamic> json) {
    final creator = json['creator'] as Map<String, dynamic>;
    return StudySession(
      id: json['id'] as String,
      title: json['title'] as String,
      type: SessionType.fromJson(json['type'] as String),
      status: SessionStatus.fromJson(json['status'] as String),
      summary: json['summary'] as String?,
      creatorId: creator['id'] as String,
      creatorName: creator['name'] as String,
      participants: ((json['participants'] as List<dynamic>?) ?? [])
          .map((p) => SessionParticipant.fromJson(p as Map<String, dynamic>))
          .toList(),
      messageCount: (json['_count'] as Map<String, dynamic>?)?['messages'] as int? ?? 0,
      scheduledAt: json['scheduledAt'] != null ? DateTime.parse(json['scheduledAt'] as String) : null,
      joinCode: json['joinCode'] as String?,
      hasPassword: json['hasPassword'] as bool? ?? false,
      isPublic: json['isPublic'] as bool? ?? false,
      savedByMe: json['savedByMe'] as bool? ?? false,
      tags: ((json['tags'] as List<dynamic>?) ?? [])
          .map((t) => Skill.fromJson(t as Map<String, dynamic>))
          .toList(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  @override
  List<Object?> get props => [
    id,
    title,
    type,
    status,
    summary,
    creatorId,
    creatorName,
    participants,
    messageCount,
    scheduledAt,
    joinCode,
    hasPassword,
    isPublic,
    savedByMe,
    tags,
    createdAt,
    updatedAt,
  ];
}
