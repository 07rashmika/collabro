import 'package:equatable/equatable.dart';

import 'package:frontend/features/profiles/domain/entities/profile.dart';

/// Another student's public-facing info, as returned by `GET /users` — used
/// by the Discovery tab's Users search. Distinct from [Profile], which is
/// scoped to the signed-in caller's own profile CRUD.
class PublicUser extends Equatable {
  final String id;
  final String name;
  final String email;
  final String? bio;
  final List<ProfileSkillEntry> skills;
  final List<ProfileStudyAreaEntry> studyAreas;
  final int notesCount;
  final int sessionsCount;

  const PublicUser({
    required this.id,
    required this.name,
    required this.email,
    this.bio,
    this.skills = const [],
    this.studyAreas = const [],
    this.notesCount = 0,
    this.sessionsCount = 0,
  });

  factory PublicUser.fromJson(Map<String, dynamic> json) {
    final profile = json['profile'] as Map<String, dynamic>?;
    final count = json['_count'] as Map<String, dynamic>?;
    return PublicUser(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      bio: profile?['bio'] as String?,
      skills: ((profile?['skills'] as List<dynamic>?) ?? [])
          .map((s) => ProfileSkillEntry.fromJson(s as Map<String, dynamic>))
          .toList(),
      studyAreas: ((profile?['studyAreas'] as List<dynamic>?) ?? [])
          .map((s) => ProfileStudyAreaEntry.fromJson(s as Map<String, dynamic>))
          .toList(),
      notesCount: (count?['notes'] as num?)?.toInt() ?? 0,
      sessionsCount: (count?['createdSessions'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    email,
    bio,
    skills,
    studyAreas,
    notesCount,
    sessionsCount,
  ];
}
