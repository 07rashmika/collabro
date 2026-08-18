import 'package:flutter/material.dart';
import 'package:frontend/features/auth/presentation/components/auth_tab_item.dart';

enum AuthTab { signIn, createAccount }

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
          child: AuthTabItem(
            label: 'Sign In',
            isActive: active == .signIn,
            onTap: onSignInTap,
          ),
        ),
        Expanded(
          child: AuthTabItem(
            label: 'Create Account',
            isActive: active == .createAccount,
            onTap: onCreateAccountTap,
          ),
        ),
      ],
    );
  }
}
