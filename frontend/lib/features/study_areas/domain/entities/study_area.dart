import 'package:equatable/equatable.dart';

class StudyArea extends Equatable {
  final String id;
  final String name;

  const StudyArea({required this.id, required this.name});

  factory StudyArea.fromJson(Map<String, dynamic> json) {
    return StudyArea(id: json['id'] as String, name: json['name'] as String);
  }

  @override
  List<Object?> get props => [id, name];
}
