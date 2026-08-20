import 'package:dio/dio.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';
import '../../domain/entities/skill.dart';
import '../../domain/repos/skills_repo.dart';
import '../skills_endpoints.dart';

class ApiSkillsRepo implements SkillsRepo {
  final ApiClient apiClient;

  ApiSkillsRepo({required this.apiClient});

  @override
  Future<List<Skill>> getAllSkills() async {
    try {
      final response = await apiClient.get(SkillsEndpoints.skills);
      final skills = (response.data as List<dynamic>?) ?? [];
      return skills
          .map((s) => Skill.fromJson(s as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    } catch (e) {
      throw Exception('Fetching skills failed: $e');
    }
  }

  @override
  Future<Skill> findOrCreateSkill(String name) async {
    try {
      final response = await apiClient.post(
        SkillsEndpoints.findOrCreate,
        data: {'name': name},
      );
      return Skill.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    } catch (e) {
      throw Exception('Adding skill failed: $e');
    }
  }

  @override
  Future<List<String>> searchSkills(String query, {int count = 10}) async {
    try {
      final response = await apiClient.get(
        SkillsEndpoints.search,
        query: {'q': query, 'count': count},
      );
      final results = (response.data as List<dynamic>?) ?? [];
      return results.map((s) => s.toString()).toList();
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    } catch (e) {
      throw Exception('Searching skills failed: $e');
    }
  }
}
