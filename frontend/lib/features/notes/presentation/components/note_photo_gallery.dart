import 'package:flutter/material.dart';

import 'package:frontend/core/constants/app_colors.dart';
import 'package:frontend/core/constants/app_spacing.dart';
import 'package:frontend/core/network/api_config.dart';
import 'package:frontend/features/notes/domain/entities/note_photo.dart';

/// Grid of a note's attached photos. In editable mode each thumbnail gets a
/// delete overlay and a trailing "add" tile is appended; in read-only mode
/// (note detail) tapping a thumbnail opens it full-screen instead.
class NotePhotoGallery extends StatelessWidget {
  final List<NotePhoto> photos;
  final bool editable;
  final bool isBusy;
  final VoidCallback? onAdd;
  final ValueChanged<NotePhoto>? onDelete;

  const NotePhotoGallery({
    super.key,
    required this.photos,
    this.editable = false,
    this.isBusy = false,
    this.onAdd,
    this.onDelete,
  });

  void _openFullScreen(BuildContext context, NotePhoto photo) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(AppSpacing.lg),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              child: Image.network('${ApiConfig.baseUrl}${photo.url}', fit: BoxFit.contain),
            ),
            IconButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              icon: const Icon(Icons.close, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (photos.isEmpty && !editable) return const SizedBox.shrink();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: photos.length + (editable ? 1 : 0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: AppSpacing.sm,
        mainAxisSpacing: AppSpacing.sm,
      ),
      itemBuilder: (context, index) {
        if (editable && index == photos.length) {
          return _AddTile(onTap: isBusy ? null : onAdd, isBusy: isBusy);
        }

        final photo = photos[index];
        return ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          child: Stack(
            fit: StackFit.expand,
            children: [
              GestureDetector(
                onTap: () => _openFullScreen(context, photo),
                child: Image.network(
                  '${ApiConfig.baseUrl}${photo.url}',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const ColoredBox(
                    color: AppColors.backgroundCard,
                    child: Icon(Icons.broken_image_outlined, color: AppColors.textTertiary),
                  ),
                ),
              ),
              if (editable)
                Positioned(
                  top: 4,
                  right: 4,
                  child: GestureDetector(
                    onTap: isBusy ? null : () => onDelete?.call(photo),
                    child: const CircleAvatar(
                      radius: 12,
                      backgroundColor: Colors.black87,
                      child: Icon(Icons.close, size: 14, color: Colors.white),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _AddTile extends StatelessWidget {
  final VoidCallback? onTap;
  final bool isBusy;

  const _AddTile({required this.onTap, required this.isBusy});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.backgroundCard,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(color: AppColors.border),
        ),
        child: Center(
          child: isBusy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                )
              : const Icon(Icons.add_photo_alternate_outlined, color: AppColors.textSecondary),
        ),
      ),
    );
  }
}
