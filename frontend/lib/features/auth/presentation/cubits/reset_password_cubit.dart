import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/repos/auth_repo.dart';

part 'reset_password_state.dart';

class ResetPasswordCubit extends Cubit<ResetPasswordState> {
  final AuthRepo authRepo;

  ResetPasswordCubit({required this.authRepo})
    : super(const ResetPasswordInitial());

  Future<void> reset({
    required String resetToken,
    required String newPassword,
  }) async {
    emit(const ResetPasswordLoading());
    try {
      await authRepo.resetPassword(
        resetToken: resetToken,
        newPassword: newPassword,
      );
      emit(const ResetPasswordSuccess());
    } catch (e) {
      emit(ResetPasswordError(e.toString().replaceFirst('Exception: ', '')));
    }
  }
}
