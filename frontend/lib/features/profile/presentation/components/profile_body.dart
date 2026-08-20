import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/core/constants/app_colors.dart';
import 'package:frontend/core/constants/app_routes.dart';
import 'package:frontend/core/constants/app_spacing.dart';
import 'package:frontend/core/constants/app_typography.dart';
import 'package:frontend/core/constants/error_messages.dart';
import 'package:frontend/core/widgets/primary_button.dart';
import 'package:frontend/core/widgets/profile_detail_sections.dart';
import 'package:frontend/core/widgets/user_avatar.dart';
import 'package:go_router/go_router.dart';

import '../cubits/profile_cubit.dart';
import 'no_profile_placeholder.dart';

class ProfileBody extends StatelessWidget {
  final ProfileState state;

  const ProfileBody({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final typography = AppTypography.of(context);
    if (state is ProfileLoading) {
      return Center(child: CircularProgressIndicator(color: colors.primary));
    }

    if (state is ProfileError) {
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
                onPressed: () => context.read<ProfileCubit>().loadProfile(),
              ),
            ],
          ),
        ),
      );
    }

    final loaded = state as ProfileLoaded;
    return SingleChildScrollView(
      padding: const .symmetric(horizontal: AppSpacing.screenHorizontal),
      child: Column(
        crossAxisAlignment: .stretch,
        children: [
          const SizedBox(height: AppSpacing.md),
          Center(
            child: Column(
              children: [
                UserAvatar(
                  name: loaded.user.name,
                  imageUrl: loaded.user.avatarUrl,
                  size: AppSpacing.avatarXxl,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(loaded.user.name, style: typography.headlineSmall),
                const SizedBox(height: AppSpacing.xs),
                Text(loaded.user.email, style: typography.bodySmall),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          InkWell(
            onTap: () => context.push(AppRoutes.connections),
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.cardPadding),
              decoration: BoxDecoration(
                color: colors.backgroundCard,
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                border: Border.all(color: colors.border),
              ),
              child: Row(
                children: [
                  Icon(Icons.people_outline, color: colors.textSecondary),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text('Connections', style: typography.titleMedium),
                  ),
                  Text(
                    '${loaded.connectionsCount}',
                    style: typography.bodyMedium.copyWith(
                      color: colors.textTertiary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Icon(Icons.chevron_right, color: colors.textTertiary),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          if (loaded.profile == null)
            NoProfilePlaceholder(user: loaded.user)
          else
            ...buildProfileDetailSections(
              context,
              bio: loaded.profile!.bio,
              learningGoal: loaded.profile!.learningGoal,
              teachGoal: loaded.profile!.teachGoal,
              skills: loaded.profile!.skills,
              studyAreas: loaded.profile!.studyAreas,
              interests: loaded.profile!.interests,
            ),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }
}
