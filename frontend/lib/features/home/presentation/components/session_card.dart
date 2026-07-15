import 'package:flutter/material.dart';
import 'package:frontend/core/constants/app_colors.dart';
import 'package:frontend/core/constants/app_spacing.dart';
import 'package:frontend/core/constants/app_typography.dart';
import 'package:frontend/core/utils/session_time_label.dart';
import 'package:frontend/core/widgets/pill_button.dart';
import 'package:frontend/features/sessions/domain/entities/study_session.dart';

class SessionCard extends StatelessWidget {
  final StudySession session;
  final VoidCallback onAction;
  final VoidCallback? onToggleSave;

  const SessionCard({
    super.key,
    required this.session,
    required this.onAction,
    this.onToggleSave,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final typography = AppTypography.of(context);
    final isVirtual = session.type == SessionType.video;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: colors.backgroundCard,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        session.title,
                        style: typography.titleLarge,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (session.isPublic) ...[
                      const SizedBox(width: AppSpacing.xs),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xs,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: colors.chipBackground,
                          borderRadius: BorderRadius.circular(AppSpacing.radiusXs),
                        ),
                        child: Text(
                          'Public',
                          style: typography.caption.copyWith(color: colors.primaryLight),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                _IconLabel(
                  icon: Icons.access_time,
                  label: session.scheduledAt != null
                      ? sessionTimeLabel(session.scheduledAt!)
                      : 'Time TBD',
                ),
                const SizedBox(height: 2),
                _IconLabel(
                  icon: isVirtual ? Icons.videocam_outlined : Icons.chat_bubble_outline,
                  label: isVirtual ? 'Virtual Room' : 'Text Chat',
                ),
                if (session.tags.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: session.tags.map((tag) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xs,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: colors.backgroundElevated,
                          borderRadius: BorderRadius.circular(AppSpacing.radiusXs),
                        ),
                        child: Text(tag.name, style: typography.caption),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (onToggleSave != null)
                IconButton(
                  onPressed: onToggleSave,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: Icon(
                    session.savedByMe ? Icons.bookmark : Icons.bookmark_border,
                    color: session.savedByMe ? colors.primary : colors.textTertiary,
                  ),
                  tooltip: session.savedByMe ? 'Remove from saved' : 'Save session',
                ),
              const SizedBox(height: AppSpacing.sm),
              PillButton(
                label: isVirtual ? 'Join' : 'Open',
                variant: PillButtonVariant.primary,
                onPressed: onAction,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _IconLabel extends StatelessWidget {
  final IconData icon;
  final String label;

  const _IconLabel({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final typography = AppTypography.of(context);
    return Row(
      children: [
        Icon(icon, size: AppSpacing.iconSm, color: colors.textTertiary),
        const SizedBox(width: AppSpacing.xs),
        Text(label, style: typography.bodySmall),
      ],
    );
  }
}
