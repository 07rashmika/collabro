import '../entities/ice_server_config.dart';
import '../entities/session_message.dart';
import '../entities/study_session.dart';

abstract class SessionsRepo {
  Future<List<StudySession>> getMySessions({
    SessionStatus? status,
    SessionType? type,
    bool upcoming = false,
  });
  Future<StudySession> getSessionById(String id);
  Future<StudySession> createSession({
    required String title,
    required SessionType type,
    required List<String> participantIds,
    DateTime? scheduledAt,
    String? password,
    List<String> tagIds = const [],
    bool isPublic = false,
  });
  Future<StudySession> joinSessionByCode({
    required String joinCode,
    String? password,
  });
  Future<StudySession> closeSession(String id);
  Future<void> deleteSession(String id);

  /// Public sessions the caller hasn't joined. With no [search] this
  /// matches their own skills — feeds the Home tab's Upcoming Sessions
  /// alongside their own sessions. With [search] it's a title search
  /// instead, used by the Discovery tab.
  Future<List<StudySession>> discoverSessions({String? search, int page = 1, int limit = 10});
  Future<List<StudySession>> getSavedSessions({int page = 1, int limit = 10});
  Future<void> saveSession(String id);
  Future<void> unsaveSession(String id);

  /// Owner-only — the decrypted plaintext password, or null if none is set.
  Future<String?> getSessionPassword(String id);

  Future<List<SessionMessage>> getMessages(String sessionId);
  Future<SessionMessage> sendMessage(String sessionId, String content);
  Future<void> deleteMessage(String sessionId, String messageId);

  Future<IceServersResponse> getIceServers(String sessionId);

  /// Generates (or regenerates) the AI summary for a session's message
  /// transcript, persists it, and returns the updated session.
  Future<StudySession> generateSummary(String sessionId);
}
