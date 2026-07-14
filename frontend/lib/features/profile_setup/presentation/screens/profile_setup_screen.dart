import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:frontend/core/constants/app_colors.dart';
import 'package:frontend/core/constants/app_routes.dart';
import 'package:frontend/core/constants/app_spacing.dart';
import 'package:frontend/core/constants/app_typography.dart';
import 'package:frontend/core/widgets/app_text_field.dart';
import 'package:frontend/core/widgets/primary_button.dart';
import 'package:frontend/core/widgets/secondary_button.dart';
import 'package:frontend/core/widgets/selectable_chip.dart';
import 'package:frontend/core/widgets/tag_input.dart';
import 'package:frontend/core/widgets/typeahead_chip_picker.dart';
import 'package:frontend/features/auth/domain/entities/app_user.dart';
import 'package:frontend/features/profiles/domain/repos/profiles_repo.dart';
import 'package:frontend/features/profile_setup/presentation/cubits/profile_setup_cubit.dart';
import 'package:frontend/features/skills/domain/entities/skill.dart';
import 'package:frontend/features/skills/domain/repos/skills_repo.dart';
import 'package:frontend/features/study_areas/domain/entities/study_area.dart';
import 'package:frontend/features/study_areas/domain/repos/study_areas_repo.dart';

const _levelLabels = {
  'BEGINNER': 'Beginner',
  'INTERMEDIATE': 'Intermediate',
  'ADVANCED': 'Advanced',
};

const _stepTitles = ['Skills', 'Study areas', 'Interests', 'About you'];

class ProfileSetupScreen extends StatelessWidget {
  final AppUser user;

  const ProfileSetupScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ProfileSetupCubit(
        skillsRepo: context.read<SkillsRepo>(),
        studyAreasRepo: context.read<StudyAreasRepo>(),
        profilesRepo: context.read<ProfilesRepo>(),
      )..loadCatalogs(),
      child: _ProfileSetupView(user: user),
    );
  }
}

class _ProfileSetupView extends StatefulWidget {
  final AppUser user;

  const _ProfileSetupView({required this.user});

  @override
  State<_ProfileSetupView> createState() => _ProfileSetupViewState();
}

class _ProfileSetupViewState extends State<_ProfileSetupView> {
  final _bioController = TextEditingController();
  final _learningGoalController = TextEditingController();
  final _teachGoalController = TextEditingController();

  @override
  void dispose() {
    _bioController.dispose();
    _learningGoalController.dispose();
    _teachGoalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Onboarding is mandatory — block back navigation (hardware back,
      // edge-swipe) so a user can't dodge it without finishing.
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.backgroundDark,
        body: SafeArea(
          child: BlocConsumer<ProfileSetupCubit, ProfileSetupState>(
            listener: (context, state) {
              if (state is ProfileSetupReady && state.submitted) {
                context.go(AppRoutes.home, extra: widget.user);
              } else if (state is ProfileSetupReady &&
                  state.submitError != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(state.submitError!),
                    backgroundColor: AppColors.error,
                  ),
                );
              } else if (state is ProfileSetupReady &&
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
              if (state is ProfileSetupLoading) {
                return const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                );
              }
              if (state is ProfileSetupLoadError) {
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
                          onPressed: () =>
                              context.read<ProfileSetupCubit>().loadCatalogs(),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final ready = state as ProfileSetupReady;
              return _buildWizard(context, ready);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildWizard(BuildContext context, ProfileSetupReady state) {
    final cubit = context.read<ProfileSetupCubit>();
    final isLastStep = state.currentStep == kAboutStep;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenHorizontal,
            AppSpacing.lg,
            AppSpacing.screenHorizontal,
            AppSpacing.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Step ${state.currentStep + 1} of $kProfileSetupStepCount · ${_stepTitles[state.currentStep]}',
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: List.generate(kProfileSetupStepCount, (i) {
                  final active = i <= state.currentStep;
                  return Expanded(
                    child: Container(
                      margin: EdgeInsets.only(
                        right: i == kProfileSetupStepCount - 1
                            ? 0
                            : AppSpacing.xs,
                      ),
                      height: 4,
                      decoration: BoxDecoration(
                        color: active
                            ? AppColors.primary
                            : AppColors.chipBackground,
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusFull,
                        ),
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
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenHorizontal,
            ),
            child: switch (state.currentStep) {
              kSkillsStep => _buildSkillsStep(context, cubit, state),
              kStudyAreasStep => _buildStudyAreasStep(context, cubit, state),
              kInterestsStep => _buildInterestsStep(context, cubit, state),
              _ => _buildAboutStep(context, state),
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!isLastStep && !state.canAdvance)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Text(
                    _missingHintFor(state.currentStep),
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.warning,
                    ),
                    textAlign: TextAlign.center,
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
                                    bio: _bioController.text.trim(),
                                    learningGoal: _learningGoalController.text
                                        .trim(),
                                    teachGoal: _teachGoalController.text.trim(),
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

  Widget _buildSkillsStep(
    BuildContext context,
    ProfileSetupCubit cubit,
    ProfileSetupReady state,
  ) {
    final suggestions = state.allSkills
        .where((s) => !state.selectedSkillLevels.containsKey(s.id))
        .toList();

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('What are you good at?', style: AppTypography.headlineMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(
            "Type any skill — not just tech. Add it, then tap the chip to set your level.",
            style: AppTypography.bodySmall,
          ),
          const SizedBox(height: AppSpacing.xl),
          TypeaheadChipPicker<Skill>(
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
          ),
        ],
      ),
    );
  }

  Widget _buildStudyAreasStep(
    BuildContext context,
    ProfileSetupCubit cubit,
    ProfileSetupReady state,
  ) {
    final suggestions = state.allStudyAreas
        .where((a) => !state.selectedStudyAreaIds.contains(a.id))
        .toList();

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('What do you study?', style: AppTypography.headlineMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Any field, any major — type it in.',
            style: AppTypography.bodySmall,
          ),
          const SizedBox(height: AppSpacing.xl),
          TypeaheadChipPicker<StudyArea>(
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
          ),
        ],
      ),
    );
  }

  Widget _buildInterestsStep(
    BuildContext context,
    ProfileSetupCubit cubit,
    ProfileSetupReady state,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('What are you into?', style: AppTypography.headlineMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(
            "Hobbies, obsessions, anything — helps us match you beyond just coursework.",
            style: AppTypography.bodySmall,
          ),
          const SizedBox(height: AppSpacing.xl),
          TagInput(
            label: 'Interests',
            hint: 'e.g. competitive programming, sci-fi novels',
            tags: state.interests,
            onAdd: cubit.addInterest,
            onRemove: cubit.removeInterest,
            maxTags: 30,
          ),
        ],
      ),
    );
  }

  Widget _buildAboutStep(BuildContext context, ProfileSetupReady state) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Almost done', style: AppTypography.headlineMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'A few optional details to help peers get to know you.',
            style: AppTypography.bodySmall,
          ),
          const SizedBox(height: AppSpacing.xl),
          AppTextField(
            label: 'Short bio (optional)',
            hint: 'A sentence or two about you',
            icon: Icons.person_outline,
            controller: _bioController,
            maxLines: 3,
          ),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(
            label: 'What do you want to learn? (optional)',
            hint: 'e.g. React, data structures',
            icon: Icons.flag_outlined,
            controller: _learningGoalController,
          ),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(
            label: 'What can you teach? (optional)',
            hint: 'e.g. Python, calculus',
            icon: Icons.school_outlined,
            controller: _teachGoalController,
          ),
        ],
      ),
    );
  }
}
