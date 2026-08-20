import 'package:flutter/material.dart';
import 'package:frontend/core/constants/app_colors.dart';
import 'package:frontend/core/constants/app_spacing.dart';
import 'package:frontend/core/constants/app_typography.dart';
import 'package:frontend/core/utils/time_ago.dart';
import 'package:frontend/features/notes/domain/entities/note.dart';

/// Renders a note's AI-generated summary — only meant to be shown for a
/// [Note] that actually has one ([Note.summary] non-null).
class AiSummaryCard extends StatelessWidget {
  final Note note;
  final VoidCallback onReadMore;

  const AiSummaryCard({
    super.key,
    required this.note,
    required this.onReadMore,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final typography = AppTypography.of(context);
    return Container(
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
            crossAxisAlignment: .start,
            children: [
              Container(
                padding: const .all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.15),
                  borderRadius: .circular(AppSpacing.radiusSm),
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
                  crossAxisAlignment: .start,
                  children: [
                    Text(note.title, style: typography.titleMedium),
                    Text(
                      'Generated ${timeAgo(note.updatedAt)}',
                      style: typography.caption,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            note.summary ?? '',
            style: typography.bodySmall,
            maxLines: 2,
            overflow: .ellipsis,
          ),
          const SizedBox(height: AppSpacing.xs),
          GestureDetector(
            onTap: onReadMore,
            child: Row(
              mainAxisSize: .min,
              children: [
                Text(
                  'Read Full Summary',
                  style: typography.labelSmall.copyWith(
                    color: colors.primaryLight,
                  ),
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
