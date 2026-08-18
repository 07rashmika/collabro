import 'package:flutter/material.dart';
import 'package:frontend/core/constants/app_colors.dart';
import 'package:frontend/core/constants/app_typography.dart';
import 'package:frontend/core/constants/error_messages.dart';
import 'package:frontend/features/discovery/presentation/components/discovery_all_results.dart';
import 'package:frontend/features/discovery/presentation/components/discovery_notes_results.dart';
import 'package:frontend/features/discovery/presentation/components/discovery_sessions_results.dart';
import 'package:frontend/features/discovery/presentation/components/discovery_users_results.dart';
import 'package:frontend/features/discovery/presentation/cubits/discovery_cubit.dart';
import 'package:frontend/features/sessions/domain/entities/study_session.dart';

class DiscoveryResults extends StatelessWidget {
  final DiscoveryState state;
  final String? currentUserId;
  final String emptyMessage;
  final ValueChanged<StudySession> onOpenSession;

  const DiscoveryResults({
    super.key,
    required this.state,
    required this.currentUserId,
    required this.emptyMessage,
    required this.onOpenSession,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final typography = AppTypography.of(context);

    if (state is DiscoveryLoading) {
      return Center(child: CircularProgressIndicator(color: colors.primary));
    }

    if (state is DiscoveryAllLoaded) {
      final loaded = state as DiscoveryAllLoaded;
      return DiscoveryAllResults(
        sessions: loaded.sessions,
        users: loaded.users,
        notes: loaded.notes,
        currentUserId: currentUserId,
        emptyMessage: emptyMessage,
        onOpen: onOpenSession,
      );
    }

    if (state is DiscoverySessionsLoaded) {
      final loaded = state as DiscoverySessionsLoaded;
      return DiscoverySessionsResults(
        sessions: loaded.sessions,
        emptyMessage: emptyMessage,
        onOpen: onOpenSession,
      );
    }

    if (state is DiscoveryUsersLoaded) {
      final loaded = state as DiscoveryUsersLoaded;
      return DiscoveryUsersResults(
        users: loaded.users,
        currentUserId: currentUserId,
        emptyMessage: emptyMessage,
      );
    }

    if (state is DiscoveryNotesLoaded) {
      final loaded = state as DiscoveryNotesLoaded;
      return DiscoveryNotesResults(
        notes: loaded.notes,
        emptyMessage: emptyMessage,
      );
    }

    return Center(
      child: Text(
        genericErrorMessage,
        textAlign: TextAlign.center,
        style: typography.bodySmall,
      ),
    );
  }
}
