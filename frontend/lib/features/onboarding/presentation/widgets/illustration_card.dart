import 'package:flutter/material.dart';
import 'package:frontend/core/constants/app_colors.dart';
import 'package:frontend/core/constants/app_spacing.dart';

class IllustrationCard extends StatelessWidget {
  const IllustrationCard({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const .all(AppSpacing.sm + 2),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard.withValues(alpha: .92),
        borderRadius: .circular(AppSpacing.radiusMd),
        border: .all(color: AppColors.border),
      ),
      child: child,
    );
  }
}
