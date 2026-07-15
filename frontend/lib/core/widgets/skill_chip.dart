import 'package:flutter/material.dart';
import 'package:frontend/core/constants/app_colors.dart';
import 'package:frontend/core/constants/app_spacing.dart';
import 'package:frontend/core/constants/app_typography.dart';

/// Small outlined tag used for skills/subjects, e.g. "Python".
class SkillChip extends StatelessWidget {
  final String label;

  const SkillChip({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final typography = AppTypography.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
      decoration: BoxDecoration(
        color: colors.chipBackground,
        border: Border.all(color: colors.chipBorder),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Text(label, style: typography.labelSmall),
    );
  }
}
