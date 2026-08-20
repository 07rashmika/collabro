import 'package:flutter/material.dart';
import 'package:frontend/core/constants/app_spacing.dart';
import 'package:frontend/core/constants/app_typography.dart';
import 'package:frontend/core/widgets/tag_input.dart';

class InterestsStep extends StatelessWidget {
  final List<String> interests;
  final ValueChanged<String> onAdd;
  final ValueChanged<String> onRemove;

  const InterestsStep({
    super.key,
    required this.interests,
    required this.onAdd,
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
          Text('What are you into?', style: typography.headlineMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(
            "Hobbies, obsessions, anything — helps us match you beyond just coursework.",
            style: typography.bodySmall,
          ),
          const SizedBox(height: AppSpacing.xl),
          TagInput(
            label: 'Interests',
            hint: 'e.g. competitive programming, sci-fi novels',
            tags: interests,
            onAdd: onAdd,
            onRemove: onRemove,
            maxTags: 30,
          ),
        ],
      ),
    );
  }
}
