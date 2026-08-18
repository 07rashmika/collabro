import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/core/constants/app_colors.dart';
import 'package:frontend/core/constants/app_routes.dart';
import 'package:frontend/core/constants/app_spacing.dart';
import 'package:frontend/core/constants/app_typography.dart';
import 'package:frontend/core/utils/snackbar_utils.dart';
import 'package:frontend/core/widgets/app_search_field.dart';
import 'package:frontend/core/widgets/app_text_field.dart';
import 'package:frontend/core/widgets/pill_button.dart';
import 'package:frontend/features/auth/domain/repos/auth_repo.dart';
import 'package:frontend/features/discovery/presentation/components/discovery_placeholder.dart';
import 'package:frontend/features/discovery/presentation/components/discovery_results.dart';
import 'package:frontend/features/discovery/presentation/cubits/discovery_cubit.dart';
import 'package:frontend/features/notes/domain/repos/notes_repo.dart';
import 'package:frontend/features/sessions/domain/entities/study_session.dart';
import 'package:frontend/features/sessions/domain/repos/sessions_repo.dart';
import 'package:frontend/features/users/domain/repos/users_repo.dart';
import 'package:go_router/go_router.dart';

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
  DiscoveryTarget _target = .all;
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
    context.read<DiscoveryCubit>().search(
      target,
      _searchController.text.trim(),
    );
  }

  void _runSearch(String query) {
    context.read<DiscoveryCubit>().search(_target, query.trim());
  }

  Future<void> _openSession(StudySession session) async {
    final alreadyJoined =
        _currentUserId != null &&
        session.participants.any((p) => p.userId == _currentUserId);
    if (alreadyJoined) {
      await context.push(AppRoutes.sessionDetail, extra: session);
      return;
    }

    String? password;
    if (session.hasPassword) {
      password = await _promptForPassword(session.title);
      if (password == null) return; //cancelled
      if (!mounted) return;
    }

    try {
      final joined = await context.read<SessionsRepo>().joinSessionByCode(
        joinCode: session.joinCode!,
        password: password,
      );
      if (mounted) await context.push(AppRoutes.sessionDetail, extra: joined);
    } catch (e) {
      if (mounted) showErrorSnackBar(context);
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

  String get _hint {
    switch (_target) {
      case .all:
        return 'Search sessions, students, and notes...';
      case .sessions:
        return 'Search public sessions...';
      case .users:
        return 'Search students by name or email...';
      case .notes:
        return 'Search public notes...';
    }
  }

  String get _emptyMessage {
    switch (_target) {
      case .all:
        return 'No results found.';
      case .sessions:
        return 'No public sessions found.';
      case .users:
        return 'No students found.';
      case .notes:
        return 'No public notes found.';
    }
  }

  String get _placeholderMessage =>
      'Search for public sessions, students, or notes to get started.';

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
              Text(
                'Discovery',
                textAlign: .center,
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
                      showErrorSnackBar(context);
                    }
                  },
                  builder: (context, state) {
                    if (state is DiscoveryInitial) {
                      return DiscoveryPlaceholder(message: _placeholderMessage);
                    }

                    return Column(
                      crossAxisAlignment: .stretch,
                      children: [
                        SingleChildScrollView(
                          scrollDirection: .horizontal,
                          child: Row(
                            children: [
                              PillButton(
                                label: 'All',
                                variant: _target == .all ? .primary : .muted,
                                onPressed: () =>
                                    _switchTarget(DiscoveryTarget.all),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              PillButton(
                                label: 'Sessions',
                                variant: _target == .sessions
                                    ? .primary
                                    : .muted,
                                onPressed: () => _switchTarget(.sessions),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              PillButton(
                                label: 'Users',
                                variant: _target == .users ? .primary : .muted,
                                onPressed: () => _switchTarget(.users),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              PillButton(
                                label: 'Notes',
                                variant: _target == .notes ? .primary : .muted,
                                onPressed: () => _switchTarget(.notes),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Expanded(
                          child: DiscoveryResults(
                            state: state,
                            currentUserId: _currentUserId,
                            emptyMessage: _emptyMessage,
                            onOpenSession: _openSession,
                          ),
                        ),
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
