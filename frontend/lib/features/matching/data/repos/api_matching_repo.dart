import 'package:dio/dio.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';
import '../../domain/entities/match_candidate.dart';
import '../../domain/repos/matching_repo.dart';
import '../matching_endpoints.dart';

class ApiMatchingRepo implements MatchingRepo {
  final ApiClient apiClient;

  ApiMatchingRepo({required this.apiClient});

  @override
  Future<List<MatchCandidate>> getMatches({int limit = 10}) async {
    try {
      final response = await apiClient.get(
        MatchingEndpoints.suggestions,
        query: {'limit': limit.toString()},
      );

      final suggestions =
          (response.data['suggestions'] as List<dynamic>?) ?? [];
      return suggestions
          .map((s) => MatchCandidate.fromJson(s as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    } catch (e) {
      throw Exception('Fetching matches failed: $e');
    }
  }
}
