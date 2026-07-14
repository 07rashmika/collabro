import 'package:flutter/material.dart';
import 'package:frontend/core/constants/app_colors.dart';
import 'package:frontend/core/constants/app_spacing.dart';
import 'package:frontend/core/constants/app_typography.dart';
import 'package:frontend/core/widgets/primary_button.dart';

/// Shows the (hardcoded) AI summary for a note, or a button to generate
/// one. See notes/presentation/utils/hardcoded_summarizer.dart — there is
/// no real summarization backend yet.
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: AppColors.primary, size: AppSpacing.iconMd),
              const SizedBox(width: AppSpacing.xs),
              Text('AI Summary', style: AppTypography.headlineSmall),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (summary == null) ...[
            Text(
              'Generate a quick summary of this note.',
              style: AppTypography.bodySmall,
            ),
            const SizedBox(height: AppSpacing.md),
            PrimaryButton(
              label: isGenerating ? 'Generating...' : 'Generate Summary',
              isLoading: isGenerating,
              leadingIcon: Icons.auto_awesome,
              onPressed: isGenerating ? null : onGenerate,
            ),
          ] else ...[
            Text(summary!, style: AppTypography.bodyMedium),
            const SizedBox(height: AppSpacing.sm),
            Text(
              "Placeholder summary — AI summarization isn't wired up yet.",
              style: AppTypography.caption,
            ),
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              onPressed: isGenerating ? null : onGenerate,
              style: TextButton.styleFrom(padding: EdgeInsets.zero),
              child: Text(
                'Regenerate',
                style: AppTypography.labelSmall.copyWith(color: AppColors.primaryLight),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
