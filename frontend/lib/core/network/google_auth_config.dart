class GoogleAuthConfig {
  // The Web OAuth client ID from Google Cloud Console — the same value the
  // backend uses as GOOGLE_CLIENT_ID. This is what makes the ID token we get
  // on-device verifiable server-side, so it must match on both ends.
  // Override with --dart-define=GOOGLE_SERVER_CLIENT_ID=...
  static const String serverClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue: 'REPLACE_WITH_GOOGLE_WEB_CLIENT_ID',
  );
}
