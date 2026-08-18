import 'package:flutter/material.dart';
import 'package:frontend/core/constants/app_spacing.dart';
import 'package:frontend/core/constants/app_typography.dart';
import 'package:frontend/features/profile/presentation/components/study_areas_picker.dart';
import 'package:frontend/features/study_areas/domain/entities/study_area.dart';

class StudyAreasStep extends StatelessWidget {
  final List<StudyArea> allStudyAreas;
  final Set<String> selectedStudyAreaIds;
  final bool catalogBusy;
  final ValueChanged<StudyArea> onSelectExisting;
  final void Function(String name) onCreateNew;
  final void Function(String studyAreaId) onRemove;

  const StudyAreasStep({
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
    final typography = AppTypography.of(context);
    return Padding(
      padding: const .only(bottom: AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: .stretch,
        children: [
          Text('What do you study?', style: typography.headlineMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Any field, any major — type it in.',
            style: typography.bodySmall,
          ),
          const SizedBox(height: AppSpacing.xl),
          StudyAreasPicker(
            allStudyAreas: allStudyAreas,
            selectedStudyAreaIds: selectedStudyAreaIds,
            catalogBusy: catalogBusy,
            onSelectExisting: onSelectExisting,
            onCreateNew: onCreateNew,
            onRemove: onRemove,
          ),
        ],
      ),
    );
  }
}
