import 'package:flutter/material.dart';
import 'package:frontend/core/constants/app_colors.dart';
import 'package:frontend/core/constants/app_spacing.dart';
import 'package:frontend/core/constants/app_typography.dart';

class SessionInfoIconLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  const SessionInfoIconLabel({super.key, required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final typography = AppTypography.of(context);
    return Row(
      children: [
        Icon(icon, size: AppSpacing.iconSm, color: colors.textTertiary),
        const SizedBox(width: AppSpacing.xs),
        Text(label, style: typography.bodySmall),
      ],
    );
  }
}
