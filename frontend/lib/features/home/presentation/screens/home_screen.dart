import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/core/constants/app_colors.dart';
import 'package:frontend/core/constants/app_routes.dart';
import 'package:frontend/core/constants/app_spacing.dart';
import 'package:frontend/core/constants/app_typography.dart';
import 'package:frontend/core/constants/error_messages.dart';
import 'package:frontend/core/realtime/user_notifications_service.dart';
import 'package:frontend/core/utils/snackbar_utils.dart';
import 'package:frontend/core/widgets/app_text_field.dart';
import 'package:frontend/features/auth/domain/entities/app_user.dart';
import 'package:frontend/features/auth/domain/repos/auth_repo.dart';
import 'package:frontend/features/auth/presentation/cubits/auth_cubit.dart';
import 'package:frontend/features/connections/domain/repos/connections_repo.dart';
import 'package:frontend/features/discovery/presentation/components/note_preview_sheet.dart';
import 'package:frontend/features/matching/domain/entities/match_candidate.dart';
import 'package:frontend/features/matching/domain/repos/matching_repo.dart';
import 'package:frontend/features/matching/presentation/cubits/matching_cubit.dart';
import 'package:frontend/features/notes/domain/repos/notes_repo.dart';
import 'package:frontend/features/notes/presentation/cubits/notes_cubit.dart';
import 'package:frontend/features/notifications/domain/repos/notifications_repo.dart';
import 'package:frontend/features/sessions/domain/entities/study_session.dart';
import 'package:frontend/features/sessions/domain/repos/sessions_repo.dart';
import 'package:frontend/features/sessions/presentation/cubits/sessions_cubit.dart';
import 'package:go_router/go_router.dart';

import '../components/ai_summary_card.dart';
import '../components/dashboard_section_header.dart';
import '../components/greeting_header.dart';
import '../components/home_drawer.dart';
import '../components/home_top_bar.dart';
import '../components/recommended_partners_list.dart';
import '../components/session_card.dart';
import '../models/home_bootstrap.dart';

const _homeSummaryCount = 3;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final Future<HomeBootstrap> _bootstrapFuture;

  @override
  void initState() {
    super.initState();
    _bootstrapFuture = _bootstrap();
  }

  Future<HomeBootstrap> _bootstrap() async {
    final authRepo = context.read<AuthRepo>();
    final matchingRepo = context.read<MatchingRepo>();
    final connectionsRepo = context.read<ConnectionsRepo>();

    final user = await authRepo.getCurrentUser();

    var matchedAuthorIds = const <String>[];
    try {
      final results = await Future.wait([
        matchingRepo.getMatches(),
        connectionsRepo.getConnectedUserIds(),
      ]);
      final matches = results[0] as List<MatchCandidate>;
      final connectedUserIds = results[1] as List<String>;
      matchedAuthorIds = {
        ...matches.map((m) => m.userId),
        ...connectedUserIds,
      }.toList();
    } catch (e) {
      //fall back to the caller's own notes only.
      print("Call error $e");
    }

    return HomeBootstrap(user: user, matchedAuthorIds: matchedAuthorIds);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return FutureBuilder<HomeBootstrap>(
      future: _bootstrapFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != .done) {
          return Scaffold(
            backgroundColor: colors.backgroundDark,
            body: Center(
              child: CircularProgressIndicator(color: colors.primary),
            ),
          );
        }

        final user = snapshot.data?.user;
        if (user == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) context.go(AppRoutes.signIn);
          });
          return Scaffold(
            backgroundColor: colors.backgroundDark,
            body: Center(
              child: CircularProgressIndicator(color: colors.primary),
            ),
          );
        }

        final matchedAuthorIds = snapshot.data!.matchedAuthorIds;
        return MultiBlocProvider(
          providers: [
            BlocProvider(
              create: (context) =>
                  AuthCubit(authRepo: context.read<AuthRepo>()),
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
            BlocProvider(
              create: (context) =>
                  NotesCubit(notesRepo: context.read<NotesRepo>())
                    ..loadHomeSummaries(
                      matchedAuthorIds: matchedAuthorIds,
                      limit: _homeSummaryCount,
                    ),
            ),
          ],
          child: _HomeView(user: user),
        );
      },
    );
  }
}

class _HomeView extends StatefulWidget {
  final AppUser user;

  const _HomeView({required this.user});

  @override
  State<_HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<_HomeView> {
  StreamSubscription? _sessionsChangedSubscription;
  StreamSubscription? _notificationsChangedSubscription;
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _sessionsChangedSubscription = context
        .read<UserNotificationsService>()
        .sessionsChanged
        .listen((_) => _reloadUpcomingSessions());
    _notificationsChangedSubscription = context
        .read<UserNotificationsService>()
        .notificationsChanged
        .listen((_) => _refreshUnreadCount());
    _refreshUnreadCount();
  }

  @override
  void dispose() {
    _sessionsChangedSubscription?.cancel();
    _notificationsChangedSubscription?.cancel();
    super.dispose();
  }

  void _reloadUpcomingSessions() {
    context.read<SessionsCubit>().loadUpcomingSessions();
  }

