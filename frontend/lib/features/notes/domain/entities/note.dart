import 'package:equatable/equatable.dart';

import 'note_photo.dart';

class Note extends Equatable {
  final String id;
  final String title;
  final String content;
  final List<String> tags;
  final bool isPublic;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String authorId;
  final String authorName;
  final List<NotePhoto> photos;

  final String? summary;

  const Note({
    required this.id,
    required this.title,
    required this.content,
    required this.tags,
    required this.isPublic,
    required this.createdAt,
    required this.updatedAt,
    required this.authorId,
    required this.authorName,
    this.photos = const [],
    this.summary,
  });

  factory Note.fromJson(Map<String, dynamic> json) {
    final author = json['author'] as Map<String, dynamic>?;
    return Note(
      id: json['id'] as String,
      title: json['title'] as String,
      content: json['content'] as String,
      tags: ((json['tags'] as List<dynamic>?) ?? [])
          .map((e) => e.toString())
          .toList(),
      isPublic: json['isPublic'] as bool? ?? false,
      summary: json['summary'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      authorId: author?['id'] as String? ?? '',
      authorName: author?['name'] as String? ?? '',
      photos: ((json['photos'] as List<dynamic>?) ?? [])
          .map((p) => NotePhoto.fromJson(p as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'content': content,
    'tags': tags,
    'isPublic': isPublic,
    'summary': summary,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'author': {'id': authorId, 'name': authorName},
    'photos': photos.map((p) => p.toJson()).toList(),
  };

  Note copyWith({
    String? title,
    String? content,
    List<String>? tags,
    bool? isPublic,
    DateTime? updatedAt,
    List<NotePhoto>? photos,
    String? summary,
  }) {
    return Note(
      id: id,
      title: title ?? this.title,
      content: content ?? this.content,
      tags: tags ?? this.tags,
      isPublic: isPublic ?? this.isPublic,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      authorId: authorId,
      authorName: authorName,
      photos: photos ?? this.photos,
      summary: summary ?? this.summary,
    );
  }

  @override
  List<Object?> get props => [
    id,
    title,
    content,
    tags,
    isPublic,
    createdAt,
    updatedAt,
    authorId,
    authorName,
    photos,
    summary,
  ];
}
