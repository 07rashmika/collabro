import 'package:flutter/material.dart';

import 'package:frontend/core/constants/app_colors.dart';
import 'package:frontend/core/constants/app_spacing.dart';
import 'package:frontend/core/constants/app_typography.dart';
import 'package:frontend/core/widgets/skill_chip.dart';
import 'package:frontend/core/widgets/user_avatar.dart';
import 'package:frontend/features/users/domain/entities/public_user.dart';

/// Self-contained card for a Discovery "Users" search result — mirrors
/// [PartnerMatchCard]'s no-detail-screen approach, since there's no
/// read-only profile viewer screen yet.
class DiscoveryUserCard extends StatelessWidget {
  final PublicUser user;
  final VoidCallback onConnect;

  const DiscoveryUserCard({super.key, required this.user, required this.onConnect});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final typography = AppTypography.of(context);
    final skillNames = user.skills.map((s) => s.name).take(4).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: colors.backgroundCard,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              UserAvatar(name: user.name, size: AppSpacing.avatarMd),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name,
                      style: typography.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${user.notesCount} notes · ${user.sessionsCount} sessions',
                      style: typography.caption,
                    ),
                  ],
                ),
              ),
              OutlinedButton(
                onPressed: onConnect,
                style: OutlinedButton.styleFrom(
                  foregroundColor: colors.primary,
                  side: BorderSide(color: colors.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                  ),
                ),
                child: const Text('Connect'),
              ),
            ],
          ),
          if (user.bio != null && user.bio!.trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              user.bio!,
              style: typography.bodySmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
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
    );
  }
}
