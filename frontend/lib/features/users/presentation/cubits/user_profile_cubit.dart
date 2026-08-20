import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:frontend/features/connections/domain/repos/connections_repo.dart';
import 'package:frontend/features/notes/domain/entities/note.dart';
import 'package:frontend/features/notes/domain/repos/notes_repo.dart';
import 'package:frontend/features/sessions/domain/entities/study_session.dart';
import 'package:frontend/features/sessions/domain/repos/sessions_repo.dart';

import '../../domain/entities/public_user.dart';
import '../../domain/repos/users_repo.dart';

part 'user_profile_state.dart';

class UserProfileCubit extends Cubit<UserProfileState> {
  final UsersRepo usersRepo;
  final NotesRepo notesRepo;
  final SessionsRepo sessionsRepo;
  final ConnectionsRepo connectionsRepo;
  final String userId;

  UserProfileCubit({
    required this.usersRepo,
    required this.notesRepo,
    required this.sessionsRepo,
    required this.connectionsRepo,
    required this.userId,
  }) : super(const UserProfileInitial());

  Future<void> load() async {
    emit(const UserProfileLoading());
    try {
      final (user, notes, sessions, connections) = await (
        usersRepo.getUserById(userId),
        notesRepo.getNotesByUser(userId),
        sessionsRepo.getPublicSessionsByUser(userId),
        connectionsRepo.getConnectionsOf(userId),
      ).wait;
      emit(
        UserProfileLoaded(
          user: user,
          notes: notes,
          sessions: sessions,
          connectionsCount: connections.length,
        ),
      );
    } catch (e) {
      emit(UserProfileError(e.toString().replaceFirst('Exception: ', '')));
    }
  }
}
