part of 'profile_setup_cubit.dart';

const int kSkillsStep = 0;
const int kStudyAreasStep = 1;
const int kInterestsStep = 2;
const int kAboutStep = 3;
const int kProfileSetupStepCount = 4;

sealed class ProfileSetupState extends Equatable {
  const ProfileSetupState();

  @override
  List<Object?> get props => [];
}

final class ProfileSetupLoading extends ProfileSetupState {
  const ProfileSetupLoading();
}

final class ProfileSetupLoadError extends ProfileSetupState {
  final String message;
  const ProfileSetupLoadError(this.message);

  @override
  List<Object?> get props => [message];
}

final class ProfileSetupReady extends ProfileSetupState {
  final int currentStep;

  /// Grows as the student types skills/study areas that don't exist yet —
  /// so they immediately show up as future suggestions too.
  final List<Skill> allSkills;
  final List<StudyArea> allStudyAreas;

  /// skillId -> proficiency level; absence means not selected.
  final Map<String, String> selectedSkillLevels;
  final Set<String> selectedStudyAreaIds;
  final List<String> interests;

  /// True while a find-or-create call for a typed skill/study area is in flight.
  final bool catalogBusy;
  final String? catalogError;

  /// Live results from the external skills search API for whatever's
  /// currently typed in the skills picker.
  final List<String> remoteSkillSuggestions;
  final bool remoteSkillsBusy;

  final bool isSubmitting;
  final String? submitError;
  final bool submitted;

  const ProfileSetupReady({
    this.currentStep = kSkillsStep,
    required this.allSkills,
    required this.allStudyAreas,
    this.selectedSkillLevels = const {},
    this.selectedStudyAreaIds = const {},
    this.interests = const [],
    this.catalogBusy = false,
    this.catalogError,
    this.remoteSkillSuggestions = const [],
    this.remoteSkillsBusy = false,
    this.isSubmitting = false,
    this.submitError,
    this.submitted = false,
  });

  bool get hasSkills => selectedSkillLevels.isNotEmpty;
  bool get hasStudyAreas => selectedStudyAreaIds.isNotEmpty;
  bool get hasInterests => interests.isNotEmpty;

  bool get canSubmit =>
      hasSkills && hasStudyAreas && hasInterests && !isSubmitting;

  bool get canAdvance {
    switch (currentStep) {
      case kSkillsStep:
        return hasSkills;
      case kStudyAreasStep:
        return hasStudyAreas;
      case kInterestsStep:
        return hasInterests;
      default:
        return true;
    }
  }

  ProfileSetupReady copyWith({
    int? currentStep,
    List<Skill>? allSkills,
    List<StudyArea>? allStudyAreas,
    Map<String, String>? selectedSkillLevels,
    Set<String>? selectedStudyAreaIds,
    List<String>? interests,
    bool? catalogBusy,
    String? catalogError,
    bool clearCatalogError = false,
    List<String>? remoteSkillSuggestions,
    bool? remoteSkillsBusy,
    bool? isSubmitting,
    String? submitError,
    bool clearSubmitError = false,
    bool? submitted,
  }) {
    return ProfileSetupReady(
      currentStep: currentStep ?? this.currentStep,
      allSkills: allSkills ?? this.allSkills,
      allStudyAreas: allStudyAreas ?? this.allStudyAreas,
      selectedSkillLevels: selectedSkillLevels ?? this.selectedSkillLevels,
      selectedStudyAreaIds: selectedStudyAreaIds ?? this.selectedStudyAreaIds,
      interests: interests ?? this.interests,
      catalogBusy: catalogBusy ?? this.catalogBusy,
      catalogError: clearCatalogError
          ? null
          : (catalogError ?? this.catalogError),
      remoteSkillSuggestions:
          remoteSkillSuggestions ?? this.remoteSkillSuggestions,
      remoteSkillsBusy: remoteSkillsBusy ?? this.remoteSkillsBusy,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      submitError: clearSubmitError ? null : (submitError ?? this.submitError),
      submitted: submitted ?? this.submitted,
    );
  }

  @override
  List<Object?> get props => [
    currentStep,
    allSkills,
    allStudyAreas,
    selectedSkillLevels,
    selectedStudyAreaIds,
    interests,
    catalogBusy,
    catalogError,
    remoteSkillSuggestions,
    remoteSkillsBusy,
    isSubmitting,
    submitError,
    submitted,
  ];
}
