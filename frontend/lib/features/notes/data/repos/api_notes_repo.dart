import 'package:dio/dio.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';
import '../../domain/entities/note.dart';
import '../../domain/repos/notes_repo.dart';
import '../notes_endpoints.dart';

class ApiNotesRepo implements NotesRepo {
  final ApiClient apiClient;

  ApiNotesRepo({required this.apiClient});

  @override
  Future<List<Note>> getMyNotes({String? search}) async {
    try {
      final response = await apiClient.get(
        NotesEndpoints.myNotes,
        query: {if (search != null && search.isNotEmpty) 'search': search},
      );
      final notes = (response.data['notes'] as List<dynamic>?) ?? [];
      return notes.map((n) => Note.fromJson(n as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    } catch (e) {
      throw Exception('Fetching notes failed: $e');
    }
  }

  @override
  Future<Note> getNoteById(String id) async {
    try {
      final response = await apiClient.get(NotesEndpoints.byId(id));
      return Note.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    } catch (e) {
      throw Exception('Fetching note failed: $e');
    }
  }

  @override
  Future<Note> createNote({
    required String title,
    required String content,
    List<String> tags = const [],
    bool isPublic = false,
  }) async {
    try {
      final response = await apiClient.post(
        NotesEndpoints.base,
        data: {
          'title': title,
          'content': content,
          'tags': tags,
          'isPublic': isPublic,
        },
      );
      return Note.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    } catch (e) {
      throw Exception('Creating note failed: $e');
    }
  }

  @override
  Future<Note> updateNote(
    String id, {
    String? title,
    String? content,
    List<String>? tags,
    bool? isPublic,
  }) async {
    try {
      final response = await apiClient.patch(
        NotesEndpoints.byId(id),
        data: {
          if (title != null) 'title': title,
          if (content != null) 'content': content,
          if (tags != null) 'tags': tags,
          if (isPublic != null) 'isPublic': isPublic,
        },
      );
      return Note.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    } catch (e) {
      throw Exception('Updating note failed: $e');
    }
  }

  @override
  Future<void> deleteNote(String id) async {
    try {
      await apiClient.delete(NotesEndpoints.byId(id));
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    } catch (e) {
      throw Exception('Deleting note failed: $e');
    }
  }

  @override
  Future<Note> toggleVisibility(String id) async {
    try {
      final response = await apiClient.patch(NotesEndpoints.visibility(id));
      return Note.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    } catch (e) {
      throw Exception('Updating visibility failed: $e');
    }
  }

  @override
  Future<Note> uploadPhotos(String noteId, List<String> imagePaths) async {
    try {
      final formData = FormData.fromMap({
        'photos': [
          for (final path in imagePaths) await MultipartFile.fromFile(path),
        ],
      });
      final response = await apiClient.post(NotesEndpoints.photos(noteId), data: formData);
      return Note.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    } catch (e) {
      throw Exception('Uploading photos failed: $e');
    }
  }

  @override
  Future<Note> deletePhoto(String noteId, String photoId) async {
    try {
      final response = await apiClient.delete(NotesEndpoints.photo(noteId, photoId));
      return Note.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    } catch (e) {
      throw Exception('Deleting photo failed: $e');
    }
  }
}
