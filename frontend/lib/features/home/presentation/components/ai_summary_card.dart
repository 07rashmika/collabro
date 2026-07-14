import 'package:flutter/material.dart';
import 'package:frontend/core/constants/app_colors.dart';
import 'package:frontend/core/constants/app_spacing.dart';
import 'package:frontend/core/constants/app_typography.dart';
import 'package:frontend/features/home/presentation/models/mock_ai_summary.dart';

class AiSummaryCard extends StatelessWidget {
  final MockAiSummary summary;
  final VoidCallback onReadMore;

  const AiSummaryCard({super.key, required this.summary, required this.onReadMore});

  @override
  Widget build(BuildContext context) {
    return Container(
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: const Icon(
                  Icons.description_outlined,
                  color: AppColors.primary,
                  size: AppSpacing.iconMd,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(summary.title, style: AppTypography.titleMedium),
                    Text(summary.generatedLabel, style: AppTypography.caption),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            summary.snippet,
            style: AppTypography.bodySmall,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.xs),
          GestureDetector(
            onTap: onReadMore,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Read Full Summary',
                  style: AppTypography.labelSmall.copyWith(color: AppColors.primaryLight),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.arrow_forward, size: 12, color: AppColors.primaryLight),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
