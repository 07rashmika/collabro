import 'package:dio/dio.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';
import '../../domain/entities/ice_server_config.dart';
import '../../domain/entities/session_message.dart';
import '../../domain/entities/study_session.dart';
import '../../domain/repos/sessions_repo.dart';
import '../sessions_endpoints.dart';

class ApiSessionsRepo implements SessionsRepo {
  final ApiClient apiClient;

  ApiSessionsRepo({required this.apiClient});

  @override
  Future<List<StudySession>> getMySessions({
    SessionStatus? status,
    SessionType? type,
    bool upcoming = false,
  }) async {
    try {
      final response = await apiClient.get(
        SessionsEndpoints.base,
        query: {
          if (status != null) 'status': status == SessionStatus.closed ? 'CLOSED' : 'ACTIVE',
          if (type != null) 'type': type.toJson(),
          if (upcoming) 'upcoming': 'true',
        },
      );
      final sessions = (response.data['sessions'] as List<dynamic>?) ?? [];
      return sessions.map((s) => StudySession.fromJson(s as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    } catch (e) {
      throw Exception('Fetching sessions failed: $e');
    }
  }

  @override
  Future<StudySession> getSessionById(String id) async {
    try {
      final response = await apiClient.get(SessionsEndpoints.byId(id));
      return StudySession.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    } catch (e) {
      throw Exception('Fetching session failed: $e');
    }
  }

  @override
  Future<StudySession> createSession({
    required String title,
    required SessionType type,
    required List<String> participantIds,
    DateTime? scheduledAt,
    String? password,
    List<String> tagIds = const [],
    bool isPublic = false,
  }) async {
    try {
      final response = await apiClient.post(
        SessionsEndpoints.base,
        data: {
          'title': title,
          'type': type.toJson(),
          'participantIds': participantIds,
          if (scheduledAt != null) 'scheduledAt': scheduledAt.toUtc().toIso8601String(),
          if (password != null && password.isNotEmpty) 'password': password,
          'tagIds': tagIds,
          'isPublic': isPublic,
        },
      );
      return StudySession.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    } catch (e) {
      throw Exception('Creating session failed: $e');
    }
  }

  @override
  Future<StudySession> joinSessionByCode({
    required String joinCode,
    String? password,
  }) async {
    try {
      final response = await apiClient.post(
        SessionsEndpoints.join,
        data: {
          'joinCode': joinCode,
          if (password != null && password.isNotEmpty) 'password': password,
        },
      );
      return StudySession.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    } catch (e) {
      throw Exception('Joining session failed: $e');
    }
  }

  @override
  Future<StudySession> closeSession(String id) async {
    try {
      final response = await apiClient.patch(SessionsEndpoints.close(id));
      return StudySession.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    } catch (e) {
      throw Exception('Closing session failed: $e');
    }
  }

  @override
  Future<void> deleteSession(String id) async {
    try {
      await apiClient.delete(SessionsEndpoints.byId(id));
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    } catch (e) {
      throw Exception('Deleting session failed: $e');
    }
  }

  @override
  Future<List<StudySession>> discoverSessions({int page = 1, int limit = 10}) async {
    try {
      final response = await apiClient.get(
        SessionsEndpoints.discover,
        query: {'page': '$page', 'limit': '$limit'},
      );
      final sessions = (response.data['sessions'] as List<dynamic>?) ?? [];
      return sessions.map((s) => StudySession.fromJson(s as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    } catch (e) {
      throw Exception('Fetching suggested sessions failed: $e');
    }
  }

  @override
  Future<List<StudySession>> getSavedSessions({int page = 1, int limit = 10}) async {
    try {
      final response = await apiClient.get(
        SessionsEndpoints.saved,
        query: {'page': '$page', 'limit': '$limit'},
      );
      final sessions = (response.data['sessions'] as List<dynamic>?) ?? [];
      return sessions.map((s) => StudySession.fromJson(s as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    } catch (e) {
      throw Exception('Fetching saved sessions failed: $e');
    }
  }

  @override
  Future<void> saveSession(String id) async {
    try {
      await apiClient.post(SessionsEndpoints.save(id));
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    } catch (e) {
      throw Exception('Saving session failed: $e');
    }
  }

  @override
  Future<void> unsaveSession(String id) async {
    try {
      await apiClient.delete(SessionsEndpoints.save(id));
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    } catch (e) {
      throw Exception('Removing saved session failed: $e');
    }
  }

  @override
  Future<String?> getSessionPassword(String id) async {
    try {
      final response = await apiClient.get(SessionsEndpoints.password(id));
      return (response.data as Map<String, dynamic>)['password'] as String?;
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    } catch (e) {
      throw Exception('Fetching session password failed: $e');
    }
  }

  @override
  Future<List<SessionMessage>> getMessages(String sessionId) async {
    try {
      final response = await apiClient.get(
        SessionsEndpoints.messages(sessionId),
        query: {'limit': '100'},
      );
      final messages = (response.data['messages'] as List<dynamic>?) ?? [];
      return messages
          .map((m) => SessionMessage.fromJson(m as Map<String, dynamic>, sessionId: sessionId))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    } catch (e) {
      throw Exception('Fetching messages failed: $e');
    }
  }

  @override
  Future<SessionMessage> sendMessage(String sessionId, String content) async {
    try {
      final response = await apiClient.post(
        SessionsEndpoints.messages(sessionId),
        data: {'content': content},
      );
      return SessionMessage.fromJson(response.data as Map<String, dynamic>, sessionId: sessionId);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    } catch (e) {
      throw Exception('Sending message failed: $e');
    }
  }

  @override
  Future<void> deleteMessage(String sessionId, String messageId) async {
    try {
      await apiClient.delete(SessionsEndpoints.message(sessionId, messageId));
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    } catch (e) {
      throw Exception('Deleting message failed: $e');
    }
  }

  @override
  Future<IceServersResponse> getIceServers(String sessionId) async {
    try {
      final response = await apiClient.get(SessionsEndpoints.iceServers(sessionId));
      return IceServersResponse.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    } catch (e) {
      throw Exception('Fetching ICE servers failed: $e');
    }
  }
}
