import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:frontend/features/notes/domain/entities/note.dart';
import 'package:frontend/features/notes/domain/repos/notes_repo.dart';
import 'package:frontend/features/sessions/domain/entities/study_session.dart';
import 'package:frontend/features/sessions/domain/repos/sessions_repo.dart';
import 'package:frontend/features/users/domain/entities/public_user.dart';
import 'package:frontend/features/users/domain/repos/users_repo.dart';

part 'discovery_state.dart';

enum DiscoveryTarget { sessions, users, notes }

class DiscoveryCubit extends Cubit<DiscoveryState> {
  final SessionsRepo sessionsRepo;
  final UsersRepo usersRepo;
  final NotesRepo notesRepo;

  DiscoveryCubit({
    required this.sessionsRepo,
    required this.usersRepo,
    required this.notesRepo,
  }) : super(const DiscoveryInitial());

  Future<void> search(DiscoveryTarget target, String query) async {
    emit(const DiscoveryLoading());
    try {
      switch (target) {
        case DiscoveryTarget.sessions:
          final sessions = await sessionsRepo.discoverSessions(search: query);
          emit(DiscoverySessionsLoaded(sessions));
        case DiscoveryTarget.users:
          final users = await usersRepo.searchUsers(search: query);
          emit(DiscoveryUsersLoaded(users));
        case DiscoveryTarget.notes:
          final notes = await notesRepo.getPublicNotes(search: query);
          emit(DiscoveryNotesLoaded(notes));
      }
    } catch (e) {
      emit(DiscoveryError(e.toString().replaceFirst('Exception: ', '')));
    }
  }

  /// Optimistically flips `savedByMe` on a discovered session, then persists
  /// it — mirrors [SessionsCubit.toggleSaveSession] since Discovery keeps
  /// its own session list separate from the Sessions tab's.
  Future<void> toggleSaveSession(StudySession session) async {
    final current = state;
    if (current is! DiscoverySessionsLoaded) return;

    final wasSaved = session.savedByMe;
    emit(
      DiscoverySessionsLoaded(
        current.sessions
            .map((s) => s.id == session.id ? s.copyWith(savedByMe: !wasSaved) : s)
            .toList(),
      ),
    );
    try {
      if (wasSaved) {
        await sessionsRepo.unsaveSession(session.id);
      } else {
        await sessionsRepo.saveSession(session.id);
      }
    } catch (e) {
      emit(DiscoverySessionsLoaded(current.sessions));
      emit(DiscoveryError(e.toString().replaceFirst('Exception: ', '')));
    }
  }
}
