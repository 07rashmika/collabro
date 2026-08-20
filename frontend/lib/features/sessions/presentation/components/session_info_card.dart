import 'package:flutter/material.dart';
import 'package:frontend/core/constants/app_colors.dart';
import 'package:frontend/core/constants/app_spacing.dart';

class SessionInfoCard extends StatelessWidget {
  final List<Widget> children;
  const SessionInfoCard({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      width: .infinity,
      padding: const .all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: colors.backgroundCard,
        borderRadius: .circular(AppSpacing.radiusLg),
        border: .all(color: colors.border),
      ),
      child: Column(crossAxisAlignment: .start, children: children),
    );
  }
}
