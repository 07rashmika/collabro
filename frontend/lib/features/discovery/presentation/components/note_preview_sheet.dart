import 'package:flutter/material.dart';
import 'package:frontend/core/constants/app_colors.dart';
import 'package:frontend/core/constants/app_spacing.dart';
import 'package:frontend/core/constants/app_typography.dart';
import 'package:frontend/core/utils/time_ago.dart';
import 'package:frontend/core/widgets/skill_chip.dart';
import 'package:frontend/core/widgets/user_avatar.dart';
import 'package:frontend/features/notes/domain/entities/note.dart';

void showNotePreviewSheet(BuildContext context, Note note) {
  final colors = AppColors.of(context);
  final typography = AppTypography.of(context);

  showModalBottomSheet<void>(
    context: context,
    backgroundColor: colors.backgroundCard,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: .vertical(top: .circular(AppSpacing.radiusXl)),
    ),
    builder: (sheetContext) {
      return DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return SingleChildScrollView(
            controller: scrollController,
            padding: const .all(AppSpacing.cardPadding),
            child: Column(
              crossAxisAlignment: .start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colors.border,
                      borderRadius: .circular(AppSpacing.radiusFull),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(note.title, style: typography.headlineSmall),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    UserAvatar(
                      name: note.authorName,
                      size: AppSpacing.avatarSm,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(note.authorName, style: typography.bodySmall),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      '· ${timeAgo(note.updatedAt)}',
                      style: typography.caption,
                    ),
                  ],
                ),
                if (note.tags.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: note.tags
                        .map((t) => SkillChip(label: t))
                        .toList(),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                Text(note.content, style: typography.bodyLarge),
                const SizedBox(height: AppSpacing.xl),
              ],
            ),
          );
        },
      );
    },
  );
}
