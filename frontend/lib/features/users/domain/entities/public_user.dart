import 'package:equatable/equatable.dart';
import 'package:frontend/features/profiles/domain/entities/profile.dart';

class PublicUser extends Equatable {
  final String id;
  final String name;
  final String email;
  final String? bio;
  final String? learningGoal;
  final String? teachGoal;
  final List<String> interests;
  final List<ProfileSkillEntry> skills;
  final List<ProfileStudyAreaEntry> studyAreas;
  final int notesCount;
  final int sessionsCount;
  final String connectionStatus;

  const PublicUser({
    required this.id,
    required this.name,
    required this.email,
    this.bio,
    this.learningGoal,
    this.teachGoal,
    this.interests = const [],
    this.skills = const [],
    this.studyAreas = const [],
    this.notesCount = 0,
    this.sessionsCount = 0,
    this.connectionStatus = 'NONE',
  });

  factory PublicUser.fromJson(Map<String, dynamic> json) {
    final profile = json['profile'] as Map<String, dynamic>?;
    final count = json['_count'] as Map<String, dynamic>?;
    return PublicUser(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      bio: profile?['bio'] as String?,
      learningGoal: profile?['learningGoal'] as String?,
      teachGoal: profile?['teachGoal'] as String?,
      interests: ((profile?['interests'] as List<dynamic>?) ?? [])
          .map((e) => e.toString())
          .toList(),
      skills: ((profile?['skills'] as List<dynamic>?) ?? [])
          .map((s) => ProfileSkillEntry.fromJson(s as Map<String, dynamic>))
          .toList(),
      studyAreas: ((profile?['studyAreas'] as List<dynamic>?) ?? [])
          .map((s) => ProfileStudyAreaEntry.fromJson(s as Map<String, dynamic>))
          .toList(),
      notesCount: (count?['notes'] as num?)?.toInt() ?? 0,
      sessionsCount: (count?['createdSessions'] as num?)?.toInt() ?? 0,
      connectionStatus: json['connectionStatus'] as String? ?? 'NONE',
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    email,
    bio,
    learningGoal,
    teachGoal,
    interests,
    skills,
    studyAreas,
    notesCount,
    sessionsCount,
    connectionStatus,
  ];
}
