import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/core/constants/app_colors.dart';
import 'package:frontend/core/constants/app_routes.dart';
import 'package:frontend/core/constants/app_spacing.dart';
import 'package:frontend/core/constants/app_typography.dart';
import 'package:frontend/core/constants/error_messages.dart';
import 'package:frontend/core/realtime/user_notifications_service.dart';
import 'package:frontend/core/widgets/pill_button.dart';
import 'package:frontend/features/sessions/domain/entities/study_session.dart';
import 'package:frontend/features/sessions/domain/repos/sessions_repo.dart';
import 'package:frontend/features/sessions/presentation/components/session_list_card.dart';
import 'package:frontend/features/sessions/presentation/components/session_summary_dialog.dart';
import 'package:frontend/features/sessions/presentation/cubits/sessions_cubit.dart';
import 'package:go_router/go_router.dart';

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

  Future<void> _reload() {
    return switch (_tab) {
      _SessionsTab.mine => context.read<SessionsCubit>().loadSessions(),
      _SessionsTab.ended => context.read<SessionsCubit>().loadEndedSessions(),
      _SessionsTab.saved => context.read<SessionsCubit>().loadSavedSessions(),
    };
  }

  void _switchTab(_SessionsTab tab) {
    if (_tab == tab) return;
    setState(() => _tab = tab);
    _reload();
  }

  Future<void> _openNewSession() async {
    final created = await context.push<StudySession>(AppRoutes.newSession);
    if (created == null || !mounted) return;
    _reload();
    await context.push(AppRoutes.sessionDetail, extra: created);
    if (mounted) _reload();
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
          padding: const .symmetric(horizontal: AppSpacing.screenHorizontal),
          child: Column(
            crossAxisAlignment: .stretch,
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
                      textAlign: .center,
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
                scrollDirection: .horizontal,
                child: Row(
                  children: [
                    PillButton(
                      label: 'My Sessions',
                      variant: _tab == .mine ? .primary : .muted,
                      onPressed: () => _switchTab(.mine),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    PillButton(
                      label: 'Ended',
                      variant: _tab == .ended ? .primary : .muted,
                      onPressed: () => _switchTab(.ended),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    PillButton(
                      label: 'Saved',
                      variant: _tab == .saved ? .primary : .muted,
                      onPressed: () => _switchTab(.saved),
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
                        child: CircularProgressIndicator(color: colors.primary),
                      );
                    }

                    if (state is SessionsError) {
                      return Center(
                        child: Text(
                          genericErrorMessage,
                          textAlign: .center,
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
                            .saved =>
                              'No saved sessions yet. Bookmark one from Home to see it here.',
                            .ended => 'No ended sessions yet.',
                            .mine =>
                              'No study sessions yet. Tap + to start one.',
                          },
                          textAlign: .center,
                          style: typography.bodySmall,
                        ),
                      );
                    }

                    return RefreshIndicator(
                      color: colors.primary,
                      onRefresh: _reload,
                      child: ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: sessions.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: AppSpacing.md),
                        itemBuilder: (context, index) => SessionListCard(
                          session: sessions[index],
                          onTap: () => _openSession(sessions[index]),
                          onToggleSave: () async {
                            await context
                                .read<SessionsCubit>()
                                .toggleSaveSession(sessions[index]);
                            if (_tab == _SessionsTab.saved && mounted) {
                              _reload();
                            }
                          },
                          onSummarize: () => showSessionSummaryDialog(
                            context,
                            sessions[index],
                          ),
                        ),
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
