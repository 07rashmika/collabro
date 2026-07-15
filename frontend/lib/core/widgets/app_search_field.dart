import 'package:flutter/material.dart';
import 'package:frontend/core/constants/app_colors.dart';
import 'package:frontend/core/constants/app_spacing.dart';
import 'package:frontend/core/constants/app_typography.dart';

/// Shared search input — a leading search icon, no label, pill-ish rounded
/// border matching the rest of the input styling in this app.
class AppSearchField extends StatelessWidget {
  final String hint;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onTap;

  const AppSearchField({
    super.key,
    required this.hint,
    this.controller,
    this.onChanged,
    this.onSubmitted,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final typography = AppTypography.of(context);
    return TextField(
      controller: controller,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      onTap: onTap,
      textInputAction: onSubmitted != null ? TextInputAction.search : TextInputAction.done,
      style: typography.bodyMedium.copyWith(color: colors.textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: typography.bodyMedium.copyWith(color: colors.textHint),
        prefixIcon: Icon(Icons.search, color: colors.textTertiary),
        filled: true,
        fillColor: colors.backgroundInput,
        contentPadding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          borderSide: BorderSide(color: colors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          borderSide: BorderSide(color: colors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          borderSide: BorderSide(color: colors.primary),
        ),
      ),
    );
  }
}
