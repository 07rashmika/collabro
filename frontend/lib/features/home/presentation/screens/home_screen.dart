import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:frontend/core/constants/app_colors.dart';
import 'package:frontend/core/constants/app_routes.dart';
import 'package:frontend/core/constants/app_spacing.dart';
import 'package:frontend/core/constants/app_typography.dart';
import 'package:frontend/core/utils/snackbar_utils.dart';
import 'package:frontend/core/widgets/app_search_field.dart';
import 'package:frontend/core/widgets/app_text_field.dart';
import 'package:frontend/features/auth/domain/entities/app_user.dart';
import 'package:frontend/features/auth/domain/repos/auth_repo.dart';
import 'package:frontend/features/auth/presentation/cubits/auth_cubit.dart';
import 'package:frontend/features/matching/domain/repos/matching_repo.dart';
import 'package:frontend/features/matching/presentation/cubits/matching_cubit.dart';
import 'package:frontend/features/sessions/domain/entities/study_session.dart';
import 'package:frontend/features/sessions/domain/repos/sessions_repo.dart';
import 'package:frontend/features/sessions/presentation/cubits/sessions_cubit.dart';

import '../components/ai_summary_card.dart';
import '../components/dashboard_section_header.dart';
import '../components/greeting_header.dart';
import '../components/home_drawer.dart';
import '../components/home_top_bar.dart';
import '../components/recommended_partners_list.dart';
import '../components/session_card.dart';
import '../models/mock_ai_summary.dart';

class HomeScreen extends StatelessWidget {
  final AppUser user;

  const HomeScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) => AuthCubit(authRepo: context.read<AuthRepo>()),
        ),
        BlocProvider(
          create: (context) =>
              MatchingCubit(matchingRepo: context.read<MatchingRepo>())
                ..loadMatches(),
        ),
        BlocProvider(
          create: (context) =>
              SessionsCubit(sessionsRepo: context.read<SessionsRepo>())
                ..loadUpcomingSessions(),
        ),
      ],
      child: _HomeView(user: user),
    );
  }
}

class _HomeView extends StatelessWidget {
  final AppUser user;

  const _HomeView({required this.user});

  /// A discovered public session the user hasn't joined yet needs a real
  /// join (adds them as a participant server-side) before the chat/video
  /// screen will let them in — tapping straight through would 403. Sessions
  /// the user already owns or participates in skip straight to navigation.
  Future<void> _openSession(BuildContext context, StudySession session) async {
    final alreadyJoined = session.participants.any((p) => p.userId == user.id);
    if (alreadyJoined) {
      context.push(AppRoutes.sessionDetail, extra: session);
      return;
    }

    String? password;
    if (session.hasPassword) {
      password = await _promptForPassword(context, session.title);
      if (password == null) return; // cancelled
      if (!context.mounted) return;
    }

    try {
      final joined = await context.read<SessionsRepo>().joinSessionByCode(
        joinCode: session.joinCode!,
        password: password,
      );
      if (context.mounted) {
        context.push(AppRoutes.sessionDetail, extra: joined);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<String?> _promptForPassword(BuildContext context, String title) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.backgroundCard,
        title: Text('Password required', style: AppTypography.titleMedium),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('"$title" is password-protected.', style: AppTypography.bodyMedium),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: 'Password',
              hint: 'Enter the session password',
              icon: Icons.lock_outline,
              controller: controller,
              obscurable: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Join'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      drawer: HomeDrawer(user: user),
      body: SafeArea(
        child: Builder(
          builder: (scaffoldContext) {
            return BlocListener<AuthCubit, AuthState>(
              listener: (context, state) {
                if (state is AuthLoggedOut) context.go(AppRoutes.signIn);
              },
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.screenHorizontal,
                      vertical: AppSpacing.sm,
                    ),
                    child: HomeTopBar(
                      onMenuTap: () =>
                          Scaffold.of(scaffoldContext).openDrawer(),
                      onNotificationsTap: () =>
                          showComingSoonSnackBar(context, 'Notifications'),
                    ),
                  ),
                  Expanded(
                    child: RefreshIndicator(
                      color: AppColors.primary,
                      onRefresh: () => Future.wait([
                        context.read<MatchingCubit>().loadMatches(),
                        context.read<SessionsCubit>().loadUpcomingSessions(),
                      ]),
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.screenHorizontal,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: AppSpacing.xs),
                            GreetingHeader(name: user.name.split(' ').first),
                            const SizedBox(height: AppSpacing.lg),
                            AppSearchField(
                              hint: 'Search for subjects, partners, or...',
                              onTap: () =>
                                  showComingSoonSnackBar(context, 'Search'),
                            ),
                            const SizedBox(height: AppSpacing.xxl),
                            DashboardSectionHeader(
                              title: 'Recommended Partners',
                              actionLabel: 'View All',
                              onActionTap: () =>
                                  showComingSoonSnackBar(context, 'Discovery'),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            const RecommendedPartnersList(),
                            const SizedBox(height: AppSpacing.xxl),
                            DashboardSectionHeader(
                              title: 'Upcoming Sessions',
                              actionLabel: 'View All',
                              onActionTap: () => context.go(AppRoutes.sessions),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            BlocBuilder<SessionsCubit, SessionsState>(
                              builder: (context, state) {
                                if (state is SessionsLoading ||
                                    state is SessionsInitial) {
                                  return const Padding(
                                    padding: EdgeInsets.symmetric(
                                      vertical: AppSpacing.lg,
                                    ),
                                    child: Center(
                                      child: CircularProgressIndicator(
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  );
                                }

                                if (state is SessionsError) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: AppSpacing.md,
                                    ),
                                    child: Text(
                                      state.message,
                                      style: AppTypography.bodySmall,
                                    ),
                                  );
                                }

                                final sessions = state is SessionsLoaded
                                    ? state.sessions
                                    : const <StudySession>[];

                                if (sessions.isEmpty) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: AppSpacing.md,
                                    ),
                                    child: Text(
                                      'No upcoming sessions scheduled.',
                                      style: AppTypography.bodySmall,
                                    ),
                                  );
                                }

                                return Column(
                                  children: [
                                    for (final session in sessions) ...[
                                      SessionCard(
                                        session: session,
                                        onAction: () => _openSession(context, session),
                                        onToggleSave: () => context
                                            .read<SessionsCubit>()
                                            .toggleSaveSession(session),
                                      ),
                                      const SizedBox(height: AppSpacing.md),
                                    ],
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            const DashboardSectionHeader(
                              title: 'AI Summaries',
                              leadingIcon: Icons.auto_awesome,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            for (final summary in mockAiSummaries) ...[
                              AiSummaryCard(
                                summary: summary,
                                onReadMore: () => context.go(AppRoutes.notes),
                              ),
                              const SizedBox(height: AppSpacing.md),
                            ],
                            const SizedBox(height: AppSpacing.xxl),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
