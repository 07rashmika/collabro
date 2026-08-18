import 'package:flutter/material.dart';
import 'package:frontend/core/constants/app_colors.dart';
import 'package:frontend/core/constants/app_spacing.dart';
import 'package:frontend/core/constants/app_typography.dart';

class NoteStatusBadge extends StatelessWidget {
  final bool isPosted;

  const NoteStatusBadge({super.key, required this.isPosted});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final typography = AppTypography.of(context);
    final color = isPosted ? colors.success : colors.textTertiary;
    return Container(
      padding: const .symmetric(horizontal: AppSpacing.sm, vertical: 3),
      decoration: BoxDecoration(
        color: isPosted
            ? colors.success.withValues(alpha: 0.12)
            : colors.chipBackground,
        border: .all(
          color: isPosted
              ? colors.success.withValues(alpha: 0.4)
              : colors.chipBorder,
        ),
        borderRadius: .circular(AppSpacing.radiusFull),
      ),
      child: Row(
        mainAxisSize: .min,
        children: [
          Icon(
            isPosted ? Icons.public : Icons.lock_outline,
            size: 12,
            color: color,
          ),
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
