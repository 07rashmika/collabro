import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../models/onboarding_page_data.dart';

class PageContent extends StatelessWidget {
  final OnboardingPageData page;
  const PageContent({super.key, required this.page});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final typography = AppTypography.of(context);
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: .start,
        children: [
          FittedBox(
            fit: .scaleDown,
            alignment: .centerLeft,
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: '${page.headline1}\n',
                    style: typography.headlineLarge,
                  ),
                  TextSpan(
                    text: '${page.headline2}\n',
                    style: typography.headlineLarge,
                  ),
                  TextSpan(
                    text: page.headline3,
                    style: typography.headlineLarge.copyWith(
                      color: colors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            page.body,
            style: typography.bodyMedium,
            maxLines: 3,
            overflow: .ellipsis,
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Icon(
                Icons.verified_outlined,
                size: 13,
                color: colors.textTertiary,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  page.badge,
                  style: typography.caption,
                  overflow: .ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
