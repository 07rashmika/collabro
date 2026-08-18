import 'package:dio/dio.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';
import '../../domain/repos/connections_repo.dart';
import '../connections_endpoints.dart';

class ApiConnectionsRepo implements ConnectionsRepo {
  final ApiClient apiClient;

  ApiConnectionsRepo({required this.apiClient});

  @override
  Future<void> sendRequest(String userId) async {
    try {
      await apiClient.post(
        ConnectionsEndpoints.base,
        data: {'addresseeId': userId},
      );
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    } catch (e) {
      throw Exception('Sending connection request failed: $e');
    }
  }

  @override
  Future<void> cancelRequest(String userId) async {
    try {
      await apiClient.delete(
        ConnectionsEndpoints.base,
        data: {'addresseeId': userId},
      );
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    } catch (e) {
      throw Exception('Cancelling connection request failed: $e');
    }
  }

  @override
  Future<void> accept(String connectionId) async {
    try {
      await apiClient.post(ConnectionsEndpoints.accept(connectionId));
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    } catch (e) {
      throw Exception('Accepting connection request failed: $e');
    }
  }

  @override
  Future<void> decline(String connectionId) async {
    try {
      await apiClient.post(ConnectionsEndpoints.decline(connectionId));
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    } catch (e) {
      throw Exception('Declining connection request failed: $e');
    }
  }

  @override
  Future<List<String>> getConnectedUserIds() async {
    try {
      final response = await apiClient.get(ConnectionsEndpoints.mine);
      final userIds = (response.data['userIds'] as List<dynamic>?) ?? [];
      return userIds.map((id) => id as String).toList();
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    } catch (e) {
      throw Exception('Fetching connections failed: $e');
    }
  }
}
