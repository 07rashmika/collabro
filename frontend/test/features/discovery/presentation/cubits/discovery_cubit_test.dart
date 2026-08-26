import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:frontend/features/discovery/presentation/cubits/discovery_cubit.dart';
import 'package:frontend/features/notes/domain/entities/note.dart';
import 'package:frontend/features/notes/domain/repos/notes_repo.dart';
import 'package:frontend/features/sessions/domain/repos/sessions_repo.dart';
import 'package:frontend/features/users/domain/entities/public_user.dart';
import 'package:frontend/features/users/domain/repos/users_repo.dart';

class MockSessionsRepo extends Mock implements SessionsRepo {}

class MockUsersRepo extends Mock implements UsersRepo {}

class MockNotesRepo extends Mock implements NotesRepo {}

void main() {
  late MockSessionsRepo sessionsRepo;
  late MockUsersRepo usersRepo;
  late MockNotesRepo notesRepo;

  const publicUser = PublicUser(id: 'u2', name: 'Grace', email: 'grace@example.com');

  Note buildNote() {
    final now = DateTime(2026, 1, 1);
    return Note(
      id: 'n1',
      title: 'Shared note',
      content: 'Body',
      tags: const [],
      isPublic: true,
      createdAt: now,
      updatedAt: now,
      authorId: 'author-1',
      authorName: 'Grace',
    );
  }

  setUp(() {
    sessionsRepo = MockSessionsRepo();
    usersRepo = MockUsersRepo();
    notesRepo = MockNotesRepo();
  });

  DiscoveryCubit buildCubit() => DiscoveryCubit(
    sessionsRepo: sessionsRepo,
    usersRepo: usersRepo,
    notesRepo: notesRepo,
  );

  group('DiscoveryCubit.search — users target', () {
    blocTest<DiscoveryCubit, DiscoveryState>(
      'emits [loading, usersLoaded] and only queries the users repo',
      setUp: () {
        when(
          () => usersRepo.searchUsers(search: 'grace'),
        ).thenAnswer((_) async => [publicUser]);
      },
      build: buildCubit,
      act: (cubit) => cubit.search(DiscoveryTarget.users, 'grace'),
      expect: () => [
        const DiscoveryLoading(),
        const DiscoveryUsersLoaded([publicUser]),
      ],
      verify: (_) {
        verifyNever(() => sessionsRepo.discoverSessions(search: any(named: 'search')));
        verifyNever(() => notesRepo.getPublicNotes(search: any(named: 'search')));
      },
    );
  });

  group('DiscoveryCubit.search — notes target', () {
    blocTest<DiscoveryCubit, DiscoveryState>(
      'emits [loading, notesLoaded] with the matching public notes',
      setUp: () {
        when(
          () => notesRepo.getPublicNotes(search: 'shared'),
        ).thenAnswer((_) async => [buildNote()]);
      },
      build: buildCubit,
      act: (cubit) => cubit.search(DiscoveryTarget.notes, 'shared'),
      expect: () => [const DiscoveryLoading(), DiscoveryNotesLoaded([buildNote()])],
    );
  });

  group('DiscoveryCubit.search — all target', () {
    blocTest<DiscoveryCubit, DiscoveryState>(
      'fans out to all three repos and combines the results',
      setUp: () {
        when(
          () => sessionsRepo.discoverSessions(search: ''),
        ).thenAnswer((_) async => []);
        when(
          () => usersRepo.searchUsers(search: ''),
        ).thenAnswer((_) async => [publicUser]);
        when(
          () => notesRepo.getPublicNotes(search: ''),
        ).thenAnswer((_) async => [buildNote()]);
      },
      build: buildCubit,
      act: (cubit) => cubit.search(DiscoveryTarget.all, ''),
      expect: () => [
        const DiscoveryLoading(),
        DiscoveryAllLoaded(
          sessions: const [],
          users: const [publicUser],
          notes: [buildNote()],
        ),
      ],
    );
  });

  group('DiscoveryCubit.search — error handling', () {
    blocTest<DiscoveryCubit, DiscoveryState>(
      'emits [loading, error] with a clean message when a repo throws',
      setUp: () {
        when(
          () => usersRepo.searchUsers(search: any(named: 'search')),
        ).thenThrow(Exception('Search failed'));
      },
      build: buildCubit,
      act: (cubit) => cubit.search(DiscoveryTarget.users, 'grace'),
      expect: () => [
        const DiscoveryLoading(),
        const DiscoveryError('Search failed'),
      ],
    );
  });
}
