import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:frontend/core/constants/app_colors.dart';
import 'package:frontend/core/constants/app_routes.dart';
import 'package:frontend/core/constants/app_spacing.dart';
import 'package:frontend/core/constants/app_typography.dart';
import 'package:frontend/core/widgets/secondary_button.dart';
import 'package:frontend/core/widgets/user_avatar.dart';
import 'package:frontend/features/auth/domain/entities/app_user.dart';
import 'package:frontend/features/auth/presentation/cubits/auth_cubit.dart';

class HomeDrawer extends StatelessWidget {
  final AppUser user;

  const HomeDrawer({super.key, required this.user});

  void _openSettings(BuildContext context) {
    Navigator.pop(context);
    context.push(AppRoutes.settings);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final typography = AppTypography.of(context);

    return Drawer(
      backgroundColor: colors.backgroundCard,
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
                        Text(user.name, style: typography.titleLarge),
                        Text(user.email, style: typography.bodySmall),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Divider(color: colors.border, height: 1),
            ListTile(
              leading: Icon(
                Icons.settings_outlined,
                color: colors.textSecondary,
              ),
              title: Text(
                'Settings',
                style: typography.bodyMedium.copyWith(
                  color: colors.textPrimary,
                ),
              ),
              onTap: () => _openSettings(context),
            ),
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
