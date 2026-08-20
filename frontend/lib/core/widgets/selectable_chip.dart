import 'package:flutter/material.dart';
import 'package:frontend/core/constants/app_colors.dart';
import 'package:frontend/core/constants/app_spacing.dart';
import 'package:frontend/core/constants/app_typography.dart';

class SelectableChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final String? trailingLabel;

  const SelectableChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.trailingLabel,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final typography = AppTypography.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppDuration.fast,
        padding: const .symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: selected ? colors.buttonPrimary : colors.chipBackground,
          border: .all(
            color: selected ? Colors.transparent : colors.chipBorder,
          ),
          borderRadius: .circular(AppSpacing.radiusFull),
        ),
        child: Row(
          mainAxisSize: .min,
          children: [
            Text(
              label,
              style: typography.labelSmall.copyWith(
                color: selected ? Colors.white : colors.textSecondary,
              ),
            ),
            if (trailingLabel != null) ...[
              const SizedBox(width: AppSpacing.xs),
              Text(
                '· $trailingLabel',
                style: typography.labelSmall.copyWith(
                  color: selected ? Colors.white : colors.textTertiary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
