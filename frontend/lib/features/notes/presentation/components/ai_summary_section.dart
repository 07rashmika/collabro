import 'package:flutter/material.dart';
import 'package:frontend/core/constants/app_colors.dart';
import 'package:frontend/core/constants/app_spacing.dart';
import 'package:frontend/core/constants/app_typography.dart';
import 'package:frontend/core/widgets/primary_button.dart';

class AiSummarySection extends StatelessWidget {
  final String? summary;
  final bool isGenerating;
  final VoidCallback onGenerate;

  const AiSummarySection({
    super.key,
    required this.summary,
    required this.isGenerating,
    required this.onGenerate,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final typography = AppTypography.of(context);
    return Container(
      width: .infinity,
      padding: const .all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: colors.backgroundCard,
        borderRadius: .circular(AppSpacing.radiusLg),
        border: .all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: .start,
        children: [
          Row(
            children: [
              Icon(
                Icons.auto_awesome,
                color: colors.primary,
                size: AppSpacing.iconMd,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text('AI Summary', style: typography.headlineSmall),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (summary == null) ...[
            Text(
              'Generate a quick summary of this note.',
              style: typography.bodySmall,
            ),
            const SizedBox(height: AppSpacing.md),
            PrimaryButton(
              label: isGenerating ? 'Generating...' : 'Generate Summary',
              isLoading: isGenerating,
              leadingIcon: Icons.auto_awesome,
              onPressed: isGenerating ? null : onGenerate,
            ),
          ] else ...[
            Text(summary!, style: typography.bodyMedium),
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              onPressed: isGenerating ? null : onGenerate,
              style: TextButton.styleFrom(padding: .zero),
              child: Text(
                'Regenerate',
                style: typography.labelSmall.copyWith(
                  color: colors.primaryLight,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
