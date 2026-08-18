import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/core/constants/app_colors.dart';
import 'package:frontend/core/constants/app_spacing.dart';
import 'package:frontend/core/constants/app_typography.dart';
import 'package:frontend/core/constants/error_messages.dart';
import 'package:frontend/core/widgets/app_text_field.dart';
import 'package:frontend/core/widgets/primary_button.dart';
import 'package:frontend/core/widgets/tag_input.dart';

import '../cubits/edit_profile_cubit.dart';
import 'skills_picker.dart';
import 'study_areas_picker.dart';

class EditProfileBody extends StatelessWidget {
  final EditProfileState state;
  final TextEditingController bioController;
  final TextEditingController learningGoalController;
  final TextEditingController teachGoalController;

  const EditProfileBody({
    super.key,
    required this.state,
    required this.bioController,
    required this.learningGoalController,
    required this.teachGoalController,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final typography = AppTypography.of(context);
    if (state is EditProfileLoading) {
      return Center(child: CircularProgressIndicator(color: colors.primary));
    }

    if (state is EditProfileLoadError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisSize: .min,
            children: [
              Text(
                genericErrorMessage,
                style: typography.bodyMedium,
                textAlign: .center,
              ),
              const SizedBox(height: AppSpacing.lg),
              PrimaryButton(
                label: 'Retry',
                onPressed: () => context.read<EditProfileCubit>().load(),
              ),
            ],
          ),
        ),
      );
    }

    final ready = state as EditProfileReady;
    final cubit = context.read<EditProfileCubit>();

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const .symmetric(horizontal: AppSpacing.screenHorizontal),
            child: Column(
              crossAxisAlignment: .stretch,
              children: [
                const SizedBox(height: AppSpacing.sm),
                AppTextField(
                  label: 'Short bio',
                  hint: 'A sentence or two about you',
                  icon: Icons.person_outline,
                  controller: bioController,
                  maxLines: 3,
                ),
                const SizedBox(height: AppSpacing.lg),
                AppTextField(
                  label: 'What do you want to learn?',
                  hint: 'e.g. React, data structures',
                  icon: Icons.flag_outlined,
                  controller: learningGoalController,
                ),
                const SizedBox(height: AppSpacing.lg),
                AppTextField(
                  label: 'What can you teach?',
                  hint: 'e.g. Python, calculus',
                  icon: Icons.school_outlined,
                  controller: teachGoalController,
                ),
                const SizedBox(height: AppSpacing.xl),
                SkillsPicker(
                  allSkills: ready.allSkills,
                  selectedSkillLevels: ready.selectedSkillLevels,
                  catalogBusy: ready.catalogBusy,
                  remoteSkillSuggestions: ready.remoteSkillSuggestions,
                  remoteSkillsBusy: ready.remoteSkillsBusy,
                  onSelectExisting: cubit.selectSkill,
                  onCreateNew: cubit.createAndSelectSkill,
                  onQueryChanged: cubit.searchSkills,
                  onCycleLevel: cubit.cycleSkillLevel,
                ),
                const SizedBox(height: AppSpacing.xl),
                StudyAreasPicker(
                  allStudyAreas: ready.allStudyAreas,
                  selectedStudyAreaIds: ready.selectedStudyAreaIds,
                  catalogBusy: ready.catalogBusy,
                  onSelectExisting: cubit.selectStudyArea,
                  onCreateNew: cubit.createAndSelectStudyArea,
                  onRemove: cubit.removeStudyArea,
                ),
                const SizedBox(height: AppSpacing.xl),
                TagInput(
                  label: 'Interests',
                  hint: 'e.g. competitive programming, sci-fi novels',
                  tags: ready.interests,
                  onAdd: cubit.addInterest,
                  onRemove: cubit.removeInterest,
                  maxTags: 30,
                ),
                const SizedBox(height: AppSpacing.xxl),
              ],
            ),
          ),
        ),
        Padding(
          padding: const .all(AppSpacing.screenHorizontal),
          child: Column(
            crossAxisAlignment: .stretch,
            children: [
              if (!ready.canSubmit && !ready.isSubmitting)
                Padding(
                  padding: const .only(bottom: AppSpacing.sm),
                  child: Text(
                    'Keep at least one skill, study area, and interest.',
                    style: typography.bodySmall.copyWith(color: colors.warning),
                    textAlign: .center,
                  ),
                ),
              PrimaryButton(
                label: 'Save Changes',
                isLoading: ready.isSubmitting,
                onPressed: ready.canSubmit
                    ? () => cubit.submit(
                        bio: bioController.text.trim(),
                        learningGoal: learningGoalController.text.trim(),
                        teachGoal: teachGoalController.text.trim(),
                      )
                    : null,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
