import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:frontend/core/constants/app_colors.dart';
import 'package:frontend/core/constants/app_routes.dart';
import 'package:frontend/core/constants/app_spacing.dart';
import 'package:frontend/core/constants/app_typography.dart';
import 'package:frontend/core/realtime/user_notifications_service.dart';
import 'package:frontend/core/widgets/pill_button.dart';
import 'package:frontend/features/sessions/domain/entities/study_session.dart';
import 'package:frontend/features/sessions/domain/repos/sessions_repo.dart';
import 'package:frontend/features/sessions/presentation/components/session_list_card.dart';
import 'package:frontend/features/sessions/presentation/components/session_summary_dialog.dart';
import 'package:frontend/features/sessions/presentation/cubits/sessions_cubit.dart';

enum _SessionsTab { mine, ended, saved }

class SessionsListScreen extends StatelessWidget {
  const SessionsListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          SessionsCubit(sessionsRepo: context.read<SessionsRepo>())
            ..loadSessions(),
      child: const _SessionsListView(),
    );
  }
}

class _SessionsListView extends StatefulWidget {
  const _SessionsListView();

  @override
  State<_SessionsListView> createState() => _SessionsListViewState();
}

class _SessionsListViewState extends State<_SessionsListView> {
  _SessionsTab _tab = _SessionsTab.mine;
  StreamSubscription? _sessionsChangedSubscription;

  @override
  void initState() {
    super.initState();
    // This screen's state is kept alive for the app's lifetime by the shell's
    // IndexedStack, so this subscription effectively lasts the whole session.
    _sessionsChangedSubscription = context
        .read<UserNotificationsService>()
        .sessionsChanged
        .listen((_) => _reload());
  }

  @override
  void dispose() {
    _sessionsChangedSubscription?.cancel();
    super.dispose();
  }

  void _reload() {
    switch (_tab) {
      case _SessionsTab.mine:
        context.read<SessionsCubit>().loadSessions();
      case _SessionsTab.ended:
        context.read<SessionsCubit>().loadEndedSessions();
      case _SessionsTab.saved:
        context.read<SessionsCubit>().loadSavedSessions();
    }
  }

  void _switchTab(_SessionsTab tab) {
    if (_tab == tab) return;
    setState(() => _tab = tab);
    _reload();
  }

  Future<void> _openNewSession() async {
    final created = await context.push<bool>(AppRoutes.newSession);
    if (created == true && mounted) _reload();
  }

  Future<void> _openJoinSession() async {
    final joined = await context.push<bool>(AppRoutes.joinSession);
    if (joined == true && mounted) _reload();
  }

  Future<void> _openSession(StudySession session) async {
    await context.push(AppRoutes.sessionDetail, extra: session);
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final typography = AppTypography.of(context);
    return Scaffold(
      backgroundColor: colors.backgroundDark,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenHorizontal,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  IconButton(
                    onPressed: _openJoinSession,
                    tooltip: 'Join via code',
                    icon: Icon(Icons.link, color: colors.textPrimary),
                  ),
                  Expanded(
                    child: Text(
                      'Study Sessions',
                      textAlign: TextAlign.center,
                      style: typography.headlineMedium,
                    ),
                  ),
                  IconButton(
                    onPressed: _openNewSession,
                    tooltip: 'New session',
                    icon: Icon(Icons.add, color: colors.textPrimary),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    PillButton(
                      label: 'My Sessions',
                      variant: _tab == _SessionsTab.mine
                          ? PillButtonVariant.primary
                          : PillButtonVariant.muted,
                      onPressed: () => _switchTab(_SessionsTab.mine),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    PillButton(
                      label: 'Ended',
                      variant: _tab == _SessionsTab.ended
                          ? PillButtonVariant.primary
                          : PillButtonVariant.muted,
                      onPressed: () => _switchTab(_SessionsTab.ended),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    PillButton(
                      label: 'Saved',
                      variant: _tab == _SessionsTab.saved
                          ? PillButtonVariant.primary
                          : PillButtonVariant.muted,
                      onPressed: () => _switchTab(_SessionsTab.saved),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Expanded(
                child: BlocBuilder<SessionsCubit, SessionsState>(
                  builder: (context, state) {
                    if (state is SessionsLoading || state is SessionsInitial) {
                      return Center(
                        child: CircularProgressIndicator(
                          color: colors.primary,
                        ),
                      );
                    }

                    if (state is SessionsError) {
                      return Center(
                        child: Text(
                          state.message,
                          textAlign: TextAlign.center,
                          style: typography.bodySmall,
                        ),
                      );
                    }

                    final sessions = state is SessionsLoaded
                        ? state.sessions
                        : const <StudySession>[];
                    if (sessions.isEmpty) {
                      return Center(
                        child: Text(
                          switch (_tab) {
                            _SessionsTab.saved =>
                              'No saved sessions yet. Bookmark one from Home to see it here.',
                            _SessionsTab.ended =>
                              'No ended sessions yet.',
                            _SessionsTab.mine =>
                              'No study sessions yet. Tap + to start one.',
                          },
                          textAlign: TextAlign.center,
                          style: typography.bodySmall,
                        ),
                      );
                    }

                    return ListView.separated(
                      itemCount: sessions.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: AppSpacing.md),
                      itemBuilder: (context, i) => SessionListCard(
                        session: sessions[i],
                        onTap: () => _openSession(sessions[i]),
                        onToggleSave: () async {
                          await context
                              .read<SessionsCubit>()
                              .toggleSaveSession(sessions[i]);
                          // Unsaving in the Saved tab should drop it from
                          // view — the cubit's optimistic toggle only flips
                          // the flag, so re-fetch to prune it out here.
                          if (_tab == _SessionsTab.saved && mounted) _reload();
                        },
                        onSummarize: () => showSessionSummaryDialog(context, sessions[i]),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
