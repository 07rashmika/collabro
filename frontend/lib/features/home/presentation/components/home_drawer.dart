import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/core/constants/app_colors.dart';
import 'package:frontend/core/constants/app_spacing.dart';
import 'package:frontend/core/constants/app_typography.dart';
import 'package:frontend/core/widgets/secondary_button.dart';
import 'package:frontend/core/widgets/user_avatar.dart';
import 'package:frontend/features/auth/domain/entities/app_user.dart';
import 'package:frontend/features/auth/presentation/cubits/auth_cubit.dart';
import 'package:frontend/features/settings/presentation/cubits/notification_preferences_cubit.dart';
import 'package:frontend/features/settings/presentation/cubits/theme_cubit.dart';

class HomeDrawer extends StatelessWidget {
  final AppUser user;

  const HomeDrawer({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final typography = AppTypography.of(context);

    return Drawer(
      backgroundColor: colors.backgroundCard,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: .start,
          children: [
            Padding(
              padding: const .all(AppSpacing.screenHorizontal),
              child: Row(
                children: [
                  UserAvatar(
                    name: user.name,
                    imageUrl: user.avatarUrl,
                    size: AppSpacing.avatarLg,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: .start,
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
            BlocBuilder<NotificationPreferencesCubit, NotificationPreferences>(
              builder: (context, prefs) {
                final cubit = context.read<NotificationPreferencesCubit>();
                return ExpansionTile(
                  leading: Icon(
                    Icons.notifications_outlined,
                    color: colors.textSecondary,
                  ),
                  title: Text(
                    'Notifications',
                    style: typography.bodyMedium.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                  trailing: Switch(
                    value: prefs.anyEnabled,
                    activeThumbColor: colors.primary,
                    onChanged: cubit.setAll,
                  ),
                  children: [
                    SwitchListTile(
                      contentPadding: const .only(
                        left: AppSpacing.xxl,
                        right: AppSpacing.screenHorizontal,
                      ),
                      title: Text(
                        'Message Notifications',
                        style: typography.bodySmall.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                      value: prefs.messageNotifications,
                      activeThumbColor: colors.primary,
                      onChanged: cubit.setMessageNotifications,
                    ),
                    SwitchListTile(
                      contentPadding: const .only(
                        left: AppSpacing.xxl,
                        right: AppSpacing.screenHorizontal,
                      ),
                      title: Text(
                        'Connection Notifications',
                        style: typography.bodySmall.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                      value: prefs.connectionNotifications,
                      activeThumbColor: colors.primary,
                      onChanged: cubit.setConnectionNotifications,
                    ),
                    SwitchListTile(
                      contentPadding: const .only(
                        left: AppSpacing.xxl,
                        right: AppSpacing.screenHorizontal,
                      ),
                      title: Text(
                        'Video Session Notifications',
                        style: typography.bodySmall.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                      value: prefs.videoSessionNotifications,
                      activeThumbColor: colors.primary,
                      onChanged: cubit.setVideoSessionNotifications,
                    ),
                  ],
                );
              },
            ),
            Divider(color: colors.border, height: 1),
            BlocBuilder<ThemeCubit, ThemeMode>(
              builder: (context, mode) {
                final isLight = mode == .light;
                return SwitchListTile(
                  secondary: Icon(
                    Icons.light_mode_outlined,
                    color: colors.textSecondary,
                  ),
                  title: Text(
                    'Light Mode',
                    style: typography.bodyMedium.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                  value: isLight,
                  activeThumbColor: colors.primary,
                  onChanged: (value) =>
                      context.read<ThemeCubit>().setLightMode(value),
                );
              },
            ),
            const Spacer(),
            Padding(
              padding: const .all(AppSpacing.screenHorizontal),
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
