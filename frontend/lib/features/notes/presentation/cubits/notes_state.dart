part of 'notes_cubit.dart';

sealed class NotesState extends Equatable {
  const NotesState();

  @override
  List<Object?> get props => [];
}

final class NotesInitial extends NotesState {
  const NotesInitial();
}

final class NotesLoading extends NotesState {
  const NotesLoading();
}

final class NotesLoaded extends NotesState {
  final List<Note> notes;
  const NotesLoaded(this.notes);

  @override
  List<Object?> get props => [notes];
}

final class NoteSaving extends NotesState {
  const NoteSaving();
}

final class NoteSaved extends NotesState {
  final Note note;
  const NoteSaved(this.note);

  @override
  List<Object?> get props => [note];
}

final class NoteDeleted extends NotesState {
  final String noteId;
  const NoteDeleted(this.noteId);

  @override
  List<Object?> get props => [noteId];
}

final class NoteSummarizing extends NotesState {
  const NoteSummarizing();
}

final class NoteSummarized extends NotesState {
  final Note note;
  const NoteSummarized(this.note);

  @override
  List<Object?> get props => [note];
}

final class NotesError extends NotesState {
  final String message;
  const NotesError(this.message);

  @override
  List<Object?> get props => [message];
}

final class NotePhotosUpdating extends NotesState {
  const NotePhotosUpdating();
}

final class NotePhotosUpdated extends NotesState {
  final Note note;
  const NotePhotosUpdated(this.note);

  @override
  List<Object?> get props => [note];
}
