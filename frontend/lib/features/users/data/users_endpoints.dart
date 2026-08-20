abstract class UsersEndpoints {
  static const String base = '/users';

  static String byId(String id) => '/users/$id';

  static const String avatar = '/users/me/avatar';
}
