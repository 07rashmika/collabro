part of 'edit_profile_cubit.dart';

sealed class EditProfileState extends Equatable {
  const EditProfileState();

  @override
  List<Object?> get props => [];
}

final class EditProfileLoading extends EditProfileState {
  const EditProfileLoading();
}

final class EditProfileLoadError extends EditProfileState {
  final String message;
  const EditProfileLoadError(this.message);

  @override
  List<Object?> get props => [message];
}

final class EditProfileReady extends EditProfileState {
  final List<Skill> allSkills;
  final List<StudyArea> allStudyAreas;

  final Map<String, String> selectedSkillLevels;
  final Map<String, String> originalSkillLevels;
  final Set<String> selectedStudyAreaIds;
  final Set<String> originalStudyAreaIds;
  final List<String> interests;

  final String bio;
  final String learningGoal;
  final String teachGoal;

  final bool catalogBusy;
  final String? catalogError;

  final List<String> remoteSkillSuggestions;
  final bool remoteSkillsBusy;

  final bool isSubmitting;
  final String? submitError;
  final bool submitted;

  const EditProfileReady({
    required this.allSkills,
    required this.allStudyAreas,
    this.selectedSkillLevels = const {},
    this.originalSkillLevels = const {},
    this.selectedStudyAreaIds = const {},
    this.originalStudyAreaIds = const {},
    this.interests = const [],
    this.bio = '',
    this.learningGoal = '',
    this.teachGoal = '',
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

  EditProfileReady copyWith({
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
    return EditProfileReady(
      allSkills: allSkills ?? this.allSkills,
      allStudyAreas: allStudyAreas ?? this.allStudyAreas,
      selectedSkillLevels: selectedSkillLevels ?? this.selectedSkillLevels,
      originalSkillLevels: originalSkillLevels,
      selectedStudyAreaIds: selectedStudyAreaIds ?? this.selectedStudyAreaIds,
      originalStudyAreaIds: originalStudyAreaIds,
      interests: interests ?? this.interests,
      bio: bio,
      learningGoal: learningGoal,
      teachGoal: teachGoal,
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
    allSkills,
    allStudyAreas,
    selectedSkillLevels,
    originalSkillLevels,
    selectedStudyAreaIds,
    remoteSkillSuggestions,
    remoteSkillsBusy,
    originalStudyAreaIds,
    interests,
    bio,
    learningGoal,
    teachGoal,
    catalogBusy,
    catalogError,
    isSubmitting,
    submitError,
    submitted,
  ];
}
