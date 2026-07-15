import 'package:flutter/material.dart';
import 'package:frontend/core/constants/app_colors.dart';
import 'package:frontend/core/constants/app_spacing.dart';
import 'package:frontend/core/constants/app_typography.dart';

enum AuthTab { signIn, createAccount }

/// Underlined "Sign In / Create Account" tab switcher at the top of the
/// auth card. Navigation between the two routes is handled by the caller.
class AuthTabBar extends StatelessWidget {
  final AuthTab active;
  final VoidCallback onSignInTap;
  final VoidCallback onCreateAccountTap;

  const AuthTabBar({
    super.key,
    required this.active,
    required this.onSignInTap,
    required this.onCreateAccountTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _Tab(
            label: 'Sign In',
            isActive: active == AuthTab.signIn,
            onTap: onSignInTap,
          ),
        ),
        Expanded(
          child: _Tab(
            label: 'Create Account',
            isActive: active == AuthTab.createAccount,
            onTap: onCreateAccountTap,
          ),
        ),
      ],
    );
  }
}

class _Tab extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _Tab({required this.label, required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final typography = AppTypography.of(context);
    return GestureDetector(
      onTap: isActive ? null : onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Text(
              label,
              textAlign: TextAlign.center,
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
