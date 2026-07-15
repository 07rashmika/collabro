import 'package:flutter/material.dart';
import 'package:frontend/core/constants/app_colors.dart';
import 'package:frontend/core/constants/app_spacing.dart';

class IconActionButton extends StatelessWidget {
  final Widget icon;
  final VoidCallback? onPressed;

  const IconActionButton({super.key, required this.icon, this.onPressed});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return SizedBox(
      height: AppSpacing.buttonHeightMd,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.textPrimary,
          side: BorderSide(color: colors.border),
          shape: RoundedRectangleBorder(
            borderRadius: .circular(AppSpacing.radiusMd),
          ),
        ),
        child: icon,
      ),
    );
  }
}