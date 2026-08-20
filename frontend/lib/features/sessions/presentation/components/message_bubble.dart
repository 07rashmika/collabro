import 'package:flutter/material.dart';
import 'package:frontend/core/constants/app_colors.dart';
import 'package:frontend/core/constants/app_spacing.dart';
import 'package:frontend/core/constants/app_typography.dart';
import 'package:frontend/core/utils/time_ago.dart';
import 'package:frontend/core/widgets/user_avatar.dart';
import 'package:frontend/features/sessions/domain/entities/session_message.dart';

class MessageBubble extends StatelessWidget {
  final SessionMessage message;
  final bool isMine;
  final VoidCallback? onLongPress;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMine,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final typography = AppTypography.of(context);
    final bubble = GestureDetector(
      onLongPress: onLongPress,
      child: Container(
        margin: const .symmetric(vertical: AppSpacing.xs),
        padding: const .symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.65,
        ),
        decoration: BoxDecoration(
          color: isMine ? colors.primary : colors.backgroundCard,
          borderRadius: .only(
            topLeft: const .circular(AppSpacing.radiusMd),
            topRight: const .circular(AppSpacing.radiusMd),
            bottomLeft: .circular(isMine ? AppSpacing.radiusMd : AppSpacing.xs),
            bottomRight: .circular(
              isMine ? AppSpacing.xs : AppSpacing.radiusMd,
            ),
          ),
          border: isMine ? null : .all(color: colors.border),
        ),
        child: Column(
          crossAxisAlignment: .start,
          children: [
            if (!isMine)
              Padding(
                padding: const .only(bottom: 2),
                child: Text(
                  message.senderName,
                  style: typography.labelSmall.copyWith(
                    color: colors.primaryLight,
                  ),
                ),
              ),
            Text(
              message.content,
              style: typography.bodyMedium.copyWith(
                color: isMine ? Colors.white : colors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              timeAgo(message.createdAt),
              style: typography.caption.copyWith(
                color: isMine ? Colors.white70 : colors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );

    if (isMine) {
      return Align(alignment: .centerRight, child: bubble);
    }

    return Align(
      alignment: .centerLeft,
      child: Row(
        mainAxisSize: .min,
        crossAxisAlignment: .end,
        children: [
          UserAvatar(
            name: message.senderName,
            imageUrl: message.senderAvatarUrl,
            size: AppSpacing.avatarXs,
          ),
          const SizedBox(width: AppSpacing.xs),
          Flexible(child: bubble),
        ],
      ),
    );
  }
}
