import 'package:frontend/features/auth/domain/entities/app_user.dart';

import '../entities/public_user.dart';

abstract class UsersRepo {
  Future<List<PublicUser>> searchUsers({
    String? search,
    int page = 1,
    int limit = 20,
  });

  Future<PublicUser> getUserById(String id);

  Future<AppUser> uploadAvatar(String imagePath);

  Future<AppUser> deleteAvatar();
}
