abstract class SessionsEndpoints {
  static const String base = '/sessions';
  static const String join = '/sessions/join';
  static const String discover = '/sessions/discover';
  static const String saved = '/sessions/saved';

  static String byId(String id) => '/sessions/$id';
  static String close(String id) => '/sessions/$id/close';
  static String save(String id) => '/sessions/$id/save';
  static String password(String id) => '/sessions/$id/password';
  static String messages(String id) => '/sessions/$id/messages';
  static String message(String id, String messageId) => '/sessions/$id/messages/$messageId';
  static String zegoToken(String id) => '/sessions/$id/zego-token';

  /// Builds the signaling WebSocket URL from the same base the REST client
  /// uses (swap http(s) -> ws(s)) rather than hardcoding a separate host.
  static String signalingWsUrl(String baseHttpUrl, String sessionId, String accessToken) {
    final wsBase = baseHttpUrl.replaceFirst(RegExp(r'^http'), 'ws');
    return '$wsBase/sessions/ws?sessionId=$sessionId&token=$accessToken';
  }
}
