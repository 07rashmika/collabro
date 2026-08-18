import 'package:equatable/equatable.dart';

class ProfileSkillEntry extends Equatable {
  final String skillId;
  final String name;
  final String category;
  final String level;

  const ProfileSkillEntry({
    required this.skillId,
    required this.name,
    required this.category,
    required this.level,
  });

  factory ProfileSkillEntry.fromJson(Map<String, dynamic> json) {
    final skill = json['skill'] as Map<String, dynamic>;
    return ProfileSkillEntry(
      skillId: skill['id'] as String,
      name: skill['name'] as String,
      category: skill['category'] as String,
      level: json['level'] as String,
    );
  }

  @override
  List<Object?> get props => [skillId, name, category, level];
}

class ProfileStudyAreaEntry extends Equatable {
  final String studyAreaId;
  final String name;

  const ProfileStudyAreaEntry({required this.studyAreaId, required this.name});

  factory ProfileStudyAreaEntry.fromJson(Map<String, dynamic> json) {
    final studyArea = json['studyArea'] as Map<String, dynamic>;
    return ProfileStudyAreaEntry(
      studyAreaId: studyArea['id'] as String,
      name: studyArea['name'] as String,
    );
  }

  @override
  List<Object?> get props => [studyAreaId, name];
}

class Profile extends Equatable {
  final String? bio;
  final String? learningGoal;
  final String? teachGoal;
  final List<String> interests;
  final List<ProfileSkillEntry> skills;
  final List<ProfileStudyAreaEntry> studyAreas;

  const Profile({
    this.bio,
    this.learningGoal,
    this.teachGoal,
    this.interests = const [],
    this.skills = const [],
    this.studyAreas = const [],
  });

  bool get isComplete =>
      skills.isNotEmpty && studyAreas.isNotEmpty && interests.isNotEmpty;

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      bio: json['bio'] as String?,
      learningGoal: json['learningGoal'] as String?,
      teachGoal: json['teachGoal'] as String?,
      interests: ((json['interests'] as List<dynamic>?) ?? [])
          .map((e) => e.toString())
          .toList(),
      skills: ((json['skills'] as List<dynamic>?) ?? [])
          .map((s) => ProfileSkillEntry.fromJson(s as Map<String, dynamic>))
          .toList(),
      studyAreas: ((json['studyAreas'] as List<dynamic>?) ?? [])
          .map((s) => ProfileStudyAreaEntry.fromJson(s as Map<String, dynamic>))
          .toList(),
    );
  }

  @override
  List<Object?> get props => [
    bio,
    learningGoal,
    teachGoal,
    interests,
    skills,
    studyAreas,
  ];
}
