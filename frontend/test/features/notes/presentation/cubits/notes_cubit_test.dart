import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:frontend/features/notes/domain/entities/note.dart';
import 'package:frontend/features/notes/domain/repos/notes_repo.dart';
import 'package:frontend/features/notes/presentation/cubits/notes_cubit.dart';

class MockNotesRepo extends Mock implements NotesRepo {}

void main() {
  late MockNotesRepo notesRepo;

  Note buildNote({
    String id = 'n1',
    String title = 'Lecture recap',
    String content = 'Body text',
    bool isPublic = false,
    String? summary,
  }) {
    final now = DateTime(2026, 1, 1);
    return Note(
      id: id,
      title: title,
      content: content,
      tags: const [],
      isPublic: isPublic,
      createdAt: now,
      updatedAt: now,
      authorId: 'author-1',
      authorName: 'Ada',
      summary: summary,
    );
  }

  setUp(() {
    notesRepo = MockNotesRepo();
  });

  NotesCubit buildCubit() => NotesCubit(notesRepo: notesRepo);

  group('NotesCubit.loadNotes', () {
    blocTest<NotesCubit, NotesState>(
      'emits [loading, loaded] with the notes from the repo',
      setUp: () {
        when(
          () => notesRepo.getMyNotes(search: null, hasSummary: null, limit: null),
        ).thenAnswer((_) async => [buildNote()]);
      },
      build: buildCubit,
      act: (cubit) => cubit.loadNotes(),
      expect: () => [const NotesLoading(), NotesLoaded([buildNote()])],
    );

    blocTest<NotesCubit, NotesState>(
      'emits [loading, error] with a clean message when the repo throws',
      setUp: () {
        when(
          () => notesRepo.getMyNotes(search: any(named: 'search'), hasSummary: any(named: 'hasSummary'), limit: any(named: 'limit')),
        ).thenThrow(Exception('Network error'));
      },
      build: buildCubit,
      act: (cubit) => cubit.loadNotes(search: 'lecture'),
      expect: () => [const NotesLoading(), const NotesError('Network error')],
    );
  });

  group('NotesCubit.createNote', () {
    blocTest<NotesCubit, NotesState>(
      'emits [saving, saved] with the created note',
      setUp: () {
        when(
          () => notesRepo.createNote(
            title: 'New note',
            content: 'Some content',
            tags: const [],
            isPublic: false,
            summary: null,
          ),
        ).thenAnswer((_) async => buildNote(title: 'New note'));
      },
      build: buildCubit,
      act: (cubit) =>
          cubit.createNote(title: 'New note', content: 'Some content'),
      expect: () => [
        const NoteSaving(),
        NoteSaved(buildNote(title: 'New note')),
      ],
    );
  });

  group('NotesCubit.deleteNote', () {
    blocTest<NotesCubit, NotesState>(
      'emits [saving, deleted] and calls the repo with the note id',
      setUp: () {
        when(() => notesRepo.deleteNote('n1')).thenAnswer((_) async {});
      },
      build: buildCubit,
      act: (cubit) => cubit.deleteNote('n1'),
      expect: () => [const NoteSaving(), const NoteDeleted('n1')],
      verify: (_) {
        verify(() => notesRepo.deleteNote('n1')).called(1);
      },
    );
  });

  group('NotesCubit.toggleVisibility', () {
    blocTest<NotesCubit, NotesState>(
      'emits [saving, saved] with the note flipped to public',
      setUp: () {
        when(
          () => notesRepo.toggleVisibility('n1'),
        ).thenAnswer((_) async => buildNote(isPublic: true));
      },
      build: buildCubit,
      act: (cubit) => cubit.toggleVisibility('n1'),
      expect: () => [const NoteSaving(), NoteSaved(buildNote(isPublic: true))],
    );
  });

  group('NotesCubit.summarizeNote', () {
    blocTest<NotesCubit, NotesState>(
      'emits [summarizing, summarized] with the AI summary attached',
      setUp: () {
        when(
          () => notesRepo.requestSummary('n1'),
        ).thenAnswer((_) async => buildNote(summary: 'A short recap.'));
      },
      build: buildCubit,
      act: (cubit) => cubit.summarizeNote(buildNote()),
      expect: () => [
        const NoteSummarizing(),
        NoteSummarized(buildNote(summary: 'A short recap.')),
      ],
    );

    blocTest<NotesCubit, NotesState>(
      'emits [summarizing, error] when summary generation fails',
      setUp: () {
        when(
          () => notesRepo.requestSummary('n1'),
        ).thenThrow(Exception('Summarization timed out'));
      },
      build: buildCubit,
      act: (cubit) => cubit.summarizeNote(buildNote()),
      expect: () => [
        const NoteSummarizing(),
        const NotesError('Summarization timed out'),
      ],
    );
  });
}
