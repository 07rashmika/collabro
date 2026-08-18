import 'package:flutter/material.dart';
import 'package:frontend/core/constants/app_colors.dart';
import 'package:frontend/core/constants/app_typography.dart';

class SessionInfoSectionLabel extends StatelessWidget {
  final String label;
  const SessionInfoSectionLabel(this.label, {super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final typography = AppTypography.of(context);
    return Text(
      label.toUpperCase(),
      style: typography.labelSmall.copyWith(
        color: colors.textTertiary,
        letterSpacing: 0.6,
      ),
    );
  }
}
