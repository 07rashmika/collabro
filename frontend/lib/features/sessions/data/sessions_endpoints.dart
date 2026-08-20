abstract class SessionsEndpoints {
  static const String base = '/sessions';
  static const String join = '/sessions/join';
  static const String discover = '/sessions/discover';
  static const String saved = '/sessions/saved';

  static String byId(String id) => '/sessions/$id';
  static String byUser(String userId) => '/sessions/user/$userId';
  static String close(String id) => '/sessions/$id/close';
  static String save(String id) => '/sessions/$id/save';
  static String password(String id) => '/sessions/$id/password';
  static String messages(String id) => '/sessions/$id/messages';
  static String message(String id, String messageId) =>
      '/sessions/$id/messages/$messageId';
  static String iceServers(String id) => '/sessions/$id/ice-servers';
  static String participant(String id, String userId) =>
      '/sessions/$id/participants/$userId';
  static String summary(String id) => '/sessions/$id/summary';
  static String recording(String id) => '/sessions/$id/recording';

  static String signalingWsUrl(
    String baseHttpUrl,
    String sessionId,
    String accessToken,
  ) {
    final wsBase = baseHttpUrl.replaceFirst(RegExp(r'^http'), 'ws');
    return '$wsBase/sessions/ws?sessionId=$sessionId&token=$accessToken';
  }
}
