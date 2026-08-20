import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/note.dart';
import '../../domain/repos/notes_repo.dart';

part 'notes_state.dart';

class NotesCubit extends Cubit<NotesState> {
  final NotesRepo notesRepo;

  NotesCubit({required this.notesRepo}) : super(const NotesInitial());

  Future<void> loadNotes({String? search, bool? hasSummary, int? limit}) async {
    emit(const NotesLoading());
    try {
      final notes = await notesRepo.getMyNotes(
        search: search,
        hasSummary: hasSummary,
        limit: limit,
      );
      emit(NotesLoaded(notes));
    } catch (e) {
      emit(NotesError(e.toString().replaceFirst('Exception: ', '')));
    }
  }

  Future<void> loadHomeSummaries({
    required List<String> matchedAuthorIds,
    int limit = 3,
  }) async {
    emit(const NotesLoading());
    try {
      final results = await Future.wait([
        notesRepo.getMyNotes(hasSummary: true, limit: limit),
        matchedAuthorIds.isEmpty
            ? Future.value(const <Note>[])
            : notesRepo.getPublicNotes(
                authorIds: matchedAuthorIds,
                hasSummary: true,
              ),
      ]);
      final merged = [...results[0], ...results[1]]
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      emit(NotesLoaded(merged.take(limit).toList()));
    } catch (e) {
      emit(NotesError(e.toString().replaceFirst('Exception: ', '')));
    }
  }

  Future<void> createNote({
    required String title,
    required String content,
    List<String> tags = const [],
    bool isPublic = false,
    String? summary,
  }) async {
    emit(const NoteSaving());
    try {
      final note = await notesRepo.createNote(
        title: title,
        content: content,
        tags: tags,
        isPublic: isPublic,
        summary: summary,
      );
      emit(NoteSaved(note));
    } catch (e) {
      emit(NotesError(e.toString().replaceFirst('Exception: ', '')));
    }
  }

  Future<void> summarizeAndSaveDraft({
    String? existingNoteId,
    required String title,
    required String content,
    List<String> tags = const [],
  }) async {
    emit(const DraftSummarizing());
    try {
      final Note note;
      if (existingNoteId == null) {
        final summary = await notesRepo.summarizeText(content);
        note = await notesRepo.createNote(
          title: title,
          content: content,
          tags: tags,
          isPublic: false,
          summary: summary,
        );
      } else {
        await notesRepo.updateNote(
          existingNoteId,
          title: title,
          content: content,
          tags: tags,
        );
        note = await notesRepo.requestSummary(existingNoteId);
      }
      emit(DraftSaved(note));
    } catch (e) {
      emit(NotesError(e.toString().replaceFirst('Exception: ', '')));
    }
  }

  Future<void> updateNote(
    String id, {
    String? title,
    String? content,
    List<String>? tags,
    bool? isPublic,
  }) async {
    emit(const NoteSaving());
    try {
      final note = await notesRepo.updateNote(
        id,
        title: title,
        content: content,
        tags: tags,
        isPublic: isPublic,
      );
      emit(NoteSaved(note));
    } catch (e) {
      emit(NotesError(e.toString().replaceFirst('Exception: ', '')));
    }
  }

  Future<void> deleteNote(String id) async {
    emit(const NoteSaving());
    try {
      await notesRepo.deleteNote(id);
      emit(NoteDeleted(id));
    } catch (e) {
      emit(NotesError(e.toString().replaceFirst('Exception: ', '')));
    }
  }

  Future<void> toggleVisibility(String id) async {
    emit(const NoteSaving());
    try {
      final note = await notesRepo.toggleVisibility(id);
      emit(NoteSaved(note));
    } catch (e) {
      emit(NotesError(e.toString().replaceFirst('Exception: ', '')));
    }
  }

  Future<void> summarizeNote(Note note) async {
    emit(const NoteSummarizing());
    try {
      final summarized = await notesRepo.requestSummary(note.id);
      emit(NoteSummarized(summarized));
    } catch (e) {
      emit(NotesError(e.toString().replaceFirst('Exception: ', '')));
    }
  }

  Future<void> uploadPhotos(String noteId, List<String> imagePaths) async {
    emit(const NotePhotosUpdating());
    try {
      final note = await notesRepo.uploadPhotos(noteId, imagePaths);
      emit(NotePhotosUpdated(note));
    } catch (e) {
      emit(NotesError(e.toString().replaceFirst('Exception: ', '')));
    }
  }

  Future<void> deletePhoto(String noteId, String photoId) async {
    emit(const NotePhotosUpdating());
    try {
      final note = await notesRepo.deletePhoto(noteId, photoId);
      emit(NotePhotosUpdated(note));
    } catch (e) {
      emit(NotesError(e.toString().replaceFirst('Exception: ', '')));
    }
  }
}
