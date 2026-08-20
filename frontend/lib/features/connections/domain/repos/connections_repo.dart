import 'package:frontend/features/users/domain/entities/public_user.dart';

abstract class ConnectionsRepo {
  Future<void> sendRequest(String userId);
  Future<void> cancelRequest(String userId);
  Future<void> accept(String connectionId);
  Future<void> decline(String connectionId);
  Future<void> removeConnection(String userId);

  Future<List<String>> getConnectedUserIds();
  Future<List<PublicUser>> getConnectedUsers();
  Future<List<PublicUser>> getConnectionsOf(String userId);
}
