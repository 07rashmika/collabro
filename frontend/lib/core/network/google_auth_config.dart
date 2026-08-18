class GoogleAuthConfig {
  static const String serverClientId = .fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue: 'REPLACE_WITH_GOOGLE_WEB_CLIENT_ID',
  );
}
