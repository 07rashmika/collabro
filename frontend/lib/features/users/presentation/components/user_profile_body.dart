import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/core/constants/app_colors.dart';
import 'package:frontend/core/constants/app_spacing.dart';
import 'package:frontend/core/constants/app_typography.dart';
import 'package:frontend/core/constants/error_messages.dart';
import 'package:frontend/core/widgets/connect_button.dart';
import 'package:frontend/core/widgets/primary_button.dart';
import 'package:frontend/core/widgets/profile_detail_sections.dart';
import 'package:frontend/core/widgets/user_avatar.dart';
import 'package:frontend/features/connections/presentation/connect_request_handler.dart';
import 'package:frontend/features/connections/presentation/cubits/connections_cubit.dart';

import '../cubits/user_profile_cubit.dart';
import 'user_posts_section.dart';

class UserProfileBody extends StatelessWidget {
  final UserProfileState state;

  const UserProfileBody({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final typography = AppTypography.of(context);

    if (state is UserProfileInitial || state is UserProfileLoading) {
      return Center(child: CircularProgressIndicator(color: colors.primary));
    }

    if (state is UserProfileError) {
      return Center(
        child: Padding(
          padding: const .all(AppSpacing.xxl),
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
                onPressed: () => context.read<UserProfileCubit>().load(),
              ),
            ],
          ),
        ),
      );
    }

    final loaded = state as UserProfileLoaded;
    final user = loaded.user;
    final connectionsState = context.watch<ConnectionsCubit>().state;

    return RefreshIndicator(
      color: colors.primary,
      onRefresh: () => context.read<UserProfileCubit>().load(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const .symmetric(
          horizontal: AppSpacing.screenHorizontal,
        ),
        child: Column(
          crossAxisAlignment: .stretch,
          children: [
            const SizedBox(height: AppSpacing.md),
            Center(
              child: Column(
                children: [
                  UserAvatar(name: user.name, size: AppSpacing.avatarXxl),
                  const SizedBox(height: AppSpacing.md),
                  Text(user.name, style: typography.headlineSmall),
                  const SizedBox(height: AppSpacing.xs),
                  Text(user.email, style: typography.bodySmall),
                  const SizedBox(height: AppSpacing.md),
                  SizedBox(
                    width: 160,
                    child: ConnectButton(
                      status: connectionsState.effectiveStatus(
                        user.connectionStatus,
                        user.id,
                      ),
                      onPressed: () => handleConnectPress(
                        context,
                        user.id,
                        connectionsState.effectiveStatus(
                          user.connectionStatus,
                          user.id,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            ...buildProfileDetailSections(
              context,
              bio: user.bio,
              learningGoal: user.learningGoal,
              teachGoal: user.teachGoal,
              skills: user.skills,
              studyAreas: user.studyAreas,
              interests: user.interests,
            ),
            UserPostsSection(notes: loaded.notes, sessions: loaded.sessions),
            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }
}
