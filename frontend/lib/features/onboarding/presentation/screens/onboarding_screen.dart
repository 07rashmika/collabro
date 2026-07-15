import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_routes.dart';
import '../cubits/onboarding_cubit.dart';
import '../models/onboarding_page_data.dart';
import '../widgets/bottom_card.dart';
import '../widgets/hero_section.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => OnboardingCubit(totalPages: onboardingPages.length),
      child: const _OnboardingView(),
    );
  }
}

class _OnboardingView extends StatefulWidget {
  const _OnboardingView();

  @override
  State<_OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends State<_OnboardingView> {
  final PageController _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _next() {
    final cubit = context.read<OnboardingCubit>();
    if (cubit.state.isLastPage) {
      context.go(AppRoutes.signUp);
      return;
    }
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Scaffold(
      backgroundColor: colors.backgroundDark,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final totalH = constraints.maxHeight;
            final heroH = totalH * 0.45;
            final cardH = totalH * 0.55;

            return Stack(
              children: [
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: heroH,
                  child: HeroSection(height: heroH),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  height: cardH,
                  child: BottomCard(
                    pageController: _pageController,
                    onPageChanged: (i) =>
                        context.read<OnboardingCubit>().pageChanged(i),
                    onGetStarted: _next,
                    onSignIn: () => context.go(AppRoutes.signIn),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}