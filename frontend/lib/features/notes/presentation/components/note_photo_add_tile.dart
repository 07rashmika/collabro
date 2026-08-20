import 'package:flutter/material.dart';
import 'package:frontend/core/constants/app_colors.dart';
import 'package:frontend/core/constants/app_spacing.dart';

class NotePhotoAddTile extends StatelessWidget {
  final VoidCallback? onTap;
  final bool isBusy;

  const NotePhotoAddTile({
    super.key,
    required this.onTap,
    required this.isBusy,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: .circular(AppSpacing.radiusMd),
      child: Container(
        decoration: BoxDecoration(
          color: colors.backgroundCard,
          borderRadius: .circular(AppSpacing.radiusMd),
          border: .all(color: colors.border),
        ),
        child: Center(
          child: isBusy
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colors.primary,
                  ),
                )
              : Icon(
                  Icons.add_photo_alternate_outlined,
                  color: colors.textSecondary,
                ),
        ),
      ),
    );
  }
}
