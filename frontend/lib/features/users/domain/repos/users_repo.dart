import '../entities/public_user.dart';

abstract class UsersRepo {
  /// Other students matching [search] by name or email — feeds the
  /// Discovery tab's Users search.
  Future<List<PublicUser>> searchUsers({String? search, int page = 1, int limit = 20});
}
