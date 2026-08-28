import 'package:flutter/material.dart';
import 'package:frontend/core/constants/app_colors.dart';
import 'package:frontend/core/constants/app_spacing.dart';
import 'package:frontend/core/constants/app_typography.dart';

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
    final colors = AppColors.of(context);
    final typography = AppTypography.of(context);
    return Row(
      mainAxisAlignment: .spaceBetween,
      children: [
        Row(
          children: [
            if (leadingIcon != null) ...[
              Icon(leadingIcon, size: AppSpacing.iconMd, color: colors.primary),
              const SizedBox(width: AppSpacing.xs),
            ],
            Text(title, style: typography.headlineSmall),
          ],
        ),
        if (actionLabel != null)
          GestureDetector(
            onTap: onActionTap,
            child: Text(
              actionLabel!,
              style: typography.bodySmall.copyWith(color: colors.primaryLight),
            ),
          ),
      ],
    );
  }
}
