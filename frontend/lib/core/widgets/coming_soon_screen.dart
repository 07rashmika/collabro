import 'package:flutter/material.dart';

import 'package:frontend/core/constants/app_colors.dart';
import 'package:frontend/core/constants/app_spacing.dart';
import 'package:frontend/core/constants/app_typography.dart';

/// Placeholder body for tabs whose feature hasn't been built yet.
class ComingSoonScreen extends StatelessWidget {
  final String title;
  final IconData icon;

  const ComingSoonScreen({super.key, required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final typography = AppTypography.of(context);
    return Scaffold(
      backgroundColor: colors.backgroundDark,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 48, color: colors.textTertiary),
                const SizedBox(height: AppSpacing.md),
                Text(
                  '$title is coming soon.',
                  textAlign: TextAlign.center,
                  style: typography.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
