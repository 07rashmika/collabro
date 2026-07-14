import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:frontend/core/constants/app_colors.dart';
import 'package:frontend/core/constants/app_spacing.dart';
import 'package:frontend/core/constants/app_typography.dart';
import 'package:frontend/core/widgets/app_text_field.dart';
import 'package:frontend/core/widgets/primary_button.dart';
import 'package:frontend/core/widgets/selectable_chip.dart';
import 'package:frontend/core/widgets/tag_input.dart';
import 'package:frontend/core/widgets/typeahead_chip_picker.dart';
import 'package:frontend/features/profiles/domain/repos/profiles_repo.dart';
import 'package:frontend/features/skills/domain/entities/skill.dart';
import 'package:frontend/features/skills/domain/repos/skills_repo.dart';
import 'package:frontend/features/study_areas/domain/entities/study_area.dart';
import 'package:frontend/features/study_areas/domain/repos/study_areas_repo.dart';

import '../cubits/edit_profile_cubit.dart';

const _levelLabels = {
  'BEGINNER': 'Beginner',
  'INTERMEDIATE': 'Intermediate',
  'ADVANCED': 'Advanced',
};

class EditProfileScreen extends StatelessWidget {
  const EditProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => EditProfileCubit(
        skillsRepo: context.read<SkillsRepo>(),
        studyAreasRepo: context.read<StudyAreasRepo>(),
        profilesRepo: context.read<ProfilesRepo>(),
      )..load(),
      child: const _EditProfileView(),
    );
  }
}

class _EditProfileView extends StatefulWidget {
  const _EditProfileView();

  @override
  State<_EditProfileView> createState() => _EditProfileViewState();
}

class _EditProfileViewState extends State<_EditProfileView> {
  final _bioController = TextEditingController();
  final _learningGoalController = TextEditingController();
  final _teachGoalController = TextEditingController();
  bool _controllersSeeded = false;

  @override
  void dispose() {
    _bioController.dispose();
    _learningGoalController.dispose();
    _teachGoalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: SafeArea(
        child: BlocConsumer<EditProfileCubit, EditProfileState>(
          listener: (context, state) {
            if (state is EditProfileReady && !_controllersSeeded) {
              _controllersSeeded = true;
              _bioController.text = state.bio;
              _learningGoalController.text = state.learningGoal;
              _teachGoalController.text = state.teachGoal;
            }
            if (state is EditProfileReady && state.submitted) {
              context.pop(true);
            } else if (state is EditProfileReady && state.submitError != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.submitError!),
                  backgroundColor: AppColors.error,
                ),
              );
            } else if (state is EditProfileReady &&
                state.catalogError != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.catalogError!),
                  backgroundColor: AppColors.error,
                ),
              );
            }
          },
          builder: (context, state) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenHorizontal,
                    vertical: AppSpacing.sm,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => context.pop(),
                        icon: const Icon(
                          Icons.arrow_back,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'Edit Profile',
                          textAlign: TextAlign.center,
                          style: AppTypography.headlineMedium,
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
                Expanded(child: _buildBody(context, state)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, EditProfileState state) {
    if (state is EditProfileLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (state is EditProfileLoadError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                state.message,
                style: AppTypography.bodyMedium,
                textAlign: TextAlign.center,
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
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenHorizontal,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpacing.sm),
                AppTextField(
                  label: 'Short bio',
                  hint: 'A sentence or two about you',
                  icon: Icons.person_outline,
                  controller: _bioController,
                  maxLines: 3,
                ),
                const SizedBox(height: AppSpacing.lg),
                AppTextField(
                  label: 'What do you want to learn?',
                  hint: 'e.g. React, data structures',
                  icon: Icons.flag_outlined,
                  controller: _learningGoalController,
                ),
                const SizedBox(height: AppSpacing.lg),
                AppTextField(
                  label: 'What can you teach?',
                  hint: 'e.g. Python, calculus',
                  icon: Icons.school_outlined,
                  controller: _teachGoalController,
                ),
                const SizedBox(height: AppSpacing.xl),
                _buildSkillsPicker(cubit, ready),
                const SizedBox(height: AppSpacing.xl),
                _buildStudyAreasPicker(cubit, ready),
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
          padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!ready.canSubmit && !ready.isSubmitting)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Text(
                    'Keep at least one skill, study area, and interest.',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.warning,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              PrimaryButton(
                label: 'Save Changes',
                isLoading: ready.isSubmitting,
                onPressed: ready.canSubmit
                    ? () => cubit.submit(
                        bio: _bioController.text.trim(),
                        learningGoal: _learningGoalController.text.trim(),
                        teachGoal: _teachGoalController.text.trim(),
                      )
                    : null,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSkillsPicker(EditProfileCubit cubit, EditProfileReady state) {
    final suggestions = state.allSkills
        .where((s) => !state.selectedSkillLevels.containsKey(s.id))
        .toList();

    return TypeaheadChipPicker<Skill>(
      label: 'Skills',
      hint: 'e.g. Organic Chemistry, Debate, Photoshop',
      suggestions: suggestions,
      labelOf: (s) => s.name,
      onSelectExisting: cubit.selectSkill,
      onCreateNew: cubit.createAndSelectSkill,
      isBusy: state.catalogBusy,
      onQueryChanged: cubit.searchSkills,
      remoteSuggestions: state.remoteSkillSuggestions,
      remoteBusy: state.remoteSkillsBusy,
      selectedChips: state.selectedSkillLevels.entries.map((e) {
        final skill = state.allSkills.firstWhere((s) => s.id == e.key);
        return SelectableChip(
          label: skill.name,
          selected: true,
          trailingLabel: _levelLabels[e.value],
          onTap: () => cubit.cycleSkillLevel(e.key),
        );
      }).toList(),
    );
  }

  Widget _buildStudyAreasPicker(
    EditProfileCubit cubit,
    EditProfileReady state,
  ) {
    final suggestions = state.allStudyAreas
        .where((a) => !state.selectedStudyAreaIds.contains(a.id))
        .toList();

    return TypeaheadChipPicker<StudyArea>(
      label: 'Study areas',
      hint: 'e.g. Nursing, Economics, Fine Arts',
      suggestions: suggestions,
      labelOf: (a) => a.name,
      onSelectExisting: cubit.selectStudyArea,
      onCreateNew: cubit.createAndSelectStudyArea,
      isBusy: state.catalogBusy,
      selectedChips: state.selectedStudyAreaIds.map((id) {
        final area = state.allStudyAreas.firstWhere((a) => a.id == id);
        return SelectableChip(
          label: area.name,
          selected: true,
          onTap: () => cubit.removeStudyArea(id),
        );
      }).toList(),
    );
  }
}
