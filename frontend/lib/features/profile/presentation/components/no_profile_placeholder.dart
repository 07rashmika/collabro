import 'package:flutter/material.dart';
import 'package:frontend/core/constants/app_routes.dart';
import 'package:frontend/core/constants/app_spacing.dart';
import 'package:frontend/core/constants/app_typography.dart';
import 'package:frontend/core/widgets/primary_button.dart';
import 'package:frontend/features/auth/domain/entities/app_user.dart';
import 'package:go_router/go_router.dart';

class NoProfilePlaceholder extends StatelessWidget {
  final AppUser user;

  const NoProfilePlaceholder({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final typography = AppTypography.of(context);
    return Column(
      children: [
        Text(
          "You haven't finished setting up your profile yet.",
          style: typography.bodyMedium,
          textAlign: .center,
        ),
        const SizedBox(height: AppSpacing.lg),
        PrimaryButton(
          label: 'Complete Profile',
          onPressed: () => context.go(AppRoutes.profileSetup, extra: user),
        ),
      ],
    );
  }
}
