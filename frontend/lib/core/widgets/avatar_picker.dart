import 'package:flutter/material.dart';
import 'package:frontend/core/constants/app_colors.dart';
import 'package:frontend/core/constants/app_spacing.dart';
import 'package:frontend/core/widgets/user_avatar.dart';

/// A [UserAvatar] with a tap-to-change camera badge, used wherever the
/// signed-in user can pick/replace their own profile photo.
class AvatarPicker extends StatelessWidget {
  final String name;
  final String? imageUrl;
  final bool isUploading;
  final VoidCallback onTap;
  final double size;

  const AvatarPicker({
    super.key,
    required this.name,
    required this.onTap,
    this.imageUrl,
    this.isUploading = false,
    this.size = AppSpacing.avatarXxl,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return GestureDetector(
      onTap: isUploading ? null : onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          UserAvatar(name: name, imageUrl: imageUrl, size: size),
          if (isUploading)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.overlay,
                ),
                child: const Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.primary,
                border: Border.all(color: colors.backgroundDark, width: 2),
              ),
              child: const Icon(
                Icons.camera_alt,
                size: 14,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
