import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/core/constants/app_colors.dart';
import 'package:frontend/core/constants/app_spacing.dart';
import 'package:frontend/core/constants/app_typography.dart';
import 'package:frontend/features/settings/presentation/cubits/theme_cubit.dart';
import 'package:go_router/go_router.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final typography = AppTypography.of(context);

    return Scaffold(
      backgroundColor: colors.backgroundDark,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const .symmetric(
                horizontal: AppSpacing.screenHorizontal,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: Icon(Icons.arrow_back, color: colors.textPrimary),
                  ),
                  Expanded(
                    child: Text(
                      'Settings',
                      textAlign: .center,
                      style: typography.headlineMedium,
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const .symmetric(
                  horizontal: AppSpacing.screenHorizontal,
                ),
                children: [
                  Text(
                    'Appearance',
                    style: typography.labelSmall.copyWith(
                      color: colors.textTertiary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Material(
                    color: colors.backgroundCard,
                    borderRadius: .circular(AppSpacing.radiusMd),
                    clipBehavior: .antiAlias,
                    child: Container(
                      padding: const .symmetric(horizontal: AppSpacing.md),
                      decoration: BoxDecoration(
                        borderRadius: .circular(AppSpacing.radiusMd),
                        border: Border.all(color: colors.border),
                      ),
                      child: BlocBuilder<ThemeCubit, ThemeMode>(
                        builder: (context, mode) {
                          final isLight = mode == .light;
                          return SwitchListTile(
                            contentPadding: .zero,
                            title: Text(
                              'Light Mode',
                              style: typography.bodyLarge.copyWith(
                                color: colors.textPrimary,
                              ),
                            ),
                            subtitle: Text(
                              isLight
                                  ? 'Light theme is on'
                                  : 'Dark theme is on',
                              style: typography.bodySmall,
                            ),
                            value: isLight,
                            activeThumbColor: colors.primary,
                            onChanged: (value) =>
                                context.read<ThemeCubit>().setLightMode(value),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
