import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/core/widgets/primary_button.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../cubits/onboarding_cubit.dart';
import '../models/onboarding_page_data.dart';
import 'page_content.dart';

class BottomCard extends StatelessWidget {
  final PageController pageController;
  final void Function(int) onPageChanged;
  final VoidCallback onGetStarted;
  final VoidCallback onSignIn;

  const BottomCard({
    super.key,
    required this.pageController,
    required this.onPageChanged,
    required this.onGetStarted,
    required this.onSignIn,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.screenHorizontal,
        AppSpacing.xl,
        AppSpacing.screenHorizontal,
        bottomPad + AppSpacing.xl,
      ),
      decoration: const BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(AppSpacing.radiusXxl),
          topRight: Radius.circular(AppSpacing.radiusXxl),
        ),
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.max,
        children: [
          SmoothPageIndicator(
            controller: pageController,
            count: onboardingPages.length,
            effect: ExpandingDotsEffect(
              activeDotColor: AppColors.primary,
              dotColor: AppColors.border,
              dotHeight: 6,
              dotWidth: 6,
              expansionFactor: 4,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Expanded(
            child: PageView.builder(
              controller: pageController,
              onPageChanged: onPageChanged,
              itemCount: onboardingPages.length,
              itemBuilder: (_, i) => PageContent(page: onboardingPages[i]),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          BlocBuilder<OnboardingCubit, OnboardingState>(
            buildWhen: (prev, curr) => prev.isLastPage != curr.isLastPage,
            builder: (context, state) {
              return PrimaryButton(
                label: state.isLastPage ? 'Get Started' : 'Next',
                trailingIcon: Icons.arrow_forward,
                onPressed: onGetStarted,
              );
            },
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Already have an account? ',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              GestureDetector(
                onTap: onSignIn,
                child: Text(
                  'Sign In',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}