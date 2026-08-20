import 'package:flutter/material.dart';
import 'package:frontend/core/constants/app_colors.dart';
import 'package:frontend/core/constants/app_spacing.dart';
import 'package:frontend/core/constants/app_typography.dart';

class SessionTagChip extends StatelessWidget {
  final String label;
  const SessionTagChip(this.label, {super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final typography = AppTypography.of(context);
    return Container(
      padding: const .symmetric(horizontal: AppSpacing.sm, vertical: 4),
      decoration: BoxDecoration(
        color: colors.chipBackground,
        borderRadius: .circular(AppSpacing.radiusFull),
        border: .all(color: colors.chipBorder),
      ),
      child: Text(label, style: typography.labelSmall),
    );
  }
}
