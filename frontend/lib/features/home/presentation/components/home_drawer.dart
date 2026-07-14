import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:frontend/core/constants/app_colors.dart';
import 'package:frontend/core/constants/app_spacing.dart';
import 'package:frontend/core/constants/app_typography.dart';
import 'package:frontend/core/widgets/secondary_button.dart';
import 'package:frontend/core/widgets/user_avatar.dart';
import 'package:frontend/features/auth/domain/entities/app_user.dart';
import 'package:frontend/features/auth/presentation/cubits/auth_cubit.dart';

class HomeDrawer extends StatelessWidget {
  final AppUser user;

  const HomeDrawer({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.backgroundCard,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
              child: Row(
                children: [
                  UserAvatar(name: user.name, size: AppSpacing.avatarLg),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user.name, style: AppTypography.titleLarge),
                        Text(user.email, style: AppTypography.bodySmall),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: AppColors.border, height: 1),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
              child: BlocBuilder<AuthCubit, AuthState>(
                builder: (context, state) {
                  return SecondaryButton(
                    label: 'Log Out',
                    leadingIcon: Icons.logout,
                    isLoading: state is AuthLoading,
                    onPressed: () => context.read<AuthCubit>().logout(),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
