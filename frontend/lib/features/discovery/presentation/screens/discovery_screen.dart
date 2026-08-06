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
import 'package:frontend/core/widgets/pill_button.dart';
import 'package:frontend/features/auth/domain/repos/auth_repo.dart';
import 'package:frontend/features/discovery/presentation/components/discovery_user_card.dart';
import 'package:frontend/features/discovery/presentation/components/note_preview_sheet.dart';
import 'package:frontend/features/discovery/presentation/cubits/discovery_cubit.dart';
import 'package:frontend/features/notes/domain/entities/note.dart';
import 'package:frontend/features/notes/domain/repos/notes_repo.dart';
import 'package:frontend/features/notes/presentation/components/note_card.dart';
import 'package:frontend/features/sessions/domain/entities/study_session.dart';
import 'package:frontend/features/sessions/domain/repos/sessions_repo.dart';
import 'package:frontend/features/sessions/presentation/components/session_list_card.dart';
import 'package:frontend/features/users/domain/entities/public_user.dart';
import 'package:frontend/features/users/domain/repos/users_repo.dart';

class DiscoveryScreen extends StatelessWidget {
  const DiscoveryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => DiscoveryCubit(
        sessionsRepo: context.read<SessionsRepo>(),
        usersRepo: context.read<UsersRepo>(),
        notesRepo: context.read<NotesRepo>(),
      ),
      child: const _DiscoveryView(),
    );
  }
}

class _DiscoveryView extends StatefulWidget {
  const _DiscoveryView();

  @override
  State<_DiscoveryView> createState() => _DiscoveryViewState();
}

