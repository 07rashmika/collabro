import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:frontend/core/constants/app_colors.dart';
import 'package:frontend/core/constants/app_routes.dart';
import 'package:frontend/core/constants/app_spacing.dart';
import 'package:frontend/core/constants/app_typography.dart';
import 'package:frontend/core/widgets/primary_button.dart';
import 'package:frontend/core/widgets/secondary_button.dart';
import 'package:frontend/core/widgets/skill_chip.dart';
import 'package:frontend/core/widgets/user_avatar.dart';
import 'package:frontend/features/auth/domain/entities/app_user.dart';
import 'package:frontend/features/auth/domain/repos/auth_repo.dart';
import 'package:frontend/features/auth/presentation/cubits/auth_cubit.dart';
import 'package:frontend/features/profiles/domain/entities/profile.dart';
import 'package:frontend/features/profiles/domain/repos/profiles_repo.dart';

import '../cubits/profile_cubit.dart';

const _levelLabels = {
  'BEGINNER': 'Beginner',
  'INTERMEDIATE': 'Intermediate',
  'ADVANCED': 'Advanced',
};

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) => ProfileCubit(
            authRepo: context.read<AuthRepo>(),
            profilesRepo: context.read<ProfilesRepo>(),
          )..loadProfile(),
        ),
        BlocProvider(
          create: (context) => AuthCubit(authRepo: context.read<AuthRepo>()),
        ),
      ],
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
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: SafeArea(
        child: BlocListener<AuthCubit, AuthState>(
          listener: (context, state) {
            if (state is AuthLoggedOut) context.go(AppRoutes.signIn);
          },
          child: BlocBuilder<ProfileCubit, ProfileState>(
            builder: (context, state) {
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.screenHorizontal,
                      vertical: AppSpacing.sm,
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 48),
                        Expanded(
                          child: Text(
                            'Profile',
                            textAlign: TextAlign.center,
                            style: AppTypography.headlineMedium,
                          ),
                        ),
                        IconButton(
                          onPressed: state is ProfileLoaded
                              ? () => _openEdit(context)
                              : null,
                          icon: const Icon(
                            Icons.edit_outlined,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(child: _buildBody(context, state)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, ProfileState state) {
    if (state is ProfileLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (state is ProfileError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                state.message,
                style: AppTypography.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),
              PrimaryButton(
                label: 'Retry',
                onPressed: () => context.read<ProfileCubit>().loadProfile(),
              ),
            ],
          ),
        ),
      );
    }

    final loaded = state as ProfileLoaded;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenHorizontal,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.md),
          Center(
            child: Column(
              children: [
                UserAvatar(name: loaded.user.name, size: AppSpacing.avatarXxl),
                const SizedBox(height: AppSpacing.md),
                Text(loaded.user.name, style: AppTypography.headlineSmall),
                const SizedBox(height: AppSpacing.xs),
                Text(loaded.user.email, style: AppTypography.bodySmall),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          if (loaded.profile == null)
            _buildNoProfile(context, loaded.user)
          else
            ..._buildProfileSections(loaded.profile!),
          const SizedBox(height: AppSpacing.xxl),
          SecondaryButton(
            label: 'Log Out',
            leadingIcon: Icons.logout,
            isLoading: context.watch<AuthCubit>().state is AuthLoading,
            onPressed: () => context.read<AuthCubit>().logout(),
          ),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }

  Widget _buildNoProfile(BuildContext context, AppUser user) {
    return Column(
      children: [
        Text(
          "You haven't finished setting up your profile yet.",
          style: AppTypography.bodyMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.lg),
        PrimaryButton(
          label: 'Complete Profile',
          onPressed: () => context.go(AppRoutes.profileSetup, extra: user),
        ),
      ],
    );
  }

  List<Widget> _buildProfileSections(Profile profile) {
    return [
      if (profile.bio != null && profile.bio!.isNotEmpty) ...[
        Text(
          profile.bio!,
          style: AppTypography.bodyMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xxl),
      ],
      if (profile.learningGoal != null && profile.learningGoal!.isNotEmpty)
        _buildDetailRow(
          icon: Icons.flag_outlined,
          label: 'Wants to learn',
          value: profile.learningGoal!,
        ),
      if (profile.teachGoal != null && profile.teachGoal!.isNotEmpty)
        _buildDetailRow(
          icon: Icons.school_outlined,
          label: 'Can teach',
          value: profile.teachGoal!,
        ),
      const SizedBox(height: AppSpacing.lg),
      _buildChipSection(
        'Skills',
        profile.skills
            .map((s) => '${s.name} · ${_levelLabels[s.level] ?? s.level}')
            .toList(),
      ),
      _buildChipSection(
        'Study Areas',
        profile.studyAreas.map((a) => a.name).toList(),
      ),
      _buildChipSection('Interests', profile.interests),
    ];
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: AppSpacing.iconMd, color: AppColors.textTertiary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTypography.labelSmall),
                Text(value, style: AppTypography.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChipSection(String title, List<String> items) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTypography.headlineSmall),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: items.map((label) => SkillChip(label: label)).toList(),
          ),
        ],
      ),
    );
  }
}
