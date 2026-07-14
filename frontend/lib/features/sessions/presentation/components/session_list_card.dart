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

  const SessionListCard({
    super.key,
    required this.session,
    required this.onTap,
    this.onToggleSave,
  });

  @override
  Widget build(BuildContext context) {
    final isVideo = session.type == SessionType.video;
    final isClosed = session.status == SessionStatus.closed;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        decoration: BoxDecoration(
          color: AppColors.backgroundCard,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.backgroundElevated,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              child: Icon(
                isVideo ? Icons.videocam_outlined : Icons.chat_bubble_outline,
                color: isVideo ? AppColors.info : AppColors.primary,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.title,
                    style: AppTypography.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${session.participants.length} participants · ${timeAgo(session.updatedAt)}'
                    '${isClosed ? ' · Closed' : ''}',
                    style: AppTypography.bodySmall,
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
                  color: session.savedByMe ? AppColors.primary : AppColors.textTertiary,
                ),
                tooltip: session.savedByMe ? 'Remove from saved' : 'Save session',
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