class _DiscoveryViewState extends State<_DiscoveryView> {
  final _searchController = TextEditingController();
  DiscoveryTarget _target = DiscoveryTarget.all;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    context.read<AuthRepo>().getCurrentUser().then((user) {
      if (mounted) setState(() => _currentUserId = user?.id);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _switchTarget(DiscoveryTarget target) {
    if (_target == target) return;
    setState(() => _target = target);
    context.read<DiscoveryCubit>().search(target, _searchController.text.trim());
  }

  void _runSearch(String query) {
    context.read<DiscoveryCubit>().search(_target, query.trim());
  }

  /// A discovered public session the user hasn't joined yet needs a real
  /// join (adds them as a participant server-side) before the chat/video
  /// screen will let them in — mirrors HomeScreen's _openSession.
  Future<void> _openSession(StudySession session) async {
    final colors = AppColors.of(context);
    final alreadyJoined =
        _currentUserId != null && session.participants.any((p) => p.userId == _currentUserId);
    if (alreadyJoined) {
      await context.push(AppRoutes.sessionDetail, extra: session);
      return;
    }

    String? password;
    if (session.hasPassword) {
      password = await _promptForPassword(session.title);
      if (password == null) return; // cancelled
      if (!mounted) return;
    }

    try {
      final joined = await context.read<SessionsRepo>().joinSessionByCode(
        joinCode: session.joinCode!,
        password: password,
      );
      if (mounted) await context.push(AppRoutes.sessionDetail, extra: joined);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: colors.error,
          ),
        );
      }
    }
  }

  Future<String?> _promptForPassword(String title) {
    final colors = AppColors.of(context);
    final typography = AppTypography.of(context);
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: colors.backgroundCard,
        title: Text('Password required', style: typography.titleMedium),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('"$title" is password-protected.', style: typography.bodyMedium),
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

  String get _hint {
    switch (_target) {
      case DiscoveryTarget.all:
        return 'Search sessions, students, and notes...';
      case DiscoveryTarget.sessions:
        return 'Search public sessions...';
      case DiscoveryTarget.users:
        return 'Search students by name or email...';
      case DiscoveryTarget.notes:
        return 'Search public notes...';
    }
  }

  String get _emptyMessage {
    switch (_target) {
      case DiscoveryTarget.all:
        return 'No results found.';
      case DiscoveryTarget.sessions:
        return 'No public sessions found.';
      case DiscoveryTarget.users:
        return 'No students found.';
      case DiscoveryTarget.notes:
        return 'No public notes found.';
    }
  }

  String get _placeholderMessage =>
      'Search for public sessions, students, or notes to get started.';

  Widget _buildResults(BuildContext context, DiscoveryState state) {
    final colors = AppColors.of(context);
    final typography = AppTypography.of(context);

    if (state is DiscoveryLoading) {
      return Center(child: CircularProgressIndicator(color: colors.primary));
    }

    if (state is DiscoveryAllLoaded) {
      return _AllResults(
        sessions: state.sessions,
        users: state.users,
        notes: state.notes,
        currentUserId: _currentUserId,
        emptyMessage: _emptyMessage,
        onOpen: _openSession,
      );
    }

    if (state is DiscoverySessionsLoaded) {
      return _SessionsResults(
        sessions: state.sessions,
        emptyMessage: _emptyMessage,
        onOpen: _openSession,
      );
    }

    if (state is DiscoveryUsersLoaded) {
      return _UsersResults(
        users: state.users,
        currentUserId: _currentUserId,
        emptyMessage: _emptyMessage,
      );
    }

    if (state is DiscoveryNotesLoaded) {
      return _NotesResults(notes: state.notes, emptyMessage: _emptyMessage);
    }

    // DiscoveryError with a search already in flight/completed.
    return Center(
      child: Text(
        (state as DiscoveryError).message,
        textAlign: TextAlign.center,
        style: typography.bodySmall,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final typography = AppTypography.of(context);
    return Scaffold(
      backgroundColor: colors.backgroundDark,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenHorizontal),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Discovery',
                textAlign: TextAlign.center,
                style: typography.headlineMedium,
              ),
              const SizedBox(height: AppSpacing.md),
              AppSearchField(
                hint: _hint,
                controller: _searchController,
                onSubmitted: _runSearch,
              ),
              const SizedBox(height: AppSpacing.md),
              Expanded(
                child: BlocConsumer<DiscoveryCubit, DiscoveryState>(
                  listener: (context, state) {
                    if (state is DiscoveryError) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(state.message), backgroundColor: colors.error),
                      );
                    }
                  },
                  builder: (context, state) {
                    // Sessions/Users/Notes tabs and their results only
                    // appear once the user has actually searched — nothing
                    // to switch between or show before that.
                    if (state is DiscoveryInitial) {
                      return _DiscoveryPlaceholder(message: _placeholderMessage);
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              PillButton(
                                label: 'All',
                                variant: _target == DiscoveryTarget.all
                                    ? PillButtonVariant.primary
                                    : PillButtonVariant.muted,
                                onPressed: () => _switchTarget(DiscoveryTarget.all),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              PillButton(
                                label: 'Sessions',
                                variant: _target == DiscoveryTarget.sessions
                                    ? PillButtonVariant.primary
                                    : PillButtonVariant.muted,
                                onPressed: () => _switchTarget(DiscoveryTarget.sessions),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              PillButton(
                                label: 'Users',
                                variant: _target == DiscoveryTarget.users
                                    ? PillButtonVariant.primary
                                    : PillButtonVariant.muted,
                                onPressed: () => _switchTarget(DiscoveryTarget.users),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              PillButton(
                                label: 'Notes',
                                variant: _target == DiscoveryTarget.notes
                                    ? PillButtonVariant.primary
                                    : PillButtonVariant.muted,
                                onPressed: () => _switchTarget(DiscoveryTarget.notes),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Expanded(child: _buildResults(context, state)),
                      ],
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

class _DiscoveryPlaceholder extends StatelessWidget {
  final String message;

  const _DiscoveryPlaceholder({required this.message});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final typography = AppTypography.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search, size: AppSpacing.iconXl, color: colors.textTertiary),
            const SizedBox(height: AppSpacing.md),
            Text(
              message,
              textAlign: TextAlign.center,
              style: typography.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

/// The "All" tab — sessions, users, and notes matching the query grouped
/// into labeled sections in a single scroll, mirroring how Facebook's "All"
/// search tab groups People/Posts/etc. rather than picking just one type.
class _AllResults extends StatelessWidget {
  final List<StudySession> sessions;
  final List<PublicUser> users;
  final List<Note> notes;
  final String? currentUserId;
  final String emptyMessage;
  final ValueChanged<StudySession> onOpen;

  const _AllResults({
    required this.sessions,
    required this.users,
    required this.notes,
    required this.currentUserId,
    required this.emptyMessage,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final typography = AppTypography.of(context);
    final filteredUsers =
        currentUserId == null ? users : users.where((u) => u.id != currentUserId).toList();

    if (sessions.isEmpty && filteredUsers.isEmpty && notes.isEmpty) {
      return Center(
        child: Text(emptyMessage, textAlign: TextAlign.center, style: typography.bodySmall),
      );
    }

    return ListView(
      children: [
        if (sessions.isNotEmpty)
          _Section(
            title: 'Sessions',
            children: sessions
                .map(
                  (s) => SessionListCard(
                    session: s,
                    onTap: () => onOpen(s),
                    onToggleSave: () => context.read<DiscoveryCubit>().toggleSaveSession(s),
                  ),
                )
                .toList(),
          ),
        if (filteredUsers.isNotEmpty)
          _Section(
            title: 'Users',
            children: filteredUsers
                .map(
                  (u) => DiscoveryUserCard(
                    user: u,
                    onConnect: () => showComingSoonSnackBar(context, 'Connect requests'),
                  ),
                )
                .toList(),
          ),
        if (notes.isNotEmpty)
          _Section(
            title: 'Notes',
            children: notes
                .map((n) => NoteCard(note: n, onTap: () => showNotePreviewSheet(context, n)))
                .toList(),
          ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final typography = AppTypography.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: typography.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          for (final child in children) ...[
            child,
            const SizedBox(height: AppSpacing.md),
          ],
        ],
      ),
    );
  }
}

class _SessionsResults extends StatelessWidget {
  final List<StudySession> sessions;
  final String emptyMessage;
  final ValueChanged<StudySession> onOpen;

  const _SessionsResults({
    required this.sessions,
    required this.emptyMessage,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    if (sessions.isEmpty) {
      return Center(
        child: Text(
          emptyMessage,
          textAlign: TextAlign.center,
          style: AppTypography.of(context).bodySmall,
        ),
      );
    }
    return ListView.separated(
      itemCount: sessions.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (context, i) => SessionListCard(
        session: sessions[i],
        onTap: () => onOpen(sessions[i]),
        onToggleSave: () =>
            context.read<DiscoveryCubit>().toggleSaveSession(sessions[i]),
      ),
    );
  }
}

class _UsersResults extends StatelessWidget {
  final List<PublicUser> users;
  final String? currentUserId;
  final String emptyMessage;

  const _UsersResults({
    required this.users,
    required this.currentUserId,
    required this.emptyMessage,
  });

  @override
  Widget build(BuildContext context) {
    final filtered = currentUserId == null
        ? users
        : users.where((u) => u.id != currentUserId).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Text(
          emptyMessage,
          textAlign: TextAlign.center,
          style: AppTypography.of(context).bodySmall,
        ),
      );
    }
    return ListView.separated(
      itemCount: filtered.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (context, i) => DiscoveryUserCard(
        user: filtered[i],
        onConnect: () => showComingSoonSnackBar(context, 'Connect requests'),
      ),
    );
  }
}

class _NotesResults extends StatelessWidget {
  final List<Note> notes;
  final String emptyMessage;

  const _NotesResults({required this.notes, required this.emptyMessage});

  @override
  Widget build(BuildContext context) {
    if (notes.isEmpty) {
      return Center(
        child: Text(
          emptyMessage,
          textAlign: TextAlign.center,
          style: AppTypography.of(context).bodySmall,
        ),
      );
    }
    return ListView.separated(
      itemCount: notes.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (context, i) =>
          NoteCard(note: notes[i], onTap: () => showNotePreviewSheet(context, notes[i])),
    );
  }
}
