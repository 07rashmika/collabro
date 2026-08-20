import 'package:flutter/material.dart';
import 'package:frontend/core/constants/app_spacing.dart';
import 'package:frontend/core/constants/app_typography.dart';
import 'package:frontend/features/profile/presentation/components/skills_picker.dart';
import 'package:frontend/features/skills/domain/entities/skill.dart';

class SkillsStep extends StatelessWidget {
  final List<Skill> allSkills;
  final Map<String, String> selectedSkillLevels;
  final bool catalogBusy;
  final List<String> remoteSkillSuggestions;
  final bool remoteSkillsBusy;
  final ValueChanged<Skill> onSelectExisting;
  final void Function(String name) onCreateNew;
  final ValueChanged<String> onQueryChanged;
  final void Function(String skillId) onCycleLevel;

  const SkillsStep({
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
    final typography = AppTypography.of(context);
    return Padding(
      padding: const .only(bottom: AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: .stretch,
        children: [
          Text('What are you good at?', style: typography.headlineMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(
            "Type any skill — not just tech. Add it, then tap the chip to set your level.",
            style: typography.bodySmall,
          ),
          const SizedBox(height: AppSpacing.xl),
          SkillsPicker(
            allSkills: allSkills,
            selectedSkillLevels: selectedSkillLevels,
            catalogBusy: catalogBusy,
            remoteSkillSuggestions: remoteSkillSuggestions,
            remoteSkillsBusy: remoteSkillsBusy,
            onSelectExisting: onSelectExisting,
            onCreateNew: onCreateNew,
            onQueryChanged: onQueryChanged,
            onCycleLevel: onCycleLevel,
          ),
        ],
      ),
    );
  }
}
