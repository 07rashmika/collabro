import 'package:frontend/features/auth/domain/entities/app_user.dart';

class HomeBootstrap {
  final AppUser? user;
  final List<String> matchedAuthorIds;

  const HomeBootstrap({required this.user, required this.matchedAuthorIds});
}
