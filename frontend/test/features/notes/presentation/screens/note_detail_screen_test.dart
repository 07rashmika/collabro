import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:frontend/features/notes/domain/entities/note.dart';
import 'package:frontend/features/notes/domain/repos/notes_repo.dart';
import 'package:frontend/features/notes/presentation/screens/note_detail_screen.dart';

class MockNotesRepo extends Mock implements NotesRepo {}

void main() {
  late MockNotesRepo notesRepo;

  Note buildNote({bool isPublic = false}) {
    final now = DateTime(2026, 1, 1);
    return Note(
      id: 'n1',
      title: 'Lecture recap',
      content: 'Everything we covered today.',
      tags: const ['algorithms', 'week-3'],
      isPublic: isPublic,
      createdAt: now,
      updatedAt: now,
      authorId: 'author-1',
      authorName: 'Ada',
    );
  }

  setUp(() {
    notesRepo = MockNotesRepo();
  });

  // NoteDetailScreen navigates via go_router's context.pop()/context.push(),
  // not Navigator directly, so a bare MaterialApp isn't enough for anything
  // that pops (the back arrow, the delete dialog's actions). Nesting the
  // route under '/' gives a two-deep page stack so pop() has somewhere to
  // go back to, matching how it's reached in the real app.
  Widget wrap(Note note) {
    final router = GoRouter(
      initialLocation: '/note',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: SizedBox()),
          routes: [
            GoRoute(
              path: 'note',
              builder: (_, _) => RepositoryProvider<NotesRepo>.value(
                value: notesRepo,
                child: NoteDetailScreen(note: note),
              ),
            ),
          ],
        ),
      ],
    );
    return MaterialApp.router(routerConfig: router);
  }

  testWidgets('renders the note title, content, and tags', (tester) async {
    await tester.pumpWidget(wrap(buildNote()));

    expect(find.text('Lecture recap'), findsOneWidget);
    expect(find.text('Everything we covered today.'), findsOneWidget);
    expect(find.text('algorithms'), findsOneWidget);
    expect(find.text('week-3'), findsOneWidget);
  });

  testWidgets('shows the lock icon for a private note', (tester) async {
    await tester.pumpWidget(wrap(buildNote(isPublic: false)));

    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    expect(find.byIcon(Icons.public), findsNothing);
  });

  testWidgets(
    'tapping the visibility toggle flips the note to public',
    (tester) async {
      when(
        () => notesRepo.toggleVisibility('n1'),
      ).thenAnswer((_) async => buildNote(isPublic: true));

      await tester.pumpWidget(wrap(buildNote(isPublic: false)));

      await tester.tap(find.byIcon(Icons.lock_outline));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.public), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline), findsNothing);
      verify(() => notesRepo.toggleVisibility('n1')).called(1);
    },
  );

  testWidgets(
    'tapping Delete Note asks for confirmation before deleting anything',
    (tester) async {
      await tester.pumpWidget(wrap(buildNote()));

      await tester.tap(find.text('Delete Note'));
      await tester.pumpAndSettle();

      expect(
        find.text('This permanently deletes "Lecture recap". This can\'t be undone.'),
        findsOneWidget,
      );
      // The repo must not be touched until the user confirms.
      verifyNever(() => notesRepo.deleteNote(any()));

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Delete note?'), findsNothing);
      verifyNever(() => notesRepo.deleteNote(any()));
    },
  );
}
