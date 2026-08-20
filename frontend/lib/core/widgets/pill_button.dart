import 'package:flutter/material.dart';
import 'package:frontend/core/constants/app_colors.dart';
import 'package:frontend/core/constants/app_spacing.dart';
import 'package:frontend/core/constants/app_typography.dart';

enum PillButtonVariant { primary, muted }

class PillButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final PillButtonVariant variant;

  const PillButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = .primary,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final typography = AppTypography.of(context);
    final isPrimary = variant == .primary;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: isPrimary ? colors.buttonPrimary : colors.backgroundElevated,
        borderRadius: .circular(AppSpacing.radiusFull),
      ),
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          padding: const .symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          minimumSize: Size.zero,
          tapTargetSize: .shrinkWrap,
          shape: RoundedRectangleBorder(
            borderRadius: .circular(AppSpacing.radiusFull),
          ),
        ),
        child: Text(
          label,
          style: typography.labelMedium.copyWith(
            color: isPrimary ? Colors.white : colors.textSecondary,
          ),
        ),
      ),
    );
  }
}
