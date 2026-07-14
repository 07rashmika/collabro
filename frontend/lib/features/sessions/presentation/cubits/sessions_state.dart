part of 'sessions_cubit.dart';

sealed class SessionsState extends Equatable {
  const SessionsState();

  @override
  List<Object?> get props => [];
}

final class SessionsInitial extends SessionsState {
  const SessionsInitial();
}

final class SessionsLoading extends SessionsState {
  const SessionsLoading();
}

final class SessionsLoaded extends SessionsState {
  final List<StudySession> sessions;
  const SessionsLoaded(this.sessions);

  @override
  List<Object?> get props => [sessions];
}

final class SessionSaving extends SessionsState {
  const SessionSaving();
}

final class SessionSaved extends SessionsState {
  final StudySession session;
  const SessionSaved(this.session);

  @override
  List<Object?> get props => [session];
}

final class SessionDeleted extends SessionsState {
  final String sessionId;
  const SessionDeleted(this.sessionId);

  @override
  List<Object?> get props => [sessionId];
}

final class SessionsError extends SessionsState {
  final String message;
  const SessionsError(this.message);

  @override
  List<Object?> get props => [message];
}

/// A join-by-code attempt hit a password-protected session — the join code
/// was valid, so this isn't a generic [SessionsError]: the UI should prompt
/// for a password and retry rather than just showing a snackbar.
final class SessionPasswordRequired extends SessionsState {
  final String message;
  const SessionPasswordRequired(this.message);

  @override
  List<Object?> get props => [message];
}

/// The owner just fetched their session's decrypted password from the info
/// panel — `password` is null if the session has none set.
final class SessionPasswordViewed extends SessionsState {
  final String? password;
  const SessionPasswordViewed(this.password);

  @override
  List<Object?> get props => [password];
}
