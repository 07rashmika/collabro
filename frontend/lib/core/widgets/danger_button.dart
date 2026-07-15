import 'package:flutter/material.dart';
import 'package:frontend/core/constants/app_colors.dart';
import 'package:frontend/core/constants/app_spacing.dart';
import 'package:frontend/core/constants/app_typography.dart';

class DangerButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  const DangerButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final typography = AppTypography.of(context);
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(foregroundColor: colors.error),
      child: Row(
        mainAxisAlignment: .center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: AppSpacing.iconMd),
            const SizedBox(width: AppSpacing.sm),
          ],
          Text(
            label,
            style: typography.labelMedium.copyWith(color: colors.error),
          ),
        ],
      ),
    );
  }
}
