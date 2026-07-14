import 'package:dio/dio.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';
import '../../domain/entities/profile.dart';
import '../../domain/repos/profiles_repo.dart';
import '../profiles_endpoints.dart';

class ApiProfilesRepo implements ProfilesRepo {
  final ApiClient apiClient;

  ApiProfilesRepo({required this.apiClient});

  @override
  Future<Profile?> getMyProfile() async {
    try {
      final response = await apiClient.get(ProfilesEndpoints.me);
      return Profile.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      throw ApiException.fromDioError(e);
    } catch (e) {
      throw Exception('Fetching profile failed: $e');
    }
  }

  @override
  Future<Profile> createProfile({
    String? bio,
    String? learningGoal,
    String? teachGoal,
    List<String>? interests,
    List<ProfileSkillInput>? skills,
    List<String>? studyAreaIds,
  }) async {
    try {
      final response = await apiClient.post(
        ProfilesEndpoints.profiles,
        data: {
          if (bio != null && bio.isNotEmpty) 'bio': bio,
          if (learningGoal != null && learningGoal.isNotEmpty)
            'learningGoal': learningGoal,
          if (teachGoal != null && teachGoal.isNotEmpty) 'teachGoal': teachGoal,
          if (interests != null) 'interests': interests,
          if (skills != null)
            'skills': skills
                .map((s) => {'skillId': s.skillId, 'level': s.level})
                .toList(),
          if (studyAreaIds != null) 'studyAreaIds': studyAreaIds,
        },
      );
      return Profile.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    } catch (e) {
      throw Exception('Creating profile failed: $e');
    }
  }

  @override
  Future<Profile> updateProfile({
    String? bio,
    String? learningGoal,
    String? teachGoal,
    List<String>? interests,
  }) async {
    try {
      final response = await apiClient.patch(
        ProfilesEndpoints.profiles,
        data: {
          if (bio != null) 'bio': bio,
          if (learningGoal != null) 'learningGoal': learningGoal,
          if (teachGoal != null) 'teachGoal': teachGoal,
          if (interests != null) 'interests': interests,
        },
      );
      return Profile.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    } catch (e) {
      throw Exception('Updating profile failed: $e');
    }
  }

  @override
  Future<void> addSkill({
    required String skillId,
    required String level,
  }) async {
    try {
      await apiClient.post(
        ProfilesEndpoints.skills,
        data: {'skillId': skillId, 'level': level},
      );
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    } catch (e) {
      throw Exception('Adding skill failed: $e');
    }
  }

  @override
  Future<void> removeSkill(String skillId) async {
    try {
      await apiClient.delete(
        ProfilesEndpoints.skills,
        data: {'skillId': skillId},
      );
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    } catch (e) {
      throw Exception('Removing skill failed: $e');
    }
  }

  @override
  Future<void> addStudyArea(String studyAreaId) async {
    try {
      await apiClient.post(
        ProfilesEndpoints.studyAreas,
        data: {'studyAreaId': studyAreaId},
      );
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    } catch (e) {
      throw Exception('Adding study area failed: $e');
    }
  }

  @override
  Future<void> removeStudyArea(String studyAreaId) async {
    try {
      await apiClient.delete(
        ProfilesEndpoints.studyAreas,
        data: {'studyAreaId': studyAreaId},
      );
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    } catch (e) {
      throw Exception('Removing study area failed: $e');
    }
  }
}
