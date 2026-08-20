import 'package:equatable/equatable.dart';

class AppUser extends Equatable {
  final String id;
  final String name;
  final String email;
  final String? role;
  final String? avatarUrl;
  final DateTime? createdAt;

  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    this.role,
    this.avatarUrl,
    this.createdAt,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      role: json['role'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
    );
  }

  AppUser copyWith({String? avatarUrl, bool clearAvatarUrl = false}) {
    return AppUser(
      id: id,
      name: name,
      email: email,
      role: role,
      avatarUrl: clearAvatarUrl ? null : (avatarUrl ?? this.avatarUrl),
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    if (role != null) 'role': role,
    if (avatarUrl != null) 'avatarUrl': avatarUrl,
    if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
  };

  @override
  List<Object?> get props => [id, name, email, role, avatarUrl, createdAt];
}
