import 'package:flutter/material.dart';
import 'package:frontend/core/constants/app_spacing.dart';
import 'package:frontend/core/constants/app_typography.dart';
import 'package:frontend/core/widgets/app_text_field.dart';

class AboutStep extends StatelessWidget {
  final TextEditingController bioController;
  final TextEditingController learningGoalController;
  final TextEditingController teachGoalController;

  const AboutStep({
    super.key,
    required this.bioController,
    required this.learningGoalController,
    required this.teachGoalController,
  });

  @override
  Widget build(BuildContext context) {
    final typography = AppTypography.of(context);
    return Padding(
      padding: const .only(bottom: AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: .stretch,
        children: [
          Text('Almost done', style: typography.headlineMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'A few optional details to help peers get to know you.',
            style: typography.bodySmall,
          ),
          const SizedBox(height: AppSpacing.xl),
          AppTextField(
            label: 'Short bio (optional)',
            hint: 'A sentence or two about you',
            icon: Icons.person_outline,
            controller: bioController,
            maxLines: 3,
          ),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(
            label: 'What do you want to learn? (optional)',
            hint: 'e.g. React, data structures',
            icon: Icons.flag_outlined,
            controller: learningGoalController,
          ),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(
            label: 'What can you teach? (optional)',
            hint: 'e.g. Python, calculus',
            icon: Icons.school_outlined,
            controller: teachGoalController,
          ),
        ],
      ),
    );
  }
}
