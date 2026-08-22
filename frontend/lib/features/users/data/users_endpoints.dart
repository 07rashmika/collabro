abstract class UsersEndpoints {
  static const String base = '/users';
  static const String me = '/users/me';

  static String byId(String id) => '/users/$id';

  static const String avatar = '/users/me/avatar';

  static const String deviceTokens = '/users/me/device-tokens';
  static String deviceToken(String token) =>
      '/users/me/device-tokens/${Uri.encodeComponent(token)}';
}
