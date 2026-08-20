import 'package:flutter/material.dart';
import 'package:frontend/core/constants/app_colors.dart';
import 'package:frontend/core/constants/app_spacing.dart';
import 'package:frontend/core/constants/app_typography.dart';

class SessionPickerField extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const SessionPickerField({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final typography = AppTypography.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: .circular(AppSpacing.radiusMd),
      child: Container(
        padding: const .symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: colors.backgroundInput,
          borderRadius: .circular(AppSpacing.radiusMd),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          children: [
            Icon(icon, size: AppSpacing.iconSm, color: colors.textTertiary),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                label,
                style: typography.bodyMedium,
                overflow: .ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
