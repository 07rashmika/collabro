import 'package:flutter/material.dart';
import 'package:frontend/core/constants/app_colors.dart';
import 'package:frontend/core/constants/app_spacing.dart';
import 'package:frontend/core/constants/app_typography.dart';

/// Reusable "Section Title ... View All" row used above every dashboard
/// section (Recommended Partners, Upcoming Sessions, AI Summaries).
class DashboardSectionHeader extends StatelessWidget {
  final String title;
  final IconData? leadingIcon;
  final String? actionLabel;
  final VoidCallback? onActionTap;

  const DashboardSectionHeader({
    super.key,
    required this.title,
    this.leadingIcon,
    this.actionLabel,
    this.onActionTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            if (leadingIcon != null) ...[
              Icon(leadingIcon, size: AppSpacing.iconMd, color: AppColors.primary),
              const SizedBox(width: AppSpacing.xs),
            ],
            Text(title, style: AppTypography.headlineSmall),
          ],
        ),
        if (actionLabel != null)
          GestureDetector(
            onTap: onActionTap,
            child: Text(
              actionLabel!,
              style: AppTypography.bodySmall.copyWith(color: AppColors.primaryLight),
            ),
          ),
      ],
    );
  }
}
