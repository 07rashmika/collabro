import 'package:flutter/material.dart';
import 'package:frontend/core/constants/app_colors.dart';
import 'package:frontend/core/constants/app_spacing.dart';
import 'package:frontend/core/constants/app_typography.dart';

class AuthTabItem extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const AuthTabItem({
    super.key,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final typography = AppTypography.of(context);
    return GestureDetector(
      onTap: isActive ? null : onTap,
      behavior: .opaque,
      child: Column(
        children: [
          Padding(
            padding: const .only(bottom: AppSpacing.md),
            child: Text(
              label,
              textAlign: .center,
              style: typography.titleMedium.copyWith(
                color: isActive ? colors.textPrimary : colors.textTertiary,
              ),
            ),
          ),
          Container(
            height: 2,
            color: isActive ? colors.textPrimary : Colors.transparent,
          ),
        ],
      ),
    );
  }
}