  Future<void> _refreshUnreadCount() async {
    try {
      final page = await context.read<NotificationsRepo>().getNotifications();
      if (mounted) setState(() => _unreadCount = page.unreadCount);
    } catch (_) {
      // Badge just stays at its last known value — not worth surfacing.
    }
  }

  Future<void> _openSession(BuildContext context, StudySession session) async {
    final alreadyJoined = session.participants.any(
      (p) => p.userId == widget.user.id,
    );
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
        showErrorSnackBar(context, e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  Future<String?> _promptForPassword(BuildContext context, String title) {
    final colors = AppColors.of(context);
    final typography = AppTypography.of(context);
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: colors.backgroundCard,
        title: Text('Password required', style: typography.titleMedium),
        content: Column(
          mainAxisSize: .min,
          crossAxisAlignment: .start,
          children: [
            Text(
              '"$title" is password-protected.',
              style: typography.bodyMedium,
            ),
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
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Join'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final typography = AppTypography.of(context);
    return Scaffold(
      backgroundColor: colors.backgroundDark,
      drawer: HomeDrawer(user: widget.user),
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
                    padding: const .symmetric(
                      horizontal: AppSpacing.screenHorizontal,
                      vertical: AppSpacing.sm,
                    ),
                    child: HomeTopBar(
                      onMenuTap: () =>
                          Scaffold.of(scaffoldContext).openDrawer(),
                      onNotificationsTap: () => context
                          .push(AppRoutes.notifications)
                          .then((_) => _refreshUnreadCount()),
                      hasUnreadNotifications: _unreadCount > 0,
                    ),
                  ),
                  Expanded(
                    child: RefreshIndicator(
                      color: colors.primary,
                      onRefresh: () => Future.wait([
                        context.read<MatchingCubit>().loadMatches(),
                        context.read<SessionsCubit>().loadUpcomingSessions(),
                        context.read<NotesCubit>().loadNotes(
                          hasSummary: true,
                          limit: _homeSummaryCount,
                        ),
                      ]),
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const .symmetric(
                          horizontal: AppSpacing.screenHorizontal,
                        ),
                        child: Column(
                          crossAxisAlignment: .stretch,
                          children: [
                            const SizedBox(height: AppSpacing.xs),
                            GreetingHeader(
                              name: widget.user.name.split(' ').first,
                            ),
                            const SizedBox(height: AppSpacing.xxl),
                            DashboardSectionHeader(
                              title: 'Recommended Partners',
                              actionLabel: 'View All',
                              onActionTap: () =>
                                  context.go(AppRoutes.discovery),
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
                                  return Padding(
                                    padding: const .symmetric(
                                      vertical: AppSpacing.lg,
                                    ),
                                    child: Center(
                                      child: CircularProgressIndicator(
                                        color: colors.primary,
                                      ),
                                    ),
                                  );
                                }

                                if (state is SessionsError) {
                                  debugPrint(
                                    '[HomeScreen] Failed to load upcoming sessions: ${state.message}',
                                  );
                                  return Padding(
                                    padding: const .symmetric(
                                      vertical: AppSpacing.md,
                                    ),
                                    child: Text(
                                      'No upcoming sessions scheduled.',
                                      style: typography.bodySmall,
                                    ),
                                  );
                                }

                                final sessions = state is SessionsLoaded
                                    ? state.sessions
                                    : const <StudySession>[];

                                if (sessions.isEmpty) {
                                  return Padding(
                                    padding: const .symmetric(
                                      vertical: AppSpacing.md,
                                    ),
                                    child: Text(
                                      'No upcoming sessions scheduled.',
                                      style: typography.bodySmall,
                                    ),
                                  );
                                }

                                return Column(
                                  children: [
                                    for (final session in sessions) ...[
                                      SessionCard(
                                        session: session,
                                        onAction: () =>
                                            _openSession(context, session),
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
                            BlocBuilder<NotesCubit, NotesState>(
                              builder: (context, state) {
                                if (state is NotesInitial ||
                                    state is NotesLoading) {
                                  return Center(
                                    child: CircularProgressIndicator(
                                      color: colors.primary,
                                    ),
                                  );
                                }
                                if (state is NotesError) {
                                  return Text(
                                    genericErrorMessage,
                                    textAlign: .center,
                                    style: typography.bodySmall,
                                  );
                                }
                                final notes = (state as NotesLoaded).notes;
                                if (notes.isEmpty) {
                                  return Text(
                                    'No summaries at the moment.',
                                    textAlign: .center,
                                    style: typography.bodySmall,
                                  );
                                }
                                return Column(
                                  children: [
                                    for (final note in notes) ...[
                                      AiSummaryCard(
                                        note: note,
                                        onReadMore:
                                            note.authorId == widget.user.id
                                            ? () => context.push(
                                                AppRoutes.noteDetail,
                                                extra: note,
                                              )
                                            : () => showNotePreviewSheet(
                                                context,
                                                note,
                                              ),
                                      ),
                                      const SizedBox(height: AppSpacing.md),
                                    ],
                                  ],
                                );
                              },
                            ),
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
