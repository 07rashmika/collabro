import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/api_exception.dart';
import '../../domain/entities/study_session.dart';
import '../../domain/repos/sessions_repo.dart';

part 'sessions_state.dart';

class SessionsCubit extends Cubit<SessionsState> {
  final SessionsRepo sessionsRepo;

  SessionsCubit({required this.sessionsRepo}) : super(const SessionsInitial());

  Future<void> loadSessions() async {
    emit(const SessionsLoading());
    try {
      final sessions = await sessionsRepo.getMySessions();
      emit(SessionsLoaded(sessions));
    } catch (e) {
      emit(SessionsError(e.toString().replaceFirst('Exception: ', '')));
    }
  }

  /// The user's own upcoming sessions, merged with public sessions from
  /// other students that match the user's skills — this is what "Upcoming
  /// Sessions" on the Home tab shows, sorted together by scheduled time.
  Future<void> loadUpcomingSessions() async {
    emit(const SessionsLoading());
    try {
      final results = await Future.wait([
        sessionsRepo.getMySessions(upcoming: true),
        sessionsRepo.discoverSessions(),
      ]);
      final merged = [...results[0], ...results[1]]..sort((a, b) {
        final aTime = a.scheduledAt ?? DateTime(9999);
        final bTime = b.scheduledAt ?? DateTime(9999);
        return aTime.compareTo(bTime);
      });
      emit(SessionsLoaded(merged));
    } catch (e) {
      emit(SessionsError(e.toString().replaceFirst('Exception: ', '')));
    }
  }

  Future<void> loadSavedSessions() async {
    emit(const SessionsLoading());
    try {
      final sessions = await sessionsRepo.getSavedSessions();
      emit(SessionsLoaded(sessions));
    } catch (e) {
      emit(SessionsError(e.toString().replaceFirst('Exception: ', '')));
    }
  }

  Future<void> loadEndedSessions() async {
    emit(const SessionsLoading());
    try {
      final sessions = await sessionsRepo.getMySessions(status: SessionStatus.closed);
      emit(SessionsLoaded(sessions));
    } catch (e) {
      emit(SessionsError(e.toString().replaceFirst('Exception: ', '')));
    }
  }

  /// Optimistically flips `savedByMe` in the current list, then persists it;
  /// reverts the list back if the request fails.
  Future<void> toggleSaveSession(StudySession session) async {
    final current = state;
    if (current is! SessionsLoaded) return;

    final wasSaved = session.savedByMe;
    emit(
      SessionsLoaded(
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
      emit(SessionsLoaded(current.sessions));
      emit(SessionsError(e.toString().replaceFirst('Exception: ', '')));
    }
  }

  Future<void> loadSessionPassword(String id) async {
    try {
      final password = await sessionsRepo.getSessionPassword(id);
      emit(SessionPasswordViewed(password));
    } catch (e) {
      emit(SessionsError(e.toString().replaceFirst('Exception: ', '')));
    }
  }

  Future<void> createSession({
    required String title,
    required SessionType type,
    required List<String> participantIds,
    DateTime? scheduledAt,
    String? password,
    List<String> tagIds = const [],
    bool isPublic = false,
  }) async {
    emit(const SessionSaving());
    try {
      final session = await sessionsRepo.createSession(
        title: title,
        type: type,
        participantIds: participantIds,
        scheduledAt: scheduledAt,
        password: password,
        tagIds: tagIds,
        isPublic: isPublic,
      );
      emit(SessionSaved(session));
    } catch (e) {
      emit(SessionsError(e.toString().replaceFirst('Exception: ', '')));
    }
  }

  Future<void> joinSessionByCode({
    required String joinCode,
    String? password,
  }) async {
    emit(const SessionSaving());
    try {
      final session = await sessionsRepo.joinSessionByCode(
        joinCode: joinCode,
        password: password,
      );
      emit(SessionSaved(session));
    } on ApiException catch (e) {
      if (e.statusCode == 403) {
        emit(SessionPasswordRequired(e.message));
      } else {
        emit(SessionsError(e.message));
      }
    } catch (e) {
      emit(SessionsError(e.toString().replaceFirst('Exception: ', '')));
    }
  }

  Future<void> closeSession(String id) async {
    emit(const SessionSaving());
    try {
      final session = await sessionsRepo.closeSession(id);
      emit(SessionSaved(session));
    } catch (e) {
      emit(SessionsError(e.toString().replaceFirst('Exception: ', '')));
    }
  }

  Future<void> deleteSession(String id) async {
    emit(const SessionSaving());
    try {
      await sessionsRepo.deleteSession(id);
      emit(SessionDeleted(id));
    } catch (e) {
      emit(SessionsError(e.toString().replaceFirst('Exception: ', '')));
    }
  }
}
