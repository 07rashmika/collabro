part of 'user_profile_cubit.dart';

sealed class UserProfileState extends Equatable {
  const UserProfileState();

  @override
  List<Object?> get props => [];
}

final class UserProfileInitial extends UserProfileState {
  const UserProfileInitial();
}

final class UserProfileLoading extends UserProfileState {
  const UserProfileLoading();
}

final class UserProfileLoaded extends UserProfileState {
  final PublicUser user;
  final List<Note> notes;
  final List<StudySession> sessions;
  final int connectionsCount;

  const UserProfileLoaded({
    required this.user,
    required this.notes,
    required this.sessions,
    this.connectionsCount = 0,
  });

  @override
  List<Object?> get props => [user, notes, sessions, connectionsCount];
}

final class UserProfileError extends UserProfileState {
  final String message;
  const UserProfileError(this.message);

  @override
  List<Object?> get props => [message];
}
