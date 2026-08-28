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

  Future<void> _confirmDeleteAccount(BuildContext context) async {
    final cubit = context.read<ProfileCubit>();

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final colors = AppColors.of(dialogContext);
        final typography = AppTypography.of(dialogContext);
        return AlertDialog(
          backgroundColor: colors.backgroundCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          ),
          title: Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: colors.error,
                size: AppSpacing.iconLg,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text('Delete Account', style: typography.titleLarge),
            ],
          ),
          content: Text(
            'This action cannot be undone.\n\n'
            'Your account, notes, sessions, and all associated data will be '
            'permanently deleted from our servers.',
            style: typography.bodyMedium,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(
                'Cancel',
                style: typography.labelLarge.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(
                'Delete',
                style: typography.labelLarge.copyWith(color: colors.error),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      cubit.deleteAccount();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final typography = AppTypography.of(context);

    return BlocListener<ProfileCubit, ProfileState>(
      listener: (context, state) {
        if (state is ProfileAccountDeleted) {
          context.go(AppRoutes.signIn);
        } else if (state is ProfileError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: colors.error,
            ),
          );
        }
      },
      child: _buildBody(context, colors, typography),
    );
  }

  Widget _buildBody(
    BuildContext context,
    AppColors colors,
    AppTypography typography,
  ) {
    if (state is ProfileDeletingAccount) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: colors.error),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Deleting your account…',
              style: typography.bodyMedium.copyWith(
                color: colors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    if (state is ProfileLoading) {
      return Center(child: CircularProgressIndicator(color: colors.primary));
    }

    if (state is ProfileError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                genericErrorMessage,
                style: typography.bodyMedium,
                textAlign: TextAlign.center,
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
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenHorizontal,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
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

          Divider(color: colors.border),

          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: AppSpacing.buttonHeightMd,
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _confirmDeleteAccount(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: colors.error,
                side: BorderSide(color: colors.error),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
              ),
              icon: const Icon(Icons.delete_forever_outlined),
              label: Text(
                'Delete Account',
                style: typography.labelLarge.copyWith(color: colors.error),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }
}
