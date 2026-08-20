import 'package:flutter/material.dart';
import 'package:frontend/core/constants/app_spacing.dart';
import 'package:frontend/core/constants/app_typography.dart';
import 'package:frontend/core/network/api_config.dart';

class UserAvatar extends StatelessWidget {
  final String name;
  final double size;
  // Relative backend path (e.g. `/uploads/avatars/xyz.jpg`) as returned by
  // the API — resolved against ApiConfig.baseUrl. Falls back to initials
  // when null or the image fails to load.
  final String? imageUrl;

  const UserAvatar({
    super.key,
    required this.name,
    this.size = AppSpacing.avatarLg,
    this.imageUrl,
  });

  static const List<Color> _palette = [
    Color(0xFF7B5CF5),
    Color(0xFF06B6D4),
    Color(0xFFF59E0B),
    Color(0xFF22C55E),
    Color(0xFFEF4444),
    Color(0xFF3B82F6),
  ];

  static String _initialsOf(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts[1].substring(0, 1))
        .toUpperCase();
  }

  static Color _colorOf(String seed) {
    final hash = seed.codeUnits.fold<int>(0, (acc, c) => acc + c);
    return _palette[hash % _palette.length];
  }

  Widget _buildInitials(BuildContext context) {
    final color = _colorOf(name);
    return Container(
      width: size,
      height: size,
      alignment: .center,
      decoration: BoxDecoration(shape: .circle, color: color),
      child: Text(
        _initialsOf(name),
        style: AppTypography.of(
          context,
        ).titleMedium.copyWith(color: Colors.white, fontSize: size * 0.36),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    if (url == null || url.isEmpty) {
      return _buildInitials(context);
    }

    return ClipOval(
      child: Image.network(
        '${ApiConfig.baseUrl}$url',
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildInitials(context),
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return _buildInitials(context);
        },
      ),
    );
  }
}
