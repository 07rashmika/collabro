import 'package:flutter/material.dart';
import 'package:frontend/core/constants/app_colors.dart';
import 'package:frontend/core/constants/app_spacing.dart';
import 'package:frontend/core/constants/app_typography.dart';
import 'package:frontend/core/widgets/skill_chip.dart';
import 'package:frontend/features/profiles/domain/entities/profile.dart';

const _levelLabels = {
  'BEGINNER': 'Beginner',
  'INTERMEDIATE': 'Intermediate',
  'ADVANCED': 'Advanced',
};

List<Widget> buildProfileDetailSections(
  BuildContext context, {
  String? bio,
  String? learningGoal,
  String? teachGoal,
  List<ProfileSkillEntry> skills = const [],
  List<ProfileStudyAreaEntry> studyAreas = const [],
  List<String> interests = const [],
}) {
  final typography = AppTypography.of(context);
  return [
    if (bio != null && bio.isNotEmpty) ...[
      Text(bio, style: typography.bodyMedium, textAlign: TextAlign.center),
      const SizedBox(height: AppSpacing.xxl),
    ],
    if (learningGoal != null && learningGoal.isNotEmpty)
      _buildDetailRow(
        context,
        icon: Icons.flag_outlined,
        label: 'Wants to learn',
        value: learningGoal,
      ),
    if (teachGoal != null && teachGoal.isNotEmpty)
      _buildDetailRow(
        context,
        icon: Icons.school_outlined,
        label: 'Can teach',
        value: teachGoal,
      ),
    const SizedBox(height: AppSpacing.lg),
    _buildChipSection(
      context,
      'Skills',
      skills
          .map((s) => '${s.name} · ${_levelLabels[s.level] ?? s.level}')
          .toList(),
    ),
    _buildChipSection(
      context,
      'Study Areas',
      studyAreas.map((a) => a.name).toList(),
    ),
    _buildChipSection(context, 'Interests', interests),
  ];
}

Widget _buildDetailRow(
  BuildContext context, {
  required IconData icon,
  required String label,
  required String value,
}) {
  final colors = AppColors.of(context);
  final typography = AppTypography.of(context);
  return Padding(
    padding: const .only(bottom: AppSpacing.md),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: AppSpacing.iconMd, color: colors.textTertiary),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: .start,
            children: [
              Text(label, style: typography.labelSmall),
              Text(value, style: typography.bodyMedium),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget _buildChipSection(
  BuildContext context,
  String title,
  List<String> items,
) {
  if (items.isEmpty) return const SizedBox.shrink();
  final typography = AppTypography.of(context);
  return Padding(
    padding: const .only(bottom: AppSpacing.xl),
    child: Column(
      crossAxisAlignment: .start,
      children: [
        Text(title, style: typography.headlineSmall),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: items.map((label) => SkillChip(label: label)).toList(),
        ),
      ],
    ),
  );
}
