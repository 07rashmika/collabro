import 'package:dio/dio.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../domain/entities/public_user.dart';
import '../../domain/repos/users_repo.dart';
import '../users_endpoints.dart';

class ApiUsersRepo implements UsersRepo {
  final ApiClient apiClient;

  ApiUsersRepo({required this.apiClient});

  @override
  Future<List<PublicUser>> searchUsers({
    String? search,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final response = await apiClient.get(
        UsersEndpoints.base,
        query: {
          if (search != null && search.isNotEmpty) 'search': search,
          'page': '$page',
          'limit': '$limit',
        },
      );
      final users = (response.data['users'] as List<dynamic>?) ?? [];
      return users
          .map((u) => PublicUser.fromJson(u as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    } catch (e) {
      throw Exception('Fetching users failed: $e');
    }
  }

  @override
  Future<PublicUser> getUserById(String id) async {
    try {
      final response = await apiClient.get(UsersEndpoints.byId(id));
      return PublicUser.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    } catch (e) {
      throw Exception('Fetching user failed: $e');
    }
  }

  @override
  Future<AppUser> uploadAvatar(String imagePath) async {
    try {
      final formData = FormData.fromMap({
        'avatar': await MultipartFile.fromFile(imagePath),
      });
      final response = await apiClient.post(
        UsersEndpoints.avatar,
        data: formData,
      );
      return AppUser.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    } catch (e) {
      throw Exception('Uploading profile photo failed: $e');
    }
  }

  @override
  Future<AppUser> deleteAvatar() async {
    try {
      final response = await apiClient.delete(UsersEndpoints.avatar);
      return AppUser.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    } catch (e) {
      throw Exception('Removing profile photo failed: $e');
    }
  }
}
