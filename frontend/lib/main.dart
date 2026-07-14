import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/core/router/app_router.dart';
import 'package:frontend/features/auth/data/repos/api_auth_repo.dart';
import 'package:frontend/features/auth/domain/repos/auth_repo.dart';
import 'package:frontend/features/matching/data/repos/api_matching_repo.dart';
import 'package:frontend/features/matching/domain/repos/matching_repo.dart';
import 'package:frontend/features/notes/data/repos/api_notes_repo.dart';
import 'package:frontend/features/notes/domain/repos/notes_repo.dart';
import 'package:frontend/features/profiles/data/repos/api_profiles_repo.dart';
import 'package:frontend/features/profiles/domain/repos/profiles_repo.dart';
import 'package:frontend/features/sessions/data/repos/api_sessions_repo.dart';
import 'package:frontend/features/sessions/domain/repos/sessions_repo.dart';
import 'package:frontend/features/skills/data/repos/api_skills_repo.dart';
import 'package:frontend/features/skills/domain/repos/skills_repo.dart';
import 'package:frontend/features/study_areas/data/repos/api_study_areas_repo.dart';
import 'package:frontend/features/study_areas/domain/repos/study_areas_repo.dart';

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

    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<FlutterSecureStorage>(create: (_) => storage),
        RepositoryProvider<AuthRepo>(create: (_) => authRepo),
        RepositoryProvider<MatchingRepo>(create: (_) => matchingRepo),
        RepositoryProvider<NotesRepo>(create: (_) => notesRepo),
        RepositoryProvider<SessionsRepo>(create: (_) => sessionsRepo),
        RepositoryProvider<ProfilesRepo>(create: (_) => profilesRepo),
        RepositoryProvider<SkillsRepo>(create: (_) => skillsRepo),
        RepositoryProvider<StudyAreasRepo>(create: (_) => studyAreasRepo),
      ],
      child: MaterialApp.router(
        title: 'Collabro',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(colorScheme: .fromSeed(seedColor: Colors.deepPurple)),
        routerConfig: AppRouter.router,
      ),
    );
  }
}
