import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/core/constants/app_colors.dart';
import 'package:frontend/core/constants/app_routes.dart';
import 'package:frontend/core/constants/app_spacing.dart';
import 'package:frontend/core/constants/app_typography.dart';
import 'package:frontend/core/constants/error_messages.dart';
import 'package:frontend/core/utils/snackbar_utils.dart';
import 'package:frontend/core/widgets/primary_button.dart';
import 'package:frontend/features/auth/domain/entities/app_user.dart';
import 'package:frontend/features/profile_setup/presentation/components/profile_setup_wizard.dart';
import 'package:frontend/features/profile_setup/presentation/cubits/profile_setup_cubit.dart';
import 'package:frontend/features/profiles/domain/repos/profiles_repo.dart';
import 'package:frontend/features/skills/domain/repos/skills_repo.dart';
import 'package:frontend/features/study_areas/domain/repos/study_areas_repo.dart';
import 'package:go_router/go_router.dart';

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
    final colors = AppColors.of(context);
    final typography = AppTypography.of(context);
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: colors.backgroundDark,
        body: SafeArea(
          child: BlocConsumer<ProfileSetupCubit, ProfileSetupState>(
            listener: (context, state) {
              if (state is ProfileSetupReady && state.submitted) {
                context.go(AppRoutes.home, extra: widget.user);
              } else if (state is ProfileSetupReady &&
                  (state.submitError != null || state.catalogError != null)) {
                showErrorSnackBar(context);
              }
            },
            builder: (context, state) {
              if (state is ProfileSetupLoading) {
                return Center(
                  child: CircularProgressIndicator(color: colors.primary),
                );
              }
              if (state is ProfileSetupLoadError) {
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
                          onPressed: () =>
                              context.read<ProfileSetupCubit>().loadCatalogs(),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final ready = state as ProfileSetupReady;
              return ProfileSetupWizard(
                state: ready,
                bioController: _bioController,
                learningGoalController: _learningGoalController,
                teachGoalController: _teachGoalController,
              );
            },
          ),
        ),
      ),
    );
  }
}
