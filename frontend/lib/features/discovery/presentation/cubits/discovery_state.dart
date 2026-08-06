part of 'discovery_cubit.dart';

sealed class DiscoveryState extends Equatable {
  const DiscoveryState();

  @override
  List<Object?> get props => [];
}

final class DiscoveryInitial extends DiscoveryState {
  const DiscoveryInitial();
}

final class DiscoveryLoading extends DiscoveryState {
  const DiscoveryLoading();
}

final class DiscoverySessionsLoaded extends DiscoveryState {
  final List<StudySession> sessions;
  const DiscoverySessionsLoaded(this.sessions);

  @override
  List<Object?> get props => [sessions];
}

final class DiscoveryUsersLoaded extends DiscoveryState {
  final List<PublicUser> users;
  const DiscoveryUsersLoaded(this.users);

  @override
  List<Object?> get props => [users];
}

final class DiscoveryNotesLoaded extends DiscoveryState {
  final List<Note> notes;
  const DiscoveryNotesLoaded(this.notes);

  @override
  List<Object?> get props => [notes];
}

/// Combined results for the "All" tab — sessions, users, and notes matching
/// the query, all fetched together rather than one category at a time.
final class DiscoveryAllLoaded extends DiscoveryState {
  final List<StudySession> sessions;
  final List<PublicUser> users;
  final List<Note> notes;

  const DiscoveryAllLoaded({
    required this.sessions,
    required this.users,
    required this.notes,
  });

  @override
  List<Object?> get props => [sessions, users, notes];
}

final class DiscoveryError extends DiscoveryState {
  final String message;
  const DiscoveryError(this.message);

  @override
  List<Object?> get props => [message];
}
