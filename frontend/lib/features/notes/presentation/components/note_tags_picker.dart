import 'package:flutter/material.dart';
import 'package:frontend/core/widgets/selectable_chip.dart';
import 'package:frontend/core/widgets/typeahead_chip_picker.dart';
import 'package:frontend/features/skills/domain/entities/skill.dart';

class NoteTagsPicker extends StatelessWidget {
  final List<Skill> allSkills;
  final List<Skill> selectedTags;
  final bool isBusy;
  final ValueChanged<Skill> onSelectExisting;
  final ValueChanged<Skill> onRemoveTag;
  final Future<void> Function(String name) onCreateNew;

  const NoteTagsPicker({
    super.key,
    required this.allSkills,
    required this.selectedTags,
    required this.isBusy,
    required this.onSelectExisting,
    required this.onRemoveTag,
    required this.onCreateNew,
  });

  @override
  Widget build(BuildContext context) {
    return TypeaheadChipPicker<Skill>(
      label: 'Tags',
      hint: 'e.g. Python, Organic Chemistry',
      suggestions: allSkills
          .where(
            (s) => !selectedTags.any(
              (t) => t.name.toLowerCase() == s.name.toLowerCase(),
            ),
          )
          .toList(),
      labelOf: (s) => s.name,
      onSelectExisting: onSelectExisting,
      onCreateNew: onCreateNew,
      isBusy: isBusy,
      selectedChips: selectedTags.map((tag) {
        return SelectableChip(
          label: tag.name,
          selected: true,
          onTap: () => onRemoveTag(tag),
        );
      }).toList(),
    );
  }
}
