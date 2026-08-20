import 'package:flutter/material.dart';
import 'package:frontend/core/constants/app_colors.dart';
import 'package:frontend/core/constants/app_spacing.dart';
import 'package:frontend/core/constants/app_typography.dart';

class AppTextField extends StatefulWidget {
  final String label;
  final String hint;
  final IconData icon;
  final TextEditingController controller;
  final bool obscurable;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;
  final TextInputAction textInputAction;
  final int maxLines;

  const AppTextField({
    super.key,
    required this.label,
    required this.hint,
    required this.icon,
    required this.controller,
    this.obscurable = false,
    this.keyboardType = .text,
    this.validator,
    this.textInputAction = .next,
    this.maxLines = 1,
  });

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  bool _obscured = true;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final typography = AppTypography.of(context);
    return Column(
      crossAxisAlignment: .start,
      children: [
        Text(widget.label, style: typography.labelMedium),
        const SizedBox(height: AppSpacing.sm),
        TextFormField(
          controller: widget.controller,
          obscureText: widget.obscurable && _obscured,
          keyboardType: widget.maxLines > 1 && widget.keyboardType == .text
              ? .multiline
              : widget.keyboardType,
          textInputAction: widget.textInputAction,
          validator: widget.validator,
          maxLines: widget.obscurable ? 1 : widget.maxLines,
          minLines: widget.maxLines > 1 ? widget.maxLines : null,
          style: typography.bodyLarge.copyWith(color: colors.textPrimary),
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle: typography.bodyLarge.copyWith(color: colors.textHint),
            filled: true,
            fillColor: colors.backgroundInput,
            prefixIcon: widget.maxLines > 1
                ? null
                : Icon(
                    widget.icon,
                    size: AppSpacing.iconMd,
                    color: colors.textTertiary,
                  ),
            suffixIcon: widget.obscurable
                ? IconButton(
                    icon: Icon(
                      _obscured
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: AppSpacing.iconMd,
                      color: colors.textTertiary,
                    ),
                    onPressed: () => setState(() => _obscured = !_obscured),
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: .circular(AppSpacing.radiusMd),
              borderSide: BorderSide(color: colors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: .circular(AppSpacing.radiusMd),
              borderSide: BorderSide(color: colors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: .circular(AppSpacing.radiusMd),
              borderSide: BorderSide(color: colors.primary),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: .circular(AppSpacing.radiusMd),
              borderSide: BorderSide(color: colors.error),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: .circular(AppSpacing.radiusMd),
              borderSide: BorderSide(color: colors.error),
            ),
            contentPadding: const .symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
          ),
        ),
      ],
    );
  }
}
