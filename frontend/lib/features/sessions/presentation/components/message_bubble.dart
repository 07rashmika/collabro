import 'package:flutter/material.dart';

import 'package:frontend/core/constants/app_colors.dart';
import 'package:frontend/core/constants/app_spacing.dart';
import 'package:frontend/core/constants/app_typography.dart';
import 'package:frontend/core/utils/time_ago.dart';
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
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: onLongPress,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
          decoration: BoxDecoration(
            color: isMine ? AppColors.primary : AppColors.backgroundCard,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(AppSpacing.radiusMd),
              topRight: const Radius.circular(AppSpacing.radiusMd),
              bottomLeft: Radius.circular(isMine ? AppSpacing.radiusMd : AppSpacing.xs),
              bottomRight: Radius.circular(isMine ? AppSpacing.xs : AppSpacing.radiusMd),
            ),
            border: isMine ? null : Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isMine)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    message.senderName,
                    style: AppTypography.labelSmall.copyWith(color: AppColors.primaryLight),
                  ),
                ),
              Text(
                message.content,
                style: AppTypography.bodyMedium.copyWith(
                  color: isMine ? Colors.white : AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                timeAgo(message.createdAt),
                style: AppTypography.caption.copyWith(
                  color: isMine ? Colors.white70 : AppColors.textTertiary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
