abstract class AppRoutes {
  //splash
  static const String splash = '/';

  //onboarding
  static const String onboarding = '/onboarding';

  //auth
  static const String signIn = '/sign-in';
  static const String signUp = '/sign-up';
  static const String forgotPassword = '/forgot-password';
  static const String verifyResetCode = '/verify-reset-code';
  static const String resetPassword = '/reset-password';
  static const String profileSetup = '/profile-setup';

  //main shell
  static const String home = '/home';
  static const String discovery = '/discovery';
  static const String sessions = '/sessions';
  static const String notes = '/notes';
  static const String profile = '/profile';

  //detail screens (pushed on top of shell)
  static const String sessionDetail = '/session-detail';
  static const String newSession = '/session-new';
  static const String joinSession = '/session-join';
  static const String noteDetail = '/note-detail';
  static const String noteEditor = '/note-editor';
  static const String aiInsights = '/ai-insights';
  static const String chat = '/chat';
  static const String editProfile = '/edit-profile';
  static const String notifications = '/notifications';
  static const String settings = '/settings';
  static const String userProfile = '/user-profile';
  static const String connections = '/connections';
}
