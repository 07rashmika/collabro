import 'package:flutter/material.dart';
import 'package:frontend/core/widgets/selectable_chip.dart';
import 'package:frontend/core/widgets/typeahead_chip_picker.dart';
import 'package:frontend/features/skills/domain/entities/skill.dart';

const _levelLabels = {
  'BEGINNER': 'Beginner',
  'INTERMEDIATE': 'Intermediate',
  'ADVANCED': 'Advanced',
};

class SkillsPicker extends StatelessWidget {
  final List<Skill> allSkills;
  final Map<String, String> selectedSkillLevels;
  final bool catalogBusy;
  final List<String> remoteSkillSuggestions;
  final bool remoteSkillsBusy;
  final ValueChanged<Skill> onSelectExisting;
  final void Function(String name) onCreateNew;
  final ValueChanged<String> onQueryChanged;
  final void Function(String skillId) onCycleLevel;

  const SkillsPicker({
    super.key,
    required this.allSkills,
    required this.selectedSkillLevels,
    required this.catalogBusy,
    required this.remoteSkillSuggestions,
    required this.remoteSkillsBusy,
    required this.onSelectExisting,
    required this.onCreateNew,
    required this.onQueryChanged,
    required this.onCycleLevel,
  });

  @override
  Widget build(BuildContext context) {
    final suggestions = allSkills
        .where((s) => !selectedSkillLevels.containsKey(s.id))
        .toList();

    return TypeaheadChipPicker<Skill>(
      label: 'Skills',
      hint: 'e.g. Organic Chemistry, Debate, Photoshop',
      suggestions: suggestions,
      labelOf: (s) => s.name,
      onSelectExisting: onSelectExisting,
      onCreateNew: onCreateNew,
      isBusy: catalogBusy,
      onQueryChanged: onQueryChanged,
      remoteSuggestions: remoteSkillSuggestions,
      remoteBusy: remoteSkillsBusy,
      selectedChips: selectedSkillLevels.entries.map((e) {
        final skill = allSkills.firstWhere((s) => s.id == e.key);
        return SelectableChip(
          label: skill.name,
          selected: true,
          trailingLabel: _levelLabels[e.value],
          onTap: () => onCycleLevel(e.key),
        );
      }).toList(),
    );
  }
}
