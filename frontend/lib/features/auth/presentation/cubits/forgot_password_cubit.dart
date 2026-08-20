import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/repos/auth_repo.dart';

part 'forgot_password_state.dart';

class ForgotPasswordCubit extends Cubit<ForgotPasswordState> {
  final AuthRepo authRepo;

  ForgotPasswordCubit({required this.authRepo})
    : super(const ForgotPasswordInitial());

  Future<void> sendCode(String email) async {
    emit(const ForgotPasswordLoading());
    try {
      await authRepo.requestPasswordReset(email);
      emit(ForgotPasswordCodeSent(email));
    } catch (e) {
      emit(ForgotPasswordError(e.toString().replaceFirst('Exception: ', '')));
    }
  }
}
