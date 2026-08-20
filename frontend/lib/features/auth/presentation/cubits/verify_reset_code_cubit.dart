import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/repos/auth_repo.dart';

part 'verify_reset_code_state.dart';

class VerifyResetCodeCubit extends Cubit<VerifyResetCodeState> {
  final AuthRepo authRepo;

  VerifyResetCodeCubit({required this.authRepo})
    : super(const VerifyResetCodeInitial());

  Future<void> verify({required String email, required String code}) async {
    emit(const VerifyResetCodeLoading());
    try {
      final resetToken = await authRepo.verifyResetCode(
        email: email,
        code: code,
      );
      emit(VerifyResetCodeVerified(resetToken));
    } catch (e) {
      emit(VerifyResetCodeError(e.toString().replaceFirst('Exception: ', '')));
    }
  }
}
