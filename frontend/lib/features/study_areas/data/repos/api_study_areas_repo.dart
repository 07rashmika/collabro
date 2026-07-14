import 'package:dio/dio.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';
import '../../domain/entities/study_area.dart';
import '../../domain/repos/study_areas_repo.dart';
import '../study_areas_endpoints.dart';

class ApiStudyAreasRepo implements StudyAreasRepo {
  final ApiClient apiClient;

  ApiStudyAreasRepo({required this.apiClient});

  @override
  Future<List<StudyArea>> getAllStudyAreas() async {
    try {
      final response = await apiClient.get(StudyAreasEndpoints.studyAreas);
      final studyAreas = (response.data as List<dynamic>?) ?? [];
      return studyAreas
          .map((s) => StudyArea.fromJson(s as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    } catch (e) {
      throw Exception('Fetching study areas failed: $e');
    }
  }

  @override
  Future<StudyArea> findOrCreateStudyArea(String name) async {
    try {
      final response = await apiClient.post(
        StudyAreasEndpoints.findOrCreate,
        data: {'name': name},
      );
      return StudyArea.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    } catch (e) {
      throw Exception('Adding study area failed: $e');
    }
  }
}
