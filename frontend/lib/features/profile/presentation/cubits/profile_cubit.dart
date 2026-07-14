import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../auth/domain/entities/app_user.dart';
import '../../../auth/domain/repos/auth_repo.dart';
import '../../../profiles/domain/entities/profile.dart';
import '../../../profiles/domain/repos/profiles_repo.dart';

part 'profile_state.dart';

class ProfileCubit extends Cubit<ProfileState> {
  final AuthRepo authRepo;
  final ProfilesRepo profilesRepo;

  ProfileCubit({required this.authRepo, required this.profilesRepo})
    : super(const ProfileLoading());

  Future<void> loadProfile() async {
    emit(const ProfileLoading());
    try {
      final results = await Future.wait([
        authRepo.getCurrentUser(),
        profilesRepo.getMyProfile(),
      ]);
      final user = results[0] as AppUser?;
      if (user == null) {
        emit(const ProfileError('You are not signed in.'));
        return;
      }
      emit(ProfileLoaded(user: user, profile: results[1] as Profile?));
    } catch (e) {
      emit(ProfileError(e.toString().replaceFirst('Exception: ', '')));
    }
  }
}
