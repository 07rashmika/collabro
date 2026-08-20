import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:frontend/core/constants/app_colors.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/router/app_router.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/features/auth/data/repos/api_auth_repo.dart';
import 'package:frontend/features/auth/domain/repos/auth_repo.dart';
import 'package:frontend/features/connections/data/repos/api_connections_repo.dart';
import 'package:frontend/features/connections/domain/repos/connections_repo.dart';
import 'package:frontend/features/connections/presentation/cubits/connections_cubit.dart';
import 'package:frontend/features/matching/data/repos/api_matching_repo.dart';
import 'package:frontend/features/matching/domain/repos/matching_repo.dart';
import 'package:frontend/features/notes/data/repos/api_notes_repo.dart';
import 'package:frontend/features/notes/domain/repos/notes_repo.dart';
import 'package:frontend/features/notifications/data/repos/api_notifications_repo.dart';
import 'package:frontend/features/notifications/domain/repos/notifications_repo.dart';
import 'package:frontend/features/profiles/data/repos/api_profiles_repo.dart';
import 'package:frontend/features/profiles/domain/repos/profiles_repo.dart';
import 'package:frontend/features/sessions/data/repos/api_sessions_repo.dart';
import 'package:frontend/features/sessions/domain/repos/sessions_repo.dart';
import 'package:frontend/features/settings/presentation/cubits/notification_preferences_cubit.dart';
import 'package:frontend/features/settings/presentation/cubits/theme_cubit.dart';
import 'package:frontend/features/skills/data/repos/api_skills_repo.dart';
import 'package:frontend/features/skills/domain/repos/skills_repo.dart';
import 'package:frontend/features/study_areas/data/repos/api_study_areas_repo.dart';
import 'package:frontend/features/study_areas/domain/repos/study_areas_repo.dart';
import 'package:frontend/features/users/data/repos/api_users_repo.dart';
import 'package:frontend/features/users/domain/repos/users_repo.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    const storage = FlutterSecureStorage();
    final apiClient = ApiClient(storage: storage);
    final authRepo = ApiAuthRepo(apiClient: apiClient, storage: storage);
    final matchingRepo = ApiMatchingRepo(apiClient: apiClient);
    final notesRepo = ApiNotesRepo(apiClient: apiClient);
    final sessionsRepo = ApiSessionsRepo(apiClient: apiClient);
    final profilesRepo = ApiProfilesRepo(apiClient: apiClient);
    final skillsRepo = ApiSkillsRepo(apiClient: apiClient);
    final studyAreasRepo = ApiStudyAreasRepo(apiClient: apiClient);
    final usersRepo = ApiUsersRepo(apiClient: apiClient);
    final connectionsRepo = ApiConnectionsRepo(apiClient: apiClient);
    final notificationsRepo = ApiNotificationsRepo(apiClient: apiClient);

    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<FlutterSecureStorage>(create: (context) => storage),
        RepositoryProvider<AuthRepo>(create: (context) => authRepo),
        RepositoryProvider<MatchingRepo>(create: (context) => matchingRepo),
        RepositoryProvider<NotesRepo>(create: (context) => notesRepo),
        RepositoryProvider<SessionsRepo>(create: (context) => sessionsRepo),
        RepositoryProvider<ProfilesRepo>(create: (context) => profilesRepo),
        RepositoryProvider<SkillsRepo>(create: (context) => skillsRepo),
        RepositoryProvider<StudyAreasRepo>(create: (context) => studyAreasRepo),
        RepositoryProvider<UsersRepo>(create: (context) => usersRepo),
        RepositoryProvider<ConnectionsRepo>(
          create: (context) => connectionsRepo,
        ),
        RepositoryProvider<NotificationsRepo>(
          create: (context) => notificationsRepo,
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(create: (context) => ThemeCubit(storage: storage)),
          BlocProvider(
            create: (context) => NotificationPreferencesCubit(storage: storage),
          ),
          BlocProvider(
            create: (context) => ConnectionsCubit(
              connectionsRepo: context.read<ConnectionsRepo>(),
            ),
          ),
        ],
        child: BlocBuilder<ThemeCubit, ThemeMode>(
          builder: (context, themeMode) {
            return MaterialApp.router(
              title: 'Collabro',
              debugShowCheckedModeBanner: false,
              theme: buildAppTheme(AppColors.light, .light),
              darkTheme: buildAppTheme(AppColors.dark, .dark),
              themeMode: themeMode,
              routerConfig: AppRouter.router,
            );
          },
        ),
      ),
    );
  }
}
