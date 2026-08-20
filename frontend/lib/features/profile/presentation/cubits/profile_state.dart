part of 'profile_cubit.dart';

sealed class ProfileState extends Equatable {
  const ProfileState();

  @override
  List<Object?> get props => [];
}

final class ProfileLoading extends ProfileState {
  const ProfileLoading();
}

final class ProfileLoaded extends ProfileState {
  final AppUser user;
  final Profile? profile;
  final int connectionsCount;

  const ProfileLoaded({
    required this.user,
    required this.profile,
    this.connectionsCount = 0,
  });

  @override
  List<Object?> get props => [user, profile, connectionsCount];
}

final class ProfileError extends ProfileState {
  final String message;
  const ProfileError(this.message);

  @override
  List<Object?> get props => [message];
}
