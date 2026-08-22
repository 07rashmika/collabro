import 'package:equatable/equatable.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:frontend/features/users/domain/repos/users_repo.dart';

import '../../domain/entities/app_user.dart';
import '../../domain/repos/auth_repo.dart';

part 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  final AuthRepo authRepo;
  final UsersRepo usersRepo;

  AuthCubit({required this.authRepo, required this.usersRepo})
    : super(const AuthInitial());

  Future<void> login(String email, String password) async {
    emit(const AuthLoading(AuthAction.emailPassword));
    try {
      final user = await authRepo.loginWithEmailPassword(email, password);
      emit(AuthSuccess(user));
    } catch (e) {
      emit(AuthError(e.toString().replaceFirst('Exception: ', '')));
    }
  }

  Future<void> register(String name, String email, String password) async {
    emit(const AuthLoading(AuthAction.emailPassword));
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
    emit(const AuthLoading(AuthAction.google));
    try {
      final user = await authRepo.loginWithGoogle();
      emit(AuthSuccess(user));
    } catch (e) {
      emit(AuthError(e.toString().replaceFirst('Exception: ', '')));
    }
  }

  Future<void> logout() async {
    emit(const AuthLoading(AuthAction.logout));
    try {
      // Unregister this device's push token first, while the session backing
      // it is still valid — otherwise the account keeps receiving pushes on
      // this device after logout (the token is only ever reassigned to
      // whoever logs in here next, never cleared on its own). Best-effort:
      // a missed unregister shouldn't block logging out.
      try {
        final token = await FirebaseMessaging.instance.getToken();
        if (token != null) await usersRepo.unregisterDeviceToken(token);
      } catch (_) {}

      await authRepo.logout();
      emit(const AuthLoggedOut());
    } catch (e) {
      emit(AuthError(e.toString().replaceFirst('Exception: ', '')));
    }
  }
}
