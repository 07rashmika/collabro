import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/core/constants/app_colors.dart';
import 'package:frontend/core/constants/app_routes.dart';
import 'package:frontend/core/constants/app_spacing.dart';
import 'package:frontend/core/constants/app_typography.dart';
import 'package:frontend/core/constants/error_messages.dart';
import 'package:frontend/core/utils/snackbar_utils.dart';
import 'package:frontend/core/widgets/connect_button.dart';
import 'package:frontend/core/widgets/danger_button.dart';
import 'package:frontend/core/widgets/primary_button.dart';
import 'package:frontend/core/widgets/profile_detail_sections.dart';
import 'package:frontend/core/widgets/user_avatar.dart';
import 'package:frontend/features/connections/presentation/connect_request_handler.dart';
import 'package:frontend/features/connections/presentation/cubits/connections_cubit.dart';
import 'package:go_router/go_router.dart';

import '../cubits/user_profile_cubit.dart';
import 'user_posts_section.dart';

void _confirmDisconnect(BuildContext context, String userId, String userName) {
  final colors = AppColors.of(context);
  final typography = AppTypography.of(context);
  showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: colors.backgroundCard,
      title: Text('Remove connection?', style: typography.headlineSmall),
      content: Text(
        "You and $userName won't be connected anymore. You can send a new request later.",
        style: typography.bodyMedium,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text('Cancel', style: typography.labelMedium),
        ),
        DangerButton(
          label: 'Remove',
          onPressed: () async {
            Navigator.of(dialogContext).pop();
            try {
              await context.read<ConnectionsCubit>().removeConnection(userId);
            } catch (e) {
              if (context.mounted) showErrorSnackBar(context);
            }
          },
        ),
      ],
    ),
  );
}

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
    final connectStatus = connectionsState.effectiveStatus(
      user.connectionStatus,
      user.id,
    );

    return RefreshIndicator(
      color: colors.primary,
      onRefresh: () => context.read<UserProfileCubit>().load(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const .symmetric(horizontal: AppSpacing.screenHorizontal),
        child: Column(
          crossAxisAlignment: .stretch,
          children: [
            const SizedBox(height: AppSpacing.md),
            Center(
              child: Column(
                children: [
                  UserAvatar(
                    name: user.name,
                    imageUrl: user.avatarUrl,
                    size: AppSpacing.avatarXxl,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(user.name, style: typography.headlineSmall),
                  const SizedBox(height: AppSpacing.xs),
                  Text(user.email, style: typography.bodySmall),
                  const SizedBox(height: AppSpacing.md),
                  SizedBox(
                    width: 160,
                    child: ConnectButton(
                      status: connectStatus,
                      onPressed: () =>
                          handleConnectPress(context, user.id, connectStatus),
                    ),
                  ),
                  if (connectStatus == ConnectStatus.connected) ...[
                    const SizedBox(height: AppSpacing.xs),
                    DangerButton(
                      label: 'Remove connection',
                      onPressed: () =>
                          _confirmDisconnect(context, user.id, user.name),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            InkWell(
              onTap: () => context.push(
                AppRoutes.connections,
                extra: {'userId': user.id, 'userName': user.name},
              ),
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
