import 'package:flutter/material.dart';
import 'package:frontend/core/constants/app_colors.dart';
import 'package:frontend/core/constants/app_spacing.dart';
import 'package:frontend/core/constants/app_typography.dart';
import 'package:frontend/core/widgets/connect_button.dart';
import 'package:frontend/core/widgets/match_score_badge.dart';
import 'package:frontend/core/widgets/skill_chip.dart';
import 'package:frontend/core/widgets/user_avatar.dart';
import 'package:frontend/features/matching/domain/entities/match_candidate.dart';

class PartnerMatchCard extends StatelessWidget {
  final MatchCandidate candidate;
  final ConnectStatus connectStatus;
  final VoidCallback onConnect;
  final VoidCallback? onTap;

  const PartnerMatchCard({
    super.key,
    required this.candidate,
    required this.onConnect,
    this.connectStatus = .none,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final typography = AppTypography.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: .circular(AppSpacing.radiusLg),
      child: Container(
        width: 220,
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
              mainAxisAlignment: .spaceBetween,
              children: [
                UserAvatar(name: candidate.name, imageUrl: candidate.avatarUrl),
                MatchScoreBadge(score: candidate.matchScore),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(candidate.name, style: typography.titleLarge),
            if (candidate.topCategory != null) ...[
              const SizedBox(height: 2),
              Text(
                candidate.topCategory!,
                style: typography.bodySmall,
                maxLines: 1,
                overflow: .ellipsis,
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            if (candidate.displaySkills.isNotEmpty)
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: candidate.displaySkills
                    .map((s) => SkillChip(label: s))
                    .toList(),
              ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: .infinity,
              child: ConnectButton(onPressed: onConnect, status: connectStatus),
            ),
          ],
        ),
      ),
    );
  }
}
