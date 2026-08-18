import 'package:flutter/material.dart';
import 'package:frontend/core/constants/app_colors.dart';
import 'package:frontend/core/constants/app_spacing.dart';
import 'package:frontend/core/constants/app_typography.dart';
import 'package:frontend/features/discovery/presentation/components/note_preview_sheet.dart';
import 'package:frontend/features/notes/domain/entities/note.dart';
import 'package:frontend/features/notes/presentation/components/note_card.dart';
import 'package:frontend/features/sessions/domain/entities/study_session.dart';
import 'package:frontend/features/sessions/presentation/components/session_list_card.dart';

class UserPostsSection extends StatelessWidget {
  final List<Note> notes;
  final List<StudySession> sessions;

  const UserPostsSection({
    super.key,
    required this.notes,
    required this.sessions,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final typography = AppTypography.of(context);

    if (notes.isEmpty && sessions.isEmpty) {
      return Padding(
        padding: const .symmetric(vertical: AppSpacing.xl),
        child: Center(
          child: Text(
            "Hasn't posted anything public yet.",
            style: typography.bodySmall.copyWith(color: colors.textTertiary),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: .start,
      children: [
        if (notes.isNotEmpty) ...[
          Text('Notes', style: typography.headlineSmall),
          const SizedBox(height: AppSpacing.md),
          for (final note in notes) ...[
            NoteCard(
              note: note,
              onTap: () => showNotePreviewSheet(context, note),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          const SizedBox(height: AppSpacing.md),
        ],
        if (sessions.isNotEmpty) ...[
          Text('Sessions', style: typography.headlineSmall),
          const SizedBox(height: AppSpacing.md),
          for (final session in sessions) ...[
            SessionListCard(session: session, onTap: () {}),
            const SizedBox(height: AppSpacing.md),
          ],
        ],
      ],
    );
  }
}
