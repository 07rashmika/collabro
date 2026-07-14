import 'package:go_router/go_router.dart';

import 'package:frontend/core/constants/app_routes.dart';
import 'package:frontend/core/router/main_shell.dart';
import 'package:frontend/features/auth/domain/entities/app_user.dart';
import 'package:frontend/features/auth/presentation/screens/sign_in_screen.dart';
import 'package:frontend/features/auth/presentation/screens/sign_up_screen.dart';
import 'package:frontend/features/discovery/presentation/screens/discovery_screen.dart';
import 'package:frontend/features/home/presentation/screens/home_screen.dart';
import 'package:frontend/features/notes/domain/entities/note.dart';
import 'package:frontend/features/notes/presentation/screens/note_detail_screen.dart';
import 'package:frontend/features/notes/presentation/screens/note_editor_screen.dart';
import 'package:frontend/features/notes/presentation/screens/notes_list_screen.dart';
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

abstract class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: AppRoutes.onboarding,
    routes: [
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
                builder: (context, state) =>
                    HomeScreen(user: state.extra as AppUser),
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
      // Detail screens are pushed on top of the shell, so they cover the
      // bottom nav bar instead of living inside a tab's own stack.
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
        path: AppRoutes.sessionDetail,
        builder: (context, state) {
          final session = state.extra as StudySession;
          return session.type == SessionType.video
              ? VideoCallScreen(session: session)
              : SessionChatScreen(session: session);
        },
      ),
    ],
  );
}
