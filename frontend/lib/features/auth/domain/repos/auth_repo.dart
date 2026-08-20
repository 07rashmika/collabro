import '../entities/app_user.dart';

abstract class AuthRepo {
  Future<AppUser> loginWithEmailPassword(String email, String password);
  Future<AppUser> registerWithEmailPassword(
    String name,
    String email,
    String password,
  );
  Future<AppUser> loginWithGoogle();
  Future<void> logout();
  Future<AppUser?> getCurrentUser();
  Future<void> requestPasswordReset(String email);
  Future<String> verifyResetCode({required String email, required String code});
  Future<void> resetPassword({
    required String resetToken,
    required String newPassword,
  });
}
