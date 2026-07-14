import 'package:equatable/equatable.dart';

class Skill extends Equatable {
  final String id;
  final String name;
  final String category;

  const Skill({required this.id, required this.name, required this.category});

  factory Skill.fromJson(Map<String, dynamic> json) {
    return Skill(
      id: json['id'] as String,
      name: json['name'] as String,
      category: json['category'] as String,
    );
  }

  @override
  List<Object?> get props => [id, name, category];
}
