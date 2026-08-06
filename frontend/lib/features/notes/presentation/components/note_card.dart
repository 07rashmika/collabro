import 'package:flutter/material.dart';
import 'package:frontend/core/constants/app_colors.dart';
import 'package:frontend/core/constants/app_spacing.dart';
import 'package:frontend/core/constants/app_typography.dart';
import 'package:frontend/core/utils/time_ago.dart';
import 'package:frontend/core/widgets/skill_chip.dart';
import 'package:frontend/features/notes/domain/entities/note.dart';

class NoteCard extends StatelessWidget {
  final Note note;
  final VoidCallback onTap;

  const NoteCard({super.key, required this.note, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final typography = AppTypography.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      child: Container(
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
                Expanded(
                  child: Text(
                    note.title,
                    style: typography.titleLarge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                _StatusBadge(isPosted: note.isPublic),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              note.content,
              style: typography.bodySmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                if (note.tags.isNotEmpty)
                  Expanded(
                    child: Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: note.tags.take(3).map((t) => SkillChip(label: t)).toList(),
                    ),
                  )
                else
                  const Spacer(),
                Text(timeAgo(note.updatedAt), style: typography.caption),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// "Posted" (public) vs "Draft" (private) indicator — a note exists here as
/// soon as it's been summarized, whether or not it's actually been posted.
class _StatusBadge extends StatelessWidget {
  final bool isPosted;

  const _StatusBadge({required this.isPosted});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final typography = AppTypography.of(context);
    final color = isPosted ? colors.success : colors.textTertiary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 3),
      decoration: BoxDecoration(
        color: isPosted ? colors.success.withValues(alpha: 0.12) : colors.chipBackground,
        border: Border.all(color: isPosted ? colors.success.withValues(alpha: 0.4) : colors.chipBorder),
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isPosted ? Icons.public : Icons.lock_outline, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            isPosted ? 'Posted' : 'Draft',
            style: typography.labelSmall.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}
