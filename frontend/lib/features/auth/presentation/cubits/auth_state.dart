part of 'auth_cubit.dart';

sealed class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

final class AuthInitial extends AuthState {
  const AuthInitial();
}

enum AuthAction { emailPassword, google, logout }

final class AuthLoading extends AuthState {
  final AuthAction action;
  const AuthLoading(this.action);

  @override
  List<Object?> get props => [action];
}

final class AuthSuccess extends AuthState {
  final AppUser user;
  const AuthSuccess(this.user);

  @override
  List<Object?> get props => [user];
}

final class AuthLoggedOut extends AuthState {
  const AuthLoggedOut();
}

final class AuthError extends AuthState {
  final String message;
  const AuthError(this.message);

  @override
  List<Object?> get props => [message];
}
