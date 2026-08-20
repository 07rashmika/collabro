import 'package:flutter/material.dart';
import 'package:frontend/core/constants/app_colors.dart';
import 'package:frontend/core/constants/app_spacing.dart';
import 'package:frontend/core/constants/app_typography.dart';

class AuthHeader extends StatelessWidget {
  final String tagline;

  const AuthHeader({super.key, required this.tagline});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final typography = AppTypography.of(context);
    return Column(
      children: [
        SizedBox(
          height: 96,
          child: Stack(
            alignment: .center,
            children: [
              Container(
                width: 160,
                height: 96,
                decoration: BoxDecoration(
                  shape: .circle,
                  gradient: RadialGradient(
                    colors: [
                      colors.primary.withValues(alpha: 0.25),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
              Text(
                'Collabro',
                style: typography.displayLarge.copyWith(color: colors.primary),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          tagline,
          textAlign: .center,
          style: typography.bodyMedium.copyWith(color: colors.textSecondary),
        ),
      ],
    );
  }
}
