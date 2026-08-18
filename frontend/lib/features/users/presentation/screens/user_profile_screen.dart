import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/core/constants/app_colors.dart';
import 'package:frontend/core/constants/app_spacing.dart';
import 'package:frontend/core/constants/app_typography.dart';
import 'package:frontend/features/notes/domain/repos/notes_repo.dart';
import 'package:frontend/features/sessions/domain/repos/sessions_repo.dart';
import 'package:frontend/features/users/domain/repos/users_repo.dart';
import 'package:go_router/go_router.dart';

import '../components/user_profile_body.dart';
import '../cubits/user_profile_cubit.dart';

class UserProfileScreen extends StatelessWidget {
  final String userId;

  const UserProfileScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => UserProfileCubit(
        usersRepo: context.read<UsersRepo>(),
        notesRepo: context.read<NotesRepo>(),
        sessionsRepo: context.read<SessionsRepo>(),
        userId: userId,
      )..load(),
      child: const _UserProfileView(),
    );
  }
}

class _UserProfileView extends StatelessWidget {
  const _UserProfileView();

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
                      'Profile',
                      textAlign: .center,
                      style: typography.headlineMedium,
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: BlocBuilder<UserProfileCubit, UserProfileState>(
                builder: (context, state) => UserProfileBody(state: state),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
