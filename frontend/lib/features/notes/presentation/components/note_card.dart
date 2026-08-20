import 'package:flutter/material.dart';
import 'package:frontend/core/constants/app_colors.dart';
import 'package:frontend/core/constants/app_spacing.dart';
import 'package:frontend/core/constants/app_typography.dart';
import 'package:frontend/core/utils/time_ago.dart';
import 'package:frontend/core/widgets/skill_chip.dart';
import 'package:frontend/features/notes/domain/entities/note.dart';
import 'package:frontend/features/notes/presentation/components/note_status_badge.dart';

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
                Expanded(
                  child: Text(
                    note.title,
                    style: typography.titleLarge,
                    maxLines: 1,
                    overflow: .ellipsis,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                NoteStatusBadge(isPosted: note.isPublic),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              note.content,
              style: typography.bodySmall,
              maxLines: 2,
              overflow: .ellipsis,
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                if (note.tags.isNotEmpty)
                  Expanded(
                    child: Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: note.tags
                          .take(3)
                          .map((t) => SkillChip(label: t))
                          .toList(),
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
