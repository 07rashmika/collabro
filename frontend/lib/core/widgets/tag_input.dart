import 'package:flutter/material.dart';
import 'package:frontend/core/constants/app_colors.dart';
import 'package:frontend/core/constants/app_spacing.dart';
import 'package:frontend/core/constants/app_typography.dart';

/// Free-text tag entry: a submit-on-enter text field that appends to
/// [tags], rendered below as removable chips. Used for open-ended lists
/// like interests where there's no catalog to pick from.
class TagInput extends StatefulWidget {
  final String label;
  final String hint;
  final List<String> tags;
  final ValueChanged<String> onAdd;
  final ValueChanged<String> onRemove;
  final int? maxTags;

  const TagInput({
    super.key,
    required this.label,
    required this.hint,
    required this.tags,
    required this.onAdd,
    required this.onRemove,
    this.maxTags,
  });

  @override
  State<TagInput> createState() => _TagInputState();
}

class _TagInputState extends State<TagInput> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text.trim();
    if (value.isEmpty) return;
    if (widget.maxTags != null && widget.tags.length >= widget.maxTags!) return;
    if (widget.tags.any((t) => t.toLowerCase() == value.toLowerCase())) {
      _controller.clear();
      return;
    }
    widget.onAdd(value);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final typography = AppTypography.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: typography.labelMedium),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: _controller,
          style: typography.bodyLarge.copyWith(color: colors.textPrimary),
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle: typography.bodyLarge.copyWith(color: colors.textHint),
            filled: true,
            fillColor: colors.backgroundInput,
            suffixIcon: IconButton(
              icon: Icon(Icons.add, color: colors.primary),
              onPressed: _submit,
            ),
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
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
          ),
        ),
        if (widget.tags.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: widget.tags
                .map(
                  (tag) => Container(
                    padding: const EdgeInsets.only(
                      left: AppSpacing.md,
                      right: AppSpacing.xs,
                      top: 4,
                      bottom: 4,
                    ),
                    decoration: BoxDecoration(
                      color: colors.chipBackground,
                      border: Border.all(color: colors.chipBorder),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(tag, style: typography.labelSmall),
                        InkWell(
                          onTap: () => widget.onRemove(tag),
                          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                          child: Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(Icons.close, size: 14, color: colors.textTertiary),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ],
    );
  }
}
