import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:frontend/core/constants/app_colors.dart';
import 'package:frontend/core/constants/app_routes.dart';
import 'package:frontend/core/constants/app_spacing.dart';
import 'package:frontend/core/constants/app_typography.dart';
import 'package:frontend/core/widgets/pill_button.dart';
import 'package:frontend/features/sessions/domain/entities/study_session.dart';
import 'package:frontend/features/sessions/domain/repos/sessions_repo.dart';
import 'package:frontend/features/sessions/presentation/components/session_list_card.dart';
import 'package:frontend/features/sessions/presentation/cubits/sessions_cubit.dart';

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
  bool _showSaved = false;

  void _reload() {
    if (_showSaved) {
      context.read<SessionsCubit>().loadSavedSessions();
    } else {
      context.read<SessionsCubit>().loadSessions();
    }
  }

  void _switchTab(bool showSaved) {
    if (_showSaved == showSaved) return;
    setState(() => _showSaved = showSaved);
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
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
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
                    icon: const Icon(Icons.link, color: AppColors.textPrimary),
                  ),
                  Expanded(
                    child: Text(
                      'Study Sessions',
                      textAlign: TextAlign.center,
                      style: AppTypography.headlineMedium,
                    ),
                  ),
                  IconButton(
                    onPressed: _openNewSession,
                    tooltip: 'New session',
                    icon: const Icon(Icons.add, color: AppColors.textPrimary),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  PillButton(
                    label: 'My Sessions',
                    variant: !_showSaved ? PillButtonVariant.primary : PillButtonVariant.muted,
                    onPressed: () => _switchTab(false),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  PillButton(
                    label: 'Saved',
                    variant: _showSaved ? PillButtonVariant.primary : PillButtonVariant.muted,
                    onPressed: () => _switchTab(true),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Expanded(
                child: BlocBuilder<SessionsCubit, SessionsState>(
                  builder: (context, state) {
                    if (state is SessionsLoading || state is SessionsInitial) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                        ),
                      );
                    }

                    if (state is SessionsError) {
                      return Center(
                        child: Text(
                          state.message,
                          textAlign: TextAlign.center,
                          style: AppTypography.bodySmall,
                        ),
                      );
                    }

                    final sessions = state is SessionsLoaded
                        ? state.sessions
                        : const <StudySession>[];
                    if (sessions.isEmpty) {
                      return Center(
                        child: Text(
                          _showSaved
                              ? 'No saved sessions yet. Bookmark one from Home to see it here.'
                              : 'No study sessions yet. Tap + to start one.',
                          textAlign: TextAlign.center,
                          style: AppTypography.bodySmall,
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
                          if (_showSaved && mounted) _reload();
                        },
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
