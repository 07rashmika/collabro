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
    final colors = AppColors.of(context);
    final typography = AppTypography.of(context);
    return Container(
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: Icon(
                  Icons.description_outlined,
                  color: colors.primary,
                  size: AppSpacing.iconMd,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(summary.title, style: typography.titleMedium),
                    Text(summary.generatedLabel, style: typography.caption),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            summary.snippet,
            style: typography.bodySmall,
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
                  style: typography.labelSmall.copyWith(color: colors.primaryLight),
                ),
                const SizedBox(width: 4),
                Icon(Icons.arrow_forward, size: 12, color: colors.primaryLight),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
