import 'package:flutter/material.dart';
import 'package:frontend/core/constants/app_colors.dart';
import 'package:frontend/core/constants/app_spacing.dart';
import 'package:frontend/core/constants/app_typography.dart';

class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? trailingIcon;
  final IconData? leadingIcon;

  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.trailingIcon,
    this.leadingIcon,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final typography = AppTypography.of(context);
    return SizedBox(
      height: AppSpacing.buttonHeightMd,
      width: .infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: onPressed == null ? colors.backgroundElevated : colors.buttonPrimary,
          borderRadius: .circular(AppSpacing.radiusMd),
        ),
        child: ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            foregroundColor: Colors.white,
            disabledForegroundColor: colors.textTertiary,
            disabledBackgroundColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: .circular(AppSpacing.radiusMd),
            ),
          ),
          child: isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(Colors.white),
                  ),
                )
              : Row(
                  mainAxisAlignment: .center,
                  children: [
                    if (leadingIcon != null) ...[
                      Icon(leadingIcon, size: AppSpacing.iconMd),
                      const SizedBox(width: AppSpacing.sm),
                    ],
                    Text(
                      label,
                      style: typography.labelLarge.copyWith(
                        color: Colors.white,
                      ),
                    ),
                    if (trailingIcon != null) ...[
                      const SizedBox(width: AppSpacing.sm),
                      Icon(trailingIcon, size: AppSpacing.iconMd),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}
