part of 'verify_reset_code_cubit.dart';

sealed class VerifyResetCodeState extends Equatable {
  const VerifyResetCodeState();

  @override
  List<Object?> get props => [];
}

final class VerifyResetCodeInitial extends VerifyResetCodeState {
  const VerifyResetCodeInitial();
}

final class VerifyResetCodeLoading extends VerifyResetCodeState {
  const VerifyResetCodeLoading();
}

final class VerifyResetCodeVerified extends VerifyResetCodeState {
  final String resetToken;
  const VerifyResetCodeVerified(this.resetToken);

  @override
  List<Object?> get props => [resetToken];
}

final class VerifyResetCodeError extends VerifyResetCodeState {
  final String message;
  const VerifyResetCodeError(this.message);

  @override
  List<Object?> get props => [message];
}
