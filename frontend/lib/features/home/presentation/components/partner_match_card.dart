import 'package:flutter/material.dart';
import 'package:frontend/core/constants/app_colors.dart';
import 'package:frontend/core/constants/app_spacing.dart';
import 'package:frontend/core/constants/app_typography.dart';
import 'package:frontend/core/widgets/match_score_badge.dart';
import 'package:frontend/core/widgets/primary_button.dart';
import 'package:frontend/core/widgets/skill_chip.dart';
import 'package:frontend/core/widgets/user_avatar.dart';
import 'package:frontend/features/matching/domain/entities/match_candidate.dart';

class PartnerMatchCard extends StatelessWidget {
  final MatchCandidate candidate;
  final VoidCallback onConnect;

  const PartnerMatchCard({super.key, required this.candidate, required this.onConnect});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              UserAvatar(name: candidate.name),
              MatchScoreBadge(score: candidate.matchScore),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(candidate.name, style: AppTypography.titleLarge),
          if (candidate.topCategory != null) ...[
            const SizedBox(height: 2),
            Text(
              candidate.topCategory!,
              style: AppTypography.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          if (candidate.displaySkills.isNotEmpty)
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: candidate.displaySkills.map((s) => SkillChip(label: s)).toList(),
            ),
          const SizedBox(height: AppSpacing.md),
          PrimaryButton(label: 'Connect', onPressed: onConnect),
        ],
      ),
    );
  }
}
