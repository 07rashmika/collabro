import 'package:flutter/material.dart';
import 'package:frontend/core/constants/app_colors.dart';
import 'package:frontend/features/onboarding/presentation/widgets/floating_card_illustration.dart';

class HeroSection extends StatelessWidget {
  const HeroSection({super.key, required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0E0E14), Color(0xFF1A103A), Color(0xFF0E0E14)],
          begin: .topCenter,
          end: .bottomCenter,
        ),
      ),
      child: Stack(
        alignment: .center,
        children: [
          Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              shape: .circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.22),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          const FloatingCardIllustration(),
        ],
      ),
    );
  }
}
