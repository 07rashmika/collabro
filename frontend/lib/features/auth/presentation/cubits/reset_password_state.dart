part of 'reset_password_cubit.dart';

sealed class ResetPasswordState extends Equatable {
  const ResetPasswordState();

  @override
  List<Object?> get props => [];
}

final class ResetPasswordInitial extends ResetPasswordState {
  const ResetPasswordInitial();
}

final class ResetPasswordLoading extends ResetPasswordState {
  const ResetPasswordLoading();
}

final class ResetPasswordSuccess extends ResetPasswordState {
  const ResetPasswordSuccess();
}

final class ResetPasswordError extends ResetPasswordState {
  final String message;
  const ResetPasswordError(this.message);

  @override
  List<Object?> get props => [message];
}
