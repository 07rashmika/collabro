import 'dart:async';

import 'package:flutter/material.dart';
import 'package:frontend/core/constants/app_colors.dart';
import 'package:frontend/core/constants/app_spacing.dart';
import 'package:frontend/core/constants/app_typography.dart';

/// Type-to-add picker: as the user types, matching [suggestions] appear
/// below the field; tapping one selects it. Submitting text that doesn't
/// match anything calls [onCreateNew] instead — so the list isn't a fixed,
/// pre-baked catalog the user is stuck choosing from.
///
/// [onQueryChanged], if given, fires debounced (300ms after typing pauses)
/// so a caller can fetch live [remoteSuggestions] from an external catalog
/// (e.g. a skills search API) — those render as an extra row below the
/// local matches and, since they aren't in [suggestions] yet, always go
/// through [onCreateNew] when tapped.
class TypeaheadChipPicker<T> extends StatefulWidget {
  final String label;
  final String hint;
  final List<T> suggestions;
  final String Function(T) labelOf;
  final void Function(T) onSelectExisting;
  final void Function(String) onCreateNew;
  final List<Widget> selectedChips;
  final bool isBusy;
  final ValueChanged<String>? onQueryChanged;
  final List<String> remoteSuggestions;
  final bool remoteBusy;

  const TypeaheadChipPicker({
    super.key,
    required this.label,
    required this.hint,
    required this.suggestions,
    required this.labelOf,
    required this.onSelectExisting,
    required this.onCreateNew,
    this.selectedChips = const [],
    this.isBusy = false,
    this.onQueryChanged,
    this.remoteSuggestions = const [],
    this.remoteBusy = false,
  });

  @override
  State<TypeaheadChipPicker<T>> createState() => _TypeaheadChipPickerState<T>();
}

class _TypeaheadChipPickerState<T> extends State<TypeaheadChipPicker<T>> {
  final _controller = TextEditingController();
  String _query = '';
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  List<T> get _matches {
    if (_query.isEmpty) return const [];
    final q = _query.toLowerCase();
    return widget.suggestions
        .where((s) => widget.labelOf(s).toLowerCase().contains(q))
        .take(6)
        .toList();
  }

  /// Remote results not already covered by a local match, so the same name
  /// doesn't appear twice.
  List<String> get _remoteOnly {
    final localNames = _matches
        .map((s) => widget.labelOf(s).toLowerCase())
        .toSet();
    return widget.remoteSuggestions
        .where((name) => !localNames.contains(name.toLowerCase()))
        .toList();
  }

  void _onChanged(String value) {
    setState(() => _query = value);
    final onQueryChanged = widget.onQueryChanged;
    if (onQueryChanged == null) return;
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 300),
      () => onQueryChanged(value),
    );
  }

  void _selectExisting(T item) {
    widget.onSelectExisting(item);
    _clear();
  }

  void _selectRemote(String name) {
    widget.onCreateNew(name);
    _clear();
  }

  void _clear() {
    _controller.clear();
    _debounce?.cancel();
    widget.onQueryChanged?.call('');
    setState(() => _query = '');
  }

  void _submit() {
    final value = _controller.text.trim();
    if (value.isEmpty) return;

    T? exactMatch;
    for (final s in widget.suggestions) {
      if (widget.labelOf(s).toLowerCase() == value.toLowerCase()) {
        exactMatch = s;
        break;
      }
    }

    if (exactMatch != null) {
      _selectExisting(exactMatch);
    } else {
      widget.onCreateNew(value);
      _clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final typography = AppTypography.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: typography.labelLarge),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: _controller,
          enabled: !widget.isBusy,
          style: typography.bodyLarge.copyWith(color: colors.textPrimary),
          textInputAction: TextInputAction.done,
          onChanged: _onChanged,
          onSubmitted: (_) => _submit(),
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle: typography.bodyLarge.copyWith(
              color: colors.textHint,
            ),
            filled: true,
            fillColor: colors.backgroundInput,
            suffixIcon: widget.isBusy
                ? Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colors.primary,
                      ),
                    ),
                  )
                : IconButton(
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
        if (_matches.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: _matches.map((item) {
              return ActionChip(
                label: Text(
                  widget.labelOf(item),
                  style: typography.labelSmall,
                ),
                backgroundColor: colors.backgroundElevated,
                side: BorderSide(color: colors.chipBorder),
                onPressed: () => _selectExisting(item),
              );
            }).toList(),
          ),
        ] else if (_query.isNotEmpty &&
            _remoteOnly.isEmpty &&
            !widget.remoteBusy) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Press enter to add "$_query" as new',
            style: typography.caption,
          ),
        ],
        if (widget.remoteBusy) ...[
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: colors.primary,
            ),
          ),
        ] else if (_remoteOnly.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: _remoteOnly.map((name) {
              return ActionChip(
                label: Text(name, style: typography.labelSmall),
                avatar: Icon(
                  Icons.travel_explore,
                  size: 14,
                  color: colors.primaryLight,
                ),
                backgroundColor: colors.backgroundElevated,
                side: BorderSide(color: colors.chipBorder),
                onPressed: () => _selectRemote(name),
              );
            }).toList(),
          ),
        ],
        if (widget.selectedChips.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: widget.selectedChips,
          ),
        ],
      ],
    );
  }
}
