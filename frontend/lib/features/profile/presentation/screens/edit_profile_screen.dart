import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/core/constants/app_colors.dart';
import 'package:frontend/core/constants/app_spacing.dart';
import 'package:frontend/core/constants/app_typography.dart';
import 'package:frontend/core/utils/snackbar_utils.dart';
import 'package:frontend/features/auth/domain/repos/auth_repo.dart';
import 'package:frontend/features/profiles/domain/repos/profiles_repo.dart';
import 'package:frontend/features/skills/domain/repos/skills_repo.dart';
import 'package:frontend/features/study_areas/domain/repos/study_areas_repo.dart';
import 'package:frontend/features/users/domain/repos/users_repo.dart';
import 'package:go_router/go_router.dart';

import '../components/edit_profile_body.dart';
import '../cubits/edit_profile_cubit.dart';

class EditProfileScreen extends StatelessWidget {
  const EditProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => EditProfileCubit(
        skillsRepo: context.read<SkillsRepo>(),
        studyAreasRepo: context.read<StudyAreasRepo>(),
        profilesRepo: context.read<ProfilesRepo>(),
        authRepo: context.read<AuthRepo>(),
        usersRepo: context.read<UsersRepo>(),
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
  String? _initialAvatarUrl;
  bool _avatarChanged = false;

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
    return Scaffold(
      backgroundColor: colors.backgroundDark,
      body: SafeArea(
        child: BlocConsumer<EditProfileCubit, EditProfileState>(
          listener: (context, state) {
            if (state is EditProfileReady && !_controllersSeeded) {
              _controllersSeeded = true;
              _initialAvatarUrl = state.avatarUrl;
              _bioController.text = state.bio;
              _learningGoalController.text = state.learningGoal;
              _teachGoalController.text = state.teachGoal;
            }
            if (state is EditProfileReady &&
                _controllersSeeded &&
                state.avatarUrl != _initialAvatarUrl) {
              _avatarChanged = true;
            }
            if (state is EditProfileReady && state.submitted) {
              context.pop(true);
            } else if (state is EditProfileReady &&
                (state.submitError != null || state.catalogError != null)) {
              showErrorSnackBar(context, state.submitError ?? state.catalogError);
            } else if (state is EditProfileReady && state.avatarError != null) {
              showErrorSnackBar(context, state.avatarError);
            }
          },
          builder: (context, state) {
            return Column(
              children: [
                Padding(
                  padding: const .symmetric(
                    horizontal: AppSpacing.screenHorizontal,
                    vertical: AppSpacing.sm,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => context.pop(_avatarChanged),
                        icon: Icon(Icons.arrow_back, color: colors.textPrimary),
                      ),
                      Expanded(
                        child: Text(
                          'Edit Profile',
                          textAlign: .center,
                          style: typography.headlineMedium,
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
                Expanded(
                  child: EditProfileBody(
                    state: state,
                    bioController: _bioController,
                    learningGoalController: _learningGoalController,
                    teachGoalController: _teachGoalController,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
