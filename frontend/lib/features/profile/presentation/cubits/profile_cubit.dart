import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../auth/domain/entities/app_user.dart';
import '../../../auth/domain/repos/auth_repo.dart';
import '../../../connections/domain/repos/connections_repo.dart';
import '../../../profiles/domain/entities/profile.dart';
import '../../../profiles/domain/repos/profiles_repo.dart';

part 'profile_state.dart';

class ProfileCubit extends Cubit<ProfileState> {
  final AuthRepo authRepo;
  final ProfilesRepo profilesRepo;
  final ConnectionsRepo connectionsRepo;

  ProfileCubit({
    required this.authRepo,
    required this.profilesRepo,
    required this.connectionsRepo,
  }) : super(const ProfileLoading());

  Future<void> loadProfile() async {
    emit(const ProfileLoading());
    try {
      final results = await Future.wait([
        authRepo.getCurrentUser(),
        profilesRepo.getMyProfile(),
        connectionsRepo.getConnectedUserIds(),
      ]);
      final user = results[0] as AppUser?;
      if (user == null) {
        emit(const ProfileError('You are not signed in.'));
        return;
      }
      final connectedUserIds = results[2] as List<String>;
      emit(
        ProfileLoaded(
          user: user,
          profile: results[1] as Profile?,
          connectionsCount: connectedUserIds.length,
        ),
      );
    } catch (e) {
      emit(ProfileError(e.toString().replaceFirst('Exception: ', '')));
    }
  }
}
