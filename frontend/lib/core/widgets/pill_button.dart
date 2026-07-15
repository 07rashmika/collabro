import 'package:flutter/material.dart';
import 'package:frontend/core/constants/app_colors.dart';
import 'package:frontend/core/constants/app_spacing.dart';
import 'package:frontend/core/constants/app_typography.dart';

enum PillButtonVariant { primary, muted }

/// Compact rounded button for inline actions (e.g. "Join" on a session
/// card) where the full-width [PrimaryButton]/[SecondaryButton] don't fit.
class PillButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final PillButtonVariant variant;

  const PillButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = PillButtonVariant.primary,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final typography = AppTypography.of(context);
    final isPrimary = variant == PillButtonVariant.primary;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: isPrimary ? colors.primaryGradient : null,
        color: isPrimary ? null : colors.backgroundElevated,
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
      ),
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusFull)),
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
