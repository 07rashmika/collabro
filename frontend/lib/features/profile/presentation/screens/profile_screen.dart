import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/core/constants/app_colors.dart';
import 'package:frontend/core/constants/app_routes.dart';
import 'package:frontend/core/constants/app_spacing.dart';
import 'package:frontend/core/constants/app_typography.dart';
import 'package:frontend/features/auth/domain/repos/auth_repo.dart';
import 'package:frontend/features/profiles/domain/repos/profiles_repo.dart';
import 'package:go_router/go_router.dart';

import '../components/profile_body.dart';
import '../cubits/profile_cubit.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ProfileCubit(
        authRepo: context.read<AuthRepo>(),
        profilesRepo: context.read<ProfilesRepo>(),
      )..loadProfile(),
      child: const _ProfileView(),
    );
  }
}

class _ProfileView extends StatelessWidget {
  const _ProfileView();

  Future<void> _openEdit(BuildContext context) async {
    final saved = await context.push<bool>(AppRoutes.editProfile);
    if (context.mounted && saved == true) {
      context.read<ProfileCubit>().loadProfile();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final typography = AppTypography.of(context);
    return Scaffold(
      backgroundColor: colors.backgroundDark,
      body: SafeArea(
        child: BlocBuilder<ProfileCubit, ProfileState>(
          builder: (context, state) {
            return Column(
              children: [
                Padding(
                  padding: const .symmetric(
                    horizontal: AppSpacing.screenHorizontal,
                    vertical: AppSpacing.sm,
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 48),
                      Expanded(
                        child: Text(
                          'Profile',
                          textAlign: .center,
                          style: typography.headlineMedium,
                        ),
                      ),
                      IconButton(
                        onPressed: state is ProfileLoaded
                            ? () => _openEdit(context)
                            : null,
                        icon: Icon(
                          Icons.edit_outlined,
                          color: colors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(child: ProfileBody(state: state)),
              ],
            );
          },
        ),
      ),
    );
  }
}
