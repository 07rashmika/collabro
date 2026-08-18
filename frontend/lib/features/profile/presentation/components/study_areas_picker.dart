import 'package:flutter/material.dart';
import 'package:frontend/core/widgets/selectable_chip.dart';
import 'package:frontend/core/widgets/typeahead_chip_picker.dart';
import 'package:frontend/features/study_areas/domain/entities/study_area.dart';

class StudyAreasPicker extends StatelessWidget {
  final List<StudyArea> allStudyAreas;
  final Set<String> selectedStudyAreaIds;
  final bool catalogBusy;
  final ValueChanged<StudyArea> onSelectExisting;
  final void Function(String name) onCreateNew;
  final void Function(String studyAreaId) onRemove;

  const StudyAreasPicker({
    super.key,
    required this.allStudyAreas,
    required this.selectedStudyAreaIds,
    required this.catalogBusy,
    required this.onSelectExisting,
    required this.onCreateNew,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final suggestions = allStudyAreas
        .where((a) => !selectedStudyAreaIds.contains(a.id))
        .toList();

    return TypeaheadChipPicker<StudyArea>(
      label: 'Study areas',
      hint: 'e.g. Nursing, Economics, Fine Arts',
      suggestions: suggestions,
      labelOf: (a) => a.name,
      onSelectExisting: onSelectExisting,
      onCreateNew: onCreateNew,
      isBusy: catalogBusy,
      selectedChips: selectedStudyAreaIds.map((id) {
        final area = allStudyAreas.firstWhere((a) => a.id == id);
        return SelectableChip(
          label: area.name,
          selected: true,
          onTap: () => onRemove(id),
        );
      }).toList(),
    );
  }
}
