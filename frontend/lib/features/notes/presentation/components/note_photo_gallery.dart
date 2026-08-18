import 'package:flutter/material.dart';
import 'package:frontend/core/constants/app_colors.dart';
import 'package:frontend/core/constants/app_spacing.dart';
import 'package:frontend/core/network/api_config.dart';
import 'package:frontend/features/notes/domain/entities/note_photo.dart';
import 'package:frontend/features/notes/presentation/components/note_photo_add_tile.dart';

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
        insetPadding: const .all(AppSpacing.lg),
        child: Stack(
          alignment: .topRight,
          children: [
            ClipRRect(
              borderRadius: .circular(AppSpacing.radiusLg),
              child: Image.network(
                '${ApiConfig.baseUrl}${photo.url}',
                fit: .contain,
              ),
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
    final colors = AppColors.of(context);

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
          return NotePhotoAddTile(onTap: isBusy ? null : onAdd, isBusy: isBusy);
        }

        final photo = photos[index];
        return ClipRRect(
          borderRadius: .circular(AppSpacing.radiusMd),
          child: Stack(
            fit: .expand,
            children: [
              GestureDetector(
                onTap: () => _openFullScreen(context, photo),
                child: Image.network(
                  '${ApiConfig.baseUrl}${photo.url}',
                  fit: .cover,
                  errorBuilder: (context, error, stackTrace) => ColoredBox(
                    color: colors.backgroundCard,
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: colors.textTertiary,
                    ),
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
