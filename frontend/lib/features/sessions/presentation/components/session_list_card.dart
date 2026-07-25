import 'package:flutter/material.dart';

import 'package:frontend/core/constants/app_colors.dart';
import 'package:frontend/core/constants/app_spacing.dart';
import 'package:frontend/core/constants/app_typography.dart';
import 'package:frontend/core/utils/time_ago.dart';
import 'package:frontend/core/widgets/pill_button.dart';
import 'package:frontend/features/sessions/domain/entities/study_session.dart';

class SessionListCard extends StatelessWidget {
  final StudySession session;
  final VoidCallback onTap;
  final VoidCallback? onToggleSave;
  final VoidCallback? onSummarize;

  const SessionListCard({
    super.key,
    required this.session,
    required this.onTap,
    this.onToggleSave,
    this.onSummarize,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final typography = AppTypography.of(context);
    final isVideo = session.type == SessionType.video;
    final isClosed = session.status == SessionStatus.closed;

    return InkWell(
      // Closed sessions have nothing left to open — the chat/call screen
      // just errors out trying to join a room that no longer accepts
      // connections. Summarizing (below) is the only action left for one.
      onTap: isClosed ? null : onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        decoration: BoxDecoration(
          color: colors.backgroundCard,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colors.backgroundElevated,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              child: Icon(
                isVideo ? Icons.videocam_outlined : Icons.chat_bubble_outline,
                color: isVideo ? colors.info : colors.primary,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.title,
                    style: typography.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${session.participants.length} participants · ${timeAgo(session.updatedAt)}'
                    '${isClosed ? ' · Closed' : ''}',
                    style: typography.bodySmall,
                  ),
                ],
              ),
            ),
            if (onToggleSave != null)
              IconButton(
                onPressed: onToggleSave,
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  session.savedByMe ? Icons.bookmark : Icons.bookmark_border,
                  color: session.savedByMe ? colors.primary : colors.textTertiary,
                ),
                tooltip: session.savedByMe ? 'Remove from saved' : 'Save session',
              ),
            if (isClosed && onSummarize != null)
              IconButton(
                onPressed: onSummarize,
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.auto_awesome, color: colors.primary),
                tooltip: 'Get AI summary',
              ),
            const SizedBox(width: AppSpacing.sm),
            if (!isClosed)
              PillButton(
                label: isVideo ? 'Join' : 'Open',
                onPressed: onTap,
              ),
          ],
        ),
      ),
    );
  }
}
