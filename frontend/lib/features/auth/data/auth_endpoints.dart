abstract class AuthEndpoints {
  static const String register = '/auth/register';
  static const String login = '/auth/login';
  static const String google = '/auth/google';
  static const String logout = '/auth/logout';
  static const String refresh = '/auth/refresh';

  // Owned by the users module on the backend, not /auth/me.
  static const String currentUser = '/users/me';
}
