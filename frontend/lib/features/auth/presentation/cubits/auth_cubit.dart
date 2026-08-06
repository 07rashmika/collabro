import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/app_user.dart';
import '../../domain/repos/auth_repo.dart';

part 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  final AuthRepo authRepo;

  AuthCubit({required this.authRepo}) : super(const AuthInitial());

  Future<void> login(String email, String password) async {
    emit(const AuthLoading());
    try {
      final user = await authRepo.loginWithEmailPassword(email, password);
      emit(AuthSuccess(user));
    } catch (e) {
      emit(AuthError(e.toString().replaceFirst('Exception: ', '')));
    }
  }

  Future<void> register(String name, String email, String password) async {
    emit(const AuthLoading());
    try {
      final user = await authRepo.registerWithEmailPassword(
        name,
        email,
        password,
      );
      emit(AuthSuccess(user));
    } catch (e) {
      emit(AuthError(e.toString().replaceFirst('Exception: ', '')));
    }
  }

  Future<void> loginWithGoogle() async {
    emit(const AuthLoading());
    try {
      final user = await authRepo.loginWithGoogle();
      emit(AuthSuccess(user));
    } catch (e) {
      emit(AuthError(e.toString().replaceFirst('Exception: ', '')));
    }
  }

  Future<void> logout() async {
    emit(const AuthLoading());
    try {
      await authRepo.logout();
      emit(const AuthLoggedOut());
    } catch (e) {
      emit(AuthError(e.toString().replaceFirst('Exception: ', '')));
    }
  }
}
