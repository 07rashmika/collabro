import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/api_exception.dart';
import '../../../profiles/domain/repos/profiles_repo.dart';
import '../../../skills/domain/entities/skill.dart';
import '../../../skills/domain/repos/skills_repo.dart';
import '../../../study_areas/domain/entities/study_area.dart';
import '../../../study_areas/domain/repos/study_areas_repo.dart';
import '../../../users/domain/repos/users_repo.dart';

part 'profile_setup_state.dart';

const _levelCycle = ['BEGINNER', 'INTERMEDIATE', 'ADVANCED'];

class ProfileSetupCubit extends Cubit<ProfileSetupState> {
  final SkillsRepo skillsRepo;
  final StudyAreasRepo studyAreasRepo;
  final ProfilesRepo profilesRepo;
  final UsersRepo usersRepo;

  ProfileSetupCubit({
    required this.skillsRepo,
    required this.studyAreasRepo,
    required this.profilesRepo,
    required this.usersRepo,
  }) : super(const ProfileSetupLoading());

  Future<void> loadCatalogs() async {
    emit(const ProfileSetupLoading());
    try {
      final results = await Future.wait([
        skillsRepo.getAllSkills(),
        studyAreasRepo.getAllStudyAreas(),
      ]);
      emit(
        ProfileSetupReady(
          allSkills: results[0] as List<Skill>,
          allStudyAreas: results[1] as List<StudyArea>,
        ),
      );
    } catch (e) {
      emit(ProfileSetupLoadError(e.toString().replaceFirst('Exception: ', '')));
    }
  }

  void nextStep() {
    final current = state;
    if (current is! ProfileSetupReady || !current.canAdvance) return;
    if (current.currentStep >= kProfileSetupStepCount - 1) return;

    emit(current.copyWith(currentStep: current.currentStep + 1));
  }

  void previousStep() {
    final current = state;
    if (current is! ProfileSetupReady || current.currentStep <= 0) return;

    emit(current.copyWith(currentStep: current.currentStep - 1));
  }

  /// Selecting an existing catalog suggestion — added at Beginner by
  /// default; tap the resulting chip to cycle its level.
  void selectSkill(Skill skill) {
    final current = state;
    if (current is! ProfileSetupReady) return;
    if (current.selectedSkillLevels.containsKey(skill.id)) return;

    final levels = Map<String, String>.from(current.selectedSkillLevels)
      ..[skill.id] = _levelCycle.first;
    emit(current.copyWith(selectedSkillLevels: levels));
  }

  int _searchToken = 0;

  Future<void> searchSkills(String query) async {
    final current = state;
    if (current is! ProfileSetupReady) return;

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
      if (latest is! ProfileSetupReady) return;
      emit(
        latest.copyWith(
          remoteSkillSuggestions: results,
          remoteSkillsBusy: false,
        ),
      );
    } catch (_) {
      if (token != _searchToken) return;
      final latest = state;
      if (latest is! ProfileSetupReady) return;

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
    if (current is! ProfileSetupReady) return;

    emit(current.copyWith(catalogBusy: true, clearCatalogError: true));
    try {
      final skill = await skillsRepo.findOrCreateSkill(name);
      final latest = state;
      if (latest is! ProfileSetupReady) return;

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
      if (latest is! ProfileSetupReady) return;
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
    if (current is! ProfileSetupReady) return;

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
    if (current is! ProfileSetupReady) return;
    if (current.selectedStudyAreaIds.contains(studyArea.id)) return;

    final ids = Set<String>.from(current.selectedStudyAreaIds)
      ..add(studyArea.id);
    emit(current.copyWith(selectedStudyAreaIds: ids));
  }

  Future<void> createAndSelectStudyArea(String name) async {
    final current = state;
    if (current is! ProfileSetupReady) return;

    emit(current.copyWith(catalogBusy: true, clearCatalogError: true));
    try {
      final studyArea = await studyAreasRepo.findOrCreateStudyArea(name);
      final latest = state;
      if (latest is! ProfileSetupReady) return;

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
      if (latest is! ProfileSetupReady) return;
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
    if (current is! ProfileSetupReady) return;

    final ids = Set<String>.from(current.selectedStudyAreaIds)
      ..remove(studyAreaId);
    emit(current.copyWith(selectedStudyAreaIds: ids));
  }

  void addInterest(String interest) {
    final current = state;
    if (current is! ProfileSetupReady) return;

    emit(current.copyWith(interests: [...current.interests, interest]));
  }

  void removeInterest(String interest) {
    final current = state;
    if (current is! ProfileSetupReady) return;

    emit(
      current.copyWith(
        interests: current.interests.where((i) => i != interest).toList(),
      ),
    );
  }

  Future<void> uploadAvatar(String imagePath) async {
    final current = state;
    if (current is! ProfileSetupReady) return;

    emit(current.copyWith(avatarUploading: true, clearAvatarError: true));
    try {
      final user = await usersRepo.uploadAvatar(imagePath);
      final latest = state;
      if (latest is! ProfileSetupReady) return;
      emit(latest.copyWith(avatarUrl: user.avatarUrl, avatarUploading: false));
    } catch (e) {
      final latest = state;
      if (latest is! ProfileSetupReady) return;
      emit(
        latest.copyWith(
          avatarUploading: false,
          avatarError: e.toString().replaceFirst('Exception: ', ''),
        ),
      );
    }
  }

  Future<void> submit({
    String? bio,
    String? learningGoal,
    String? teachGoal,
  }) async {
    final current = state;
    if (current is! ProfileSetupReady || !current.canSubmit) return;

    emit(current.copyWith(isSubmitting: true, clearSubmitError: true));
    try {
      try {
        await profilesRepo.createProfile(
          bio: bio,
          learningGoal: learningGoal,
          teachGoal: teachGoal,
          interests: current.interests,
          studyAreaIds: current.selectedStudyAreaIds.toList(),
          skills: current.selectedSkillLevels.entries
              .map((e) => ProfileSkillInput(skillId: e.key, level: e.value))
              .toList(),
        );
      } on ApiException catch (e) {
        if (e.statusCode != 409) rethrow;
        await profilesRepo.updateProfile(
          bio: bio,
          learningGoal: learningGoal,
          teachGoal: teachGoal,
          interests: current.interests,
        );
        await Future.wait([
          for (final entry in current.selectedSkillLevels.entries)
            profilesRepo.addSkill(skillId: entry.key, level: entry.value),
          for (final studyAreaId in current.selectedStudyAreaIds)
            profilesRepo.addStudyArea(studyAreaId),
        ]);
      }
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
