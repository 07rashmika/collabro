abstract class ConnectionsEndpoints {
  static const String base = '/connections';
  static const String mine = '/connections/mine';
  static const String mineUsers = '/connections/mine/users';

  static String usersOf(String userId) => '$base/$userId/users';

  static String accept(String connectionId) => '$base/$connectionId/accept';
  static String decline(String connectionId) => '$base/$connectionId/decline';
  static String remove(String userId) => '$base/$userId';
}
