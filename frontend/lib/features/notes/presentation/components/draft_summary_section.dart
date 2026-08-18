import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/core/constants/app_colors.dart';
import 'package:frontend/core/constants/app_spacing.dart';
import 'package:frontend/core/constants/app_typography.dart';
import 'package:frontend/core/widgets/secondary_button.dart';
import 'package:frontend/features/notes/domain/entities/note.dart';
import 'package:frontend/features/notes/presentation/cubits/notes_cubit.dart';

class DraftSummarySection extends StatelessWidget {
  final Note? draftNote;
  final VoidCallback onSummarize;

  const DraftSummarySection({
    super.key,
    required this.draftNote,
    required this.onSummarize,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final typography = AppTypography.of(context);
    return BlocBuilder<NotesCubit, NotesState>(
      builder: (context, state) {
        final isGenerating = state is DraftSummarizing;
        return Container(
          width: .infinity,
          padding: const .all(AppSpacing.cardPadding),
          decoration: BoxDecoration(
            color: colors.backgroundCard,
            borderRadius: .circular(AppSpacing.radiusLg),
            border: Border.all(color: colors.border),
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
              if (draftNote == null) ...[
                SecondaryButton(
                  label: isGenerating ? 'Summarizing...' : 'Summarize Note',
                  leadingIcon: Icons.auto_awesome,
                  isLoading: isGenerating,
                  onPressed: isGenerating ? null : onSummarize,
                ),
              ] else ...[
                Text(draftNote!.summary ?? '', style: typography.bodyMedium),
                const SizedBox(height: AppSpacing.sm),
                TextButton(
                  onPressed: isGenerating ? null : onSummarize,
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
      },
    );
  }
}
