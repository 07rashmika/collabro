import 'package:flutter/material.dart';
import 'package:frontend/core/constants/app_spacing.dart';
import 'package:frontend/core/constants/app_typography.dart';

class DiscoverySection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const DiscoverySection({super.key, required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final typography = AppTypography.of(context);
    return Padding(
      padding: const .only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: .start,
        children: [
          Text(title, style: typography.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          for (final child in children) ...[
            child,
            const SizedBox(height: AppSpacing.md),
          ],
        ],
      ),
    );
  }
}
