import 'package:flutter/material.dart';
import 'package:frontend/core/constants/app_colors.dart';
import 'package:frontend/core/constants/app_spacing.dart';
import 'package:frontend/features/onboarding/presentation/widgets/illustration_card.dart';

class FloatingCardIllustration extends StatelessWidget {
  const FloatingCardIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return SizedBox(
      width: 240,
      height: 240,
      child: Stack(
        children: [
          Positioned(
            child: IllustrationCard(
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: .3),
                  borderRadius: .circular(AppSpacing.radiusSm),
                ),
                child: Icon(
                  Icons.group,
                  color: colors.primary,
                  size: 22,
                ),
              ),
            ),
          ),
          Positioned(
            top: 50,
            right: 8,
            child: IllustrationCard(
              child: Column(
                crossAxisAlignment: .start,
                children: [
                  Container(
                    width: 72,
                    height: 7,
                    margin: const .only(bottom: 5),
                    color: colors.primary.withValues(alpha: .5),
                  ),
                  Container(width: 50, height: 7, color: colors.border),
                ],
              ),
            ),
          ),
          Positioned(
            top: 70,
            left: 70,
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: .circle,
                gradient: RadialGradient(
                  colors: [
                    colors.primary.withValues(alpha: 0.38),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Icon(
                Icons.auto_awesome,
                color: colors.primary,
                size: 32,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
