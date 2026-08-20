import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/core/constants/app_colors.dart';
import 'package:frontend/core/constants/app_spacing.dart';
import 'package:frontend/core/constants/app_typography.dart';
import 'package:frontend/core/widgets/primary_button.dart';
import 'package:frontend/core/widgets/secondary_button.dart';
import 'package:image_picker/image_picker.dart';

import '../cubits/profile_setup_cubit.dart';
import 'about_step.dart';
import 'interests_step.dart';
import 'skills_step.dart';
import 'study_areas_step.dart';

const _stepTitles = ['Skills', 'Study areas', 'Interests', 'About you'];

String _missingHintFor(int step) {
  switch (step) {
    case kSkillsStep:
      return 'Add at least one skill to continue.';
    case kStudyAreasStep:
      return 'Add at least one study area to continue.';
    case kInterestsStep:
      return 'Add at least one interest to continue.';
    default:
      return '';
  }
}

class ProfileSetupWizard extends StatelessWidget {
  final ProfileSetupReady state;
  final String userName;
  final TextEditingController bioController;
  final TextEditingController learningGoalController;
  final TextEditingController teachGoalController;

  const ProfileSetupWizard({
    super.key,
    required this.state,
    required this.userName,
    required this.bioController,
    required this.learningGoalController,
    required this.teachGoalController,
  });

  Future<void> _pickAndUploadAvatar(BuildContext context) async {
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (image == null || !context.mounted) return;
    context.read<ProfileSetupCubit>().uploadAvatar(image.path);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final typography = AppTypography.of(context);
    final cubit = context.read<ProfileSetupCubit>();
    final isLastStep = state.currentStep == kAboutStep;

    return Column(
      children: [
        Padding(
          padding: const .fromLTRB(
            AppSpacing.screenHorizontal,
            AppSpacing.lg,
            AppSpacing.screenHorizontal,
            AppSpacing.md,
          ),
          child: Column(
            crossAxisAlignment: .start,
            children: [
              Text(
                'Step ${state.currentStep + 1} of $kProfileSetupStepCount · ${_stepTitles[state.currentStep]}',
                style: typography.labelSmall.copyWith(
                  color: colors.textTertiary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: List.generate(kProfileSetupStepCount, (i) {
                  final active = i <= state.currentStep;
                  return Expanded(
                    child: Container(
                      margin: .only(
                        right: i == kProfileSetupStepCount - 1
                            ? 0
                            : AppSpacing.xs,
                      ),
                      height: 4,
                      decoration: BoxDecoration(
                        color: active ? colors.primary : colors.chipBackground,
                        borderRadius: .circular(AppSpacing.radiusFull),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const .symmetric(horizontal: AppSpacing.screenHorizontal),
            child: switch (state.currentStep) {
              kSkillsStep => SkillsStep(
                allSkills: state.allSkills,
                selectedSkillLevels: state.selectedSkillLevels,
                catalogBusy: state.catalogBusy,
                remoteSkillSuggestions: state.remoteSkillSuggestions,
                remoteSkillsBusy: state.remoteSkillsBusy,
                onSelectExisting: cubit.selectSkill,
                onCreateNew: cubit.createAndSelectSkill,
                onQueryChanged: cubit.searchSkills,
                onCycleLevel: cubit.cycleSkillLevel,
              ),
              kStudyAreasStep => StudyAreasStep(
                allStudyAreas: state.allStudyAreas,
                selectedStudyAreaIds: state.selectedStudyAreaIds,
                catalogBusy: state.catalogBusy,
                onSelectExisting: cubit.selectStudyArea,
                onCreateNew: cubit.createAndSelectStudyArea,
                onRemove: cubit.removeStudyArea,
              ),
              kInterestsStep => InterestsStep(
                interests: state.interests,
                onAdd: cubit.addInterest,
                onRemove: cubit.removeInterest,
              ),
              _ => AboutStep(
                bioController: bioController,
                learningGoalController: learningGoalController,
                teachGoalController: teachGoalController,
                userName: userName,
                avatarUrl: state.avatarUrl,
                avatarUploading: state.avatarUploading,
                onPickAvatar: () => _pickAndUploadAvatar(context),
              ),
            },
          ),
        ),
        Padding(
          padding: const .all(AppSpacing.screenHorizontal),
          child: Column(
            crossAxisAlignment: .stretch,
            children: [
              if (!isLastStep && !state.canAdvance)
                Padding(
                  padding: const .only(bottom: AppSpacing.sm),
                  child: Text(
                    _missingHintFor(state.currentStep),
                    style: typography.bodySmall.copyWith(color: colors.warning),
                    textAlign: .center,
                  ),
                ),
              Row(
                children: [
                  if (state.currentStep > 0) ...[
                    Expanded(
                      child: SecondaryButton(
                        label: 'Back',
                        onPressed: state.isSubmitting
                            ? null
                            : cubit.previousStep,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                  ],
                  Expanded(
                    child: PrimaryButton(
                      label: isLastStep ? 'Finish Setup' : 'Next',
                      isLoading: isLastStep && state.isSubmitting,
                      onPressed: isLastStep
                          ? (state.canSubmit
                                ? () => cubit.submit(
                                    bio: bioController.text.trim(),
                                    learningGoal: learningGoalController.text
                                        .trim(),
                                    teachGoal: teachGoalController.text.trim(),
                                  )
                                : null)
                          : (state.canAdvance ? cubit.nextStep : null),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
