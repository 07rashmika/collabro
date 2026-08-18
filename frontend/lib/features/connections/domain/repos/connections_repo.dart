abstract class ConnectionsRepo {
  Future<void> sendRequest(String userId);
  Future<void> cancelRequest(String userId);
  Future<void> accept(String connectionId);
  Future<void> decline(String connectionId);

  Future<List<String>> getConnectedUserIds();
}
