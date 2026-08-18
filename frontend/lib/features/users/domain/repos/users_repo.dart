import '../entities/public_user.dart';

abstract class UsersRepo {
  Future<List<PublicUser>> searchUsers({
    String? search,
    int page = 1,
    int limit = 20,
  });

  Future<PublicUser> getUserById(String id);
}
