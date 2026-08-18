import 'package:flutter/material.dart';
import 'package:frontend/core/constants/app_colors.dart';
import 'package:frontend/core/constants/app_spacing.dart';
import 'package:frontend/core/constants/app_typography.dart';

class SessionInfoBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  const SessionInfoBadge({super.key, required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final typography = AppTypography.of(context);
    return Container(
      padding: const .symmetric(horizontal: AppSpacing.sm, vertical: 4),
      decoration: BoxDecoration(
        color: colors.backgroundElevated,
        borderRadius: .circular(AppSpacing.radiusFull),
      ),
      child: Row(
        mainAxisSize: .min,
        children: [
          Icon(icon, size: AppSpacing.iconSm, color: colors.primaryLight),
          const SizedBox(width: 4),
          Text(label, style: typography.labelSmall),
        ],
      ),
    );
  }
}
