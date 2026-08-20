import 'package:frontend/core/constants/app_routes.dart';
import 'package:frontend/core/router/main_shell.dart';
import 'package:frontend/features/auth/domain/entities/app_user.dart';
import 'package:frontend/features/auth/presentation/screens/forgot_password_screen.dart';
import 'package:frontend/features/auth/presentation/screens/reset_password_screen.dart';
import 'package:frontend/features/auth/presentation/screens/sign_in_screen.dart';
import 'package:frontend/features/auth/presentation/screens/sign_up_screen.dart';
import 'package:frontend/features/auth/presentation/screens/verify_reset_code_screen.dart';
import 'package:frontend/features/connections/presentation/screens/connections_list_screen.dart';
import 'package:frontend/features/discovery/presentation/screens/discovery_screen.dart';
import 'package:frontend/features/home/presentation/screens/home_screen.dart';
import 'package:frontend/features/notes/domain/entities/note.dart';
import 'package:frontend/features/notes/presentation/screens/note_detail_screen.dart';
import 'package:frontend/features/notes/presentation/screens/note_editor_screen.dart';
import 'package:frontend/features/notes/presentation/screens/notes_list_screen.dart';
import 'package:frontend/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:frontend/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:frontend/features/profile/presentation/screens/edit_profile_screen.dart';
import 'package:frontend/features/profile/presentation/screens/profile_screen.dart';
import 'package:frontend/features/profile_setup/presentation/screens/profile_setup_screen.dart';
import 'package:frontend/features/sessions/domain/entities/study_session.dart';
import 'package:frontend/features/sessions/presentation/screens/join_session_screen.dart';
import 'package:frontend/features/sessions/presentation/screens/new_session_screen.dart';
import 'package:frontend/features/sessions/presentation/screens/session_chat_screen.dart';
import 'package:frontend/features/sessions/presentation/screens/sessions_list_screen.dart';
import 'package:frontend/features/sessions/presentation/screens/video_call_screen.dart';
import 'package:frontend/features/settings/presentation/screens/settings_screen.dart';
import 'package:frontend/features/splash/presentation/screens/splash_screen.dart';
import 'package:frontend/features/users/presentation/screens/user_profile_screen.dart';
import 'package:go_router/go_router.dart';

abstract class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: AppRoutes.splash,
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: AppRoutes.signIn,
        builder: (context, state) => const SignInScreen(),
      ),
      GoRoute(
        path: AppRoutes.signUp,
        builder: (context, state) => const SignUpScreen(),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: AppRoutes.verifyResetCode,
        builder: (context, state) =>
            VerifyResetCodeScreen(email: state.extra as String),
      ),
      GoRoute(
        path: AppRoutes.resetPassword,
        builder: (context, state) =>
            ResetPasswordScreen(resetToken: state.extra as String),
      ),
      GoRoute(
        path: AppRoutes.profileSetup,
        builder: (context, state) =>
            ProfileSetupScreen(user: state.extra as AppUser),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            MainShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.discovery,
                builder: (context, state) => const DiscoveryScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.sessions,
                builder: (context, state) => const SessionsListScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.notes,
                builder: (context, state) => const NotesListScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.profile,
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.noteDetail,
        builder: (context, state) =>
            NoteDetailScreen(note: state.extra as Note),
      ),
      GoRoute(
        path: AppRoutes.noteEditor,
        builder: (context, state) =>
            NoteEditorScreen(initialNote: state.extra as Note?),
      ),
      GoRoute(
        path: AppRoutes.newSession,
        builder: (context, state) => const NewSessionScreen(),
      ),
      GoRoute(
        path: AppRoutes.joinSession,
        builder: (context, state) => const JoinSessionScreen(),
      ),
      GoRoute(
        path: AppRoutes.editProfile,
        builder: (context, state) => const EditProfileScreen(),
      ),
      GoRoute(
        path: AppRoutes.settings,
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.notifications,
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: AppRoutes.userProfile,
        builder: (context, state) =>
            UserProfileScreen(userId: state.extra as String),
      ),
      GoRoute(
        path: AppRoutes.connections,
        builder: (context, state) {
          final extra = state.extra as Map<String, String>?;
          return ConnectionsListScreen(
            userId: extra?['userId'],
            userName: extra?['userName'],
          );
        },
      ),
      GoRoute(
        path: AppRoutes.sessionDetail,
        builder: (context, state) {
          final session = state.extra as StudySession;
          return session.type == .video
              ? VideoCallScreen(session: session)
              : SessionChatScreen(session: session);
        },
      ),
    ],
  );
}
