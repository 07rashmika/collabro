import 'package:equatable/equatable.dart';

class NotePhoto extends Equatable {
  final String id;
  final String url;
  final DateTime createdAt;

  const NotePhoto({required this.id, required this.url, required this.createdAt});

  factory NotePhoto.fromJson(Map<String, dynamic> json) {
    return NotePhoto(
      id: json['id'] as String,
      url: json['url'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'url': url,
    'createdAt': createdAt.toIso8601String(),
  };

  @override
  List<Object?> get props => [id, url, createdAt];
}
