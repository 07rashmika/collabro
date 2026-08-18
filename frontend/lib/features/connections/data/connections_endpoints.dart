abstract class ConnectionsEndpoints {
  static const String base = '/connections';
  static const String mine = '/connections/mine';

  static String accept(String connectionId) => '$base/$connectionId/accept';
  static String decline(String connectionId) => '$base/$connectionId/decline';
}
