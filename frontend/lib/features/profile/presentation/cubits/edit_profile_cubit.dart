import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../auth/domain/entities/app_user.dart';
import '../../../auth/domain/repos/auth_repo.dart';
import '../../../profiles/domain/entities/profile.dart';
import '../../../profiles/domain/repos/profiles_repo.dart';
import '../../../skills/domain/entities/skill.dart';
import '../../../skills/domain/repos/skills_repo.dart';
import '../../../study_areas/domain/entities/study_area.dart';
import '../../../study_areas/domain/repos/study_areas_repo.dart';
import '../../../users/domain/repos/users_repo.dart';

part 'edit_profile_state.dart';

const _levelCycle = ['BEGINNER', 'INTERMEDIATE', 'ADVANCED'];

class EditProfileCubit extends Cubit<EditProfileState> {
  final SkillsRepo skillsRepo;
  final StudyAreasRepo studyAreasRepo;
  final ProfilesRepo profilesRepo;
  final AuthRepo authRepo;
  final UsersRepo usersRepo;

  EditProfileCubit({
    required this.skillsRepo,
    required this.studyAreasRepo,
    required this.profilesRepo,
    required this.authRepo,
    required this.usersRepo,
  }) : super(const EditProfileLoading());

  Future<void> load() async {
    emit(const EditProfileLoading());
    try {
      final results = await Future.wait([
        skillsRepo.getAllSkills(),
        studyAreasRepo.getAllStudyAreas(),
        profilesRepo.getMyProfile(),
        authRepo.getCurrentUser(),
      ]);
      final profile = results[2] as Profile?;
      final user = results[3] as AppUser?;

      final skillLevels = <String, String>{
        for (final s in profile?.skills ?? const []) s.skillId: s.level,
      };
      final studyAreaIds = <String>{
        for (final a in profile?.studyAreas ?? const []) a.studyAreaId,
      };

      emit(
        EditProfileReady(
          allSkills: results[0] as List<Skill>,
          allStudyAreas: results[1] as List<StudyArea>,
          selectedSkillLevels: skillLevels,
          originalSkillLevels: skillLevels,
          selectedStudyAreaIds: studyAreaIds,
          originalStudyAreaIds: studyAreaIds,
          interests: profile?.interests ?? const [],
          bio: profile?.bio ?? '',
          learningGoal: profile?.learningGoal ?? '',
          teachGoal: profile?.teachGoal ?? '',
          userName: user?.name ?? '',
          avatarUrl: user?.avatarUrl,
        ),
      );
    } catch (e) {
      emit(EditProfileLoadError(e.toString().replaceFirst('Exception: ', '')));
    }
  }

  Future<void> uploadAvatar(String imagePath) async {
    final current = state;
    if (current is! EditProfileReady) return;

    emit(current.copyWith(avatarUploading: true, clearAvatarError: true));
    try {
      final user = await usersRepo.uploadAvatar(imagePath);
      final latest = state;
      if (latest is! EditProfileReady) return;
      emit(latest.copyWith(avatarUrl: user.avatarUrl, avatarUploading: false));
    } catch (e) {
      final latest = state;
      if (latest is! EditProfileReady) return;
      emit(
        latest.copyWith(
          avatarUploading: false,
          avatarError: e.toString().replaceFirst('Exception: ', ''),
        ),
      );
    }
  }

  Future<void> removeAvatar() async {
    final current = state;
    if (current is! EditProfileReady || current.avatarUrl == null) return;

    emit(current.copyWith(avatarUploading: true, clearAvatarError: true));
    try {
      await usersRepo.deleteAvatar();
      final latest = state;
      if (latest is! EditProfileReady) return;
      emit(
        latest.copyWith(avatarUploading: false, clearAvatarUrl: true),
      );
    } catch (e) {
      final latest = state;
      if (latest is! EditProfileReady) return;
      emit(
        latest.copyWith(
          avatarUploading: false,
          avatarError: e.toString().replaceFirst('Exception: ', ''),
        ),
      );
    }
  }

  void selectSkill(Skill skill) {
    final current = state;
    if (current is! EditProfileReady) return;
    if (current.selectedSkillLevels.containsKey(skill.id)) return;

    final levels = Map<String, String>.from(current.selectedSkillLevels)
      ..[skill.id] = _levelCycle.first;
    emit(current.copyWith(selectedSkillLevels: levels));
  }

  int _searchToken = 0;

  Future<void> searchSkills(String query) async {
    final current = state;
    if (current is! EditProfileReady) return;

    final token = ++_searchToken;
    if (query.trim().isEmpty) {
      emit(
        current.copyWith(
          remoteSkillSuggestions: const [],
          remoteSkillsBusy: false,
        ),
      );
      return;
    }

    emit(current.copyWith(remoteSkillsBusy: true));
    try {
      final results = await skillsRepo.searchSkills(query);
      if (token != _searchToken) return;
      final latest = state;
      if (latest is! EditProfileReady) return;
      emit(
        latest.copyWith(
          remoteSkillSuggestions: results,
          remoteSkillsBusy: false,
        ),
      );
    } catch (_) {
      if (token != _searchToken) return;
      final latest = state;
      if (latest is! EditProfileReady) return;

      emit(
        latest.copyWith(
          remoteSkillSuggestions: const [],
          remoteSkillsBusy: false,
        ),
      );
    }
  }

