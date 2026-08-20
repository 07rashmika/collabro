import '../entities/note.dart';

abstract class NotesRepo {
  Future<List<Note>> getMyNotes({String? search, bool? hasSummary, int? limit});

  Future<List<Note>> getPublicNotes({
    String? search,
    String? tag,
    List<String>? authorIds,
    bool? hasSummary,
  });
  Future<Note> getNoteById(String id);

  Future<List<Note>> getNotesByUser(String userId);

  Future<String> summarizeText(String content);

  Future<Note> createNote({
    required String title,
    required String content,
    List<String> tags = const [],
    bool isPublic = false,
    String? summary,
  });
  Future<Note> updateNote(
    String id, {
    String? title,
    String? content,
    List<String>? tags,
    bool? isPublic,
  });
  Future<void> deleteNote(String id);
  Future<Note> toggleVisibility(String id);
  Future<Note> requestSummary(String id);
  Future<Note> uploadPhotos(String noteId, List<String> imagePaths);
  Future<Note> deletePhoto(String noteId, String photoId);
}
