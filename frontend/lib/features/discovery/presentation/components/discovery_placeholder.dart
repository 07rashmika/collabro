import 'package:flutter/material.dart';
import 'package:frontend/core/constants/app_colors.dart';
import 'package:frontend/core/constants/app_spacing.dart';
import 'package:frontend/core/constants/app_typography.dart';

class DiscoveryPlaceholder extends StatelessWidget {
  final String message;

  const DiscoveryPlaceholder({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final typography = AppTypography.of(context);
    return Center(
      child: Padding(
        padding: const .symmetric(horizontal: AppSpacing.xl),
        child: Column(
          mainAxisSize: .min,
          children: [
            Icon(
              Icons.search,
              size: AppSpacing.iconXl,
              color: colors.textTertiary,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(message, textAlign: .center, style: typography.bodySmall),
          ],
        ),
      ),
    );
  }
}
