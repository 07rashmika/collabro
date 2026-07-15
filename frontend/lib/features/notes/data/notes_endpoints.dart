abstract class NotesEndpoints {
  static const String myNotes = '/notes/me';
  static const String base = '/notes';
  static const String public = '/notes/public';

  static String byId(String id) => '/notes/$id';
  static String visibility(String id) => '/notes/$id/visibility';
  static String photos(String id) => '/notes/$id/photos';
  static String photo(String id, String photoId) => '/notes/$id/photos/$photoId';
}
