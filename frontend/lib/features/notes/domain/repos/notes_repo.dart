import '../entities/note.dart';

abstract class NotesRepo {
  Future<List<Note>> getMyNotes({String? search});
  Future<Note> getNoteById(String id);
  Future<Note> createNote({
    required String title,
    required String content,
    List<String> tags = const [],
    bool isPublic = false,
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
  Future<Note> uploadPhotos(String noteId, List<String> imagePaths);
  Future<Note> deletePhoto(String noteId, String photoId);
}
