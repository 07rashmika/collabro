import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/core/constants/app_routes.dart';
import 'package:frontend/core/constants/app_typography.dart';
import 'package:frontend/features/connections/presentation/connect_request_handler.dart';
import 'package:frontend/features/connections/presentation/cubits/connections_cubit.dart';
import 'package:frontend/features/discovery/presentation/components/discovery_section.dart';
import 'package:frontend/features/discovery/presentation/components/discovery_user_card.dart';
import 'package:frontend/features/discovery/presentation/components/note_preview_sheet.dart';
import 'package:frontend/features/discovery/presentation/cubits/discovery_cubit.dart';
import 'package:frontend/features/notes/domain/entities/note.dart';
import 'package:frontend/features/notes/presentation/components/note_card.dart';
import 'package:frontend/features/sessions/domain/entities/study_session.dart';
import 'package:frontend/features/sessions/presentation/components/session_list_card.dart';
import 'package:frontend/features/users/domain/entities/public_user.dart';
import 'package:go_router/go_router.dart';

class DiscoveryAllResults extends StatelessWidget {
  final List<StudySession> sessions;
  final List<PublicUser> users;
  final List<Note> notes;
  final String? currentUserId;
  final String emptyMessage;
  final ValueChanged<StudySession> onOpen;

  const DiscoveryAllResults({
    super.key,
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
    final filteredUsers = currentUserId == null
        ? users
        : users.where((u) => u.id != currentUserId).toList();
    final connectionsState = context.watch<ConnectionsCubit>().state;

    if (sessions.isEmpty && filteredUsers.isEmpty && notes.isEmpty) {
      return Center(
        child: Text(
          emptyMessage,
          textAlign: .center,
          style: typography.bodySmall,
        ),
      );
    }

    return ListView(
      children: [
        if (sessions.isNotEmpty)
          DiscoverySection(
            title: 'Sessions',
            children: sessions
                .map(
                  (s) => SessionListCard(
                    session: s,
                    onTap: () => onOpen(s),
                    onToggleSave: () =>
                        context.read<DiscoveryCubit>().toggleSaveSession(s),
                  ),
                )
                .toList(),
          ),
        if (filteredUsers.isNotEmpty)
          DiscoverySection(
            title: 'Users',
            children: filteredUsers.map((u) {
              final status = connectionsState.effectiveStatus(
                u.connectionStatus,
                u.id,
              );
              return DiscoveryUserCard(
                user: u,
                connectStatus: status,
                onConnect: () => handleConnectPress(context, u.id, status),
                onTap: () => context.push(AppRoutes.userProfile, extra: u.id),
              );
            }).toList(),
          ),
        if (notes.isNotEmpty)
          DiscoverySection(
            title: 'Notes',
            children: notes
                .map(
                  (n) => NoteCard(
                    note: n,
                    onTap: () => showNotePreviewSheet(context, n),
                  ),
                )
                .toList(),
          ),
      ],
    );
  }
}
