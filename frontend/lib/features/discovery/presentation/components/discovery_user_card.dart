import 'package:flutter/material.dart';
import 'package:frontend/core/constants/app_colors.dart';
import 'package:frontend/core/constants/app_spacing.dart';
import 'package:frontend/core/constants/app_typography.dart';
import 'package:frontend/core/widgets/connect_button.dart';
import 'package:frontend/core/widgets/skill_chip.dart';
import 'package:frontend/core/widgets/user_avatar.dart';
import 'package:frontend/features/users/domain/entities/public_user.dart';

class DiscoveryUserCard extends StatelessWidget {
  final PublicUser user;
  final ConnectStatus connectStatus;
  final VoidCallback onConnect;
  final VoidCallback? onTap;

  const DiscoveryUserCard({
    super.key,
    required this.user,
    required this.onConnect,
    this.connectStatus = .none,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final typography = AppTypography.of(context);
    final skillNames = user.skills.map((s) => s.name).take(4).toList();

    return InkWell(
      onTap: onTap,
      borderRadius: .circular(AppSpacing.radiusLg),
      child: Container(
        width: .infinity,
        padding: const .all(AppSpacing.cardPadding),
        decoration: BoxDecoration(
          color: colors.backgroundCard,
          borderRadius: .circular(AppSpacing.radiusLg),
          border: .all(color: colors.border),
        ),
        child: Column(
          crossAxisAlignment: .start,
          children: [
            Row(
              children: [
                UserAvatar(
                  name: user.name,
                  imageUrl: user.avatarUrl,
                  size: AppSpacing.avatarMd,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: .start,
                    children: [
                      Text(
                        user.name,
                        style: typography.titleMedium,
                        maxLines: 1,
                        overflow: .ellipsis,
                      ),
                      Text(
                        'User',
                        style: typography.caption.copyWith(
                          color: colors.textTertiary,
                        ),
                      ),
                      Text(
                        '${user.notesCount} notes · ${user.sessionsCount} sessions',
                        style: typography.caption,
                      ),
                    ],
                  ),
                ),
                ConnectButton(onPressed: onConnect, status: connectStatus),
              ],
            ),
            if (user.bio != null && user.bio!.trim().isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                user.bio!,
                style: typography.bodySmall,
                maxLines: 2,
                overflow: .ellipsis,
              ),
            ],
            if (skillNames.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: skillNames.map((s) => SkillChip(label: s)).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
