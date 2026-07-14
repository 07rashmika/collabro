import '../entities/profile.dart';

class ProfileSkillInput {
  final String skillId;
  final String level;

  const ProfileSkillInput({required this.skillId, required this.level});
}

abstract class ProfilesRepo {
  /// Returns null if the caller has no profile yet (fresh signup).
  Future<Profile?> getMyProfile();

  Future<Profile> createProfile({
    String? bio,
    String? learningGoal,
    String? teachGoal,
    List<String>? interests,
    List<ProfileSkillInput>? skills,
    List<String>? studyAreaIds,
  });

  Future<Profile> updateProfile({
    String? bio,
    String? learningGoal,
    String? teachGoal,
    List<String>? interests,
  });

  Future<void> addSkill({required String skillId, required String level});

  Future<void> removeSkill(String skillId);

  Future<void> addStudyArea(String studyAreaId);

  Future<void> removeStudyArea(String studyAreaId);
}