  Future<void> createAndSelectSkill(String name) async {
    final current = state;
    if (current is! EditProfileReady) return;

    emit(current.copyWith(catalogBusy: true, clearCatalogError: true));
    try {
      final skill = await skillsRepo.findOrCreateSkill(name);
      final latest = state;
      if (latest is! EditProfileReady) return;

      final skills = latest.allSkills.any((s) => s.id == skill.id)
          ? latest.allSkills
          : [...latest.allSkills, skill];
      final levels = Map<String, String>.from(latest.selectedSkillLevels)
        ..[skill.id] = _levelCycle.first;

      emit(
        latest.copyWith(
          allSkills: skills,
          selectedSkillLevels: levels,
          catalogBusy: false,
        ),
      );
    } catch (e) {
      final latest = state;
      if (latest is! EditProfileReady) return;
      emit(
        latest.copyWith(
          catalogBusy: false,
          catalogError: e.toString().replaceFirst('Exception: ', ''),
        ),
      );
    }
  }

  void cycleSkillLevel(String skillId) {
    final current = state;
    if (current is! EditProfileReady) return;

    final levels = Map<String, String>.from(current.selectedSkillLevels);
    final existing = levels[skillId];
    if (existing == null) return;

    final nextIndex = _levelCycle.indexOf(existing) + 1;
    if (nextIndex >= _levelCycle.length) {
      levels.remove(skillId);
    } else {
      levels[skillId] = _levelCycle[nextIndex];
    }

    emit(current.copyWith(selectedSkillLevels: levels));
  }

  void selectStudyArea(StudyArea studyArea) {
    final current = state;
    if (current is! EditProfileReady) return;
    if (current.selectedStudyAreaIds.contains(studyArea.id)) return;

    final ids = Set<String>.from(current.selectedStudyAreaIds)
      ..add(studyArea.id);
    emit(current.copyWith(selectedStudyAreaIds: ids));
  }

  Future<void> createAndSelectStudyArea(String name) async {
    final current = state;
    if (current is! EditProfileReady) return;

    emit(current.copyWith(catalogBusy: true, clearCatalogError: true));
    try {
      final studyArea = await studyAreasRepo.findOrCreateStudyArea(name);
      final latest = state;
      if (latest is! EditProfileReady) return;

      final studyAreas = latest.allStudyAreas.any((s) => s.id == studyArea.id)
          ? latest.allStudyAreas
          : [...latest.allStudyAreas, studyArea];
      final ids = Set<String>.from(latest.selectedStudyAreaIds)
        ..add(studyArea.id);

      emit(
        latest.copyWith(
          allStudyAreas: studyAreas,
          selectedStudyAreaIds: ids,
          catalogBusy: false,
        ),
      );
    } catch (e) {
      final latest = state;
      if (latest is! EditProfileReady) return;
      emit(
        latest.copyWith(
          catalogBusy: false,
          catalogError: e.toString().replaceFirst('Exception: ', ''),
        ),
      );
    }
  }

  void removeStudyArea(String studyAreaId) {
    final current = state;
    if (current is! EditProfileReady) return;

    final ids = Set<String>.from(current.selectedStudyAreaIds)
      ..remove(studyAreaId);
    emit(current.copyWith(selectedStudyAreaIds: ids));
  }

  void addInterest(String interest) {
    final current = state;
    if (current is! EditProfileReady) return;

    emit(current.copyWith(interests: [...current.interests, interest]));
  }

  void removeInterest(String interest) {
    final current = state;
    if (current is! EditProfileReady) return;

    emit(
      current.copyWith(
        interests: current.interests.where((i) => i != interest).toList(),
      ),
    );
  }

  Future<void> submit({
    required String bio,
    required String learningGoal,
    required String teachGoal,
  }) async {
    final current = state;
    if (current is! EditProfileReady || !current.canSubmit) return;

    emit(current.copyWith(isSubmitting: true, clearSubmitError: true));
    try {
      final mutations = <Future<dynamic>>[
        profilesRepo.updateProfile(
          bio: bio,
          learningGoal: learningGoal,
          teachGoal: teachGoal,
          interests: current.interests,
        ),
      ];

      for (final entry in current.selectedSkillLevels.entries) {
        if (current.originalSkillLevels[entry.key] != entry.value) {
          mutations.add(
            profilesRepo.addSkill(skillId: entry.key, level: entry.value),
          );
        }
      }
      for (final skillId in current.originalSkillLevels.keys) {
        if (!current.selectedSkillLevels.containsKey(skillId)) {
          mutations.add(profilesRepo.removeSkill(skillId));
        }
      }

      for (final id in current.selectedStudyAreaIds) {
        if (!current.originalStudyAreaIds.contains(id)) {
          mutations.add(profilesRepo.addStudyArea(id));
        }
      }
      for (final id in current.originalStudyAreaIds) {
        if (!current.selectedStudyAreaIds.contains(id)) {
          mutations.add(profilesRepo.removeStudyArea(id));
        }
      }

      await Future.wait(mutations);
      emit(current.copyWith(isSubmitting: false, submitted: true));
    } catch (e) {
      emit(
        current.copyWith(
          isSubmitting: false,
          submitError: e.toString().replaceFirst('Exception: ', ''),
        ),
      );
    }
  }
}
