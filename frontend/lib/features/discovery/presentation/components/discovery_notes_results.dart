import 'package:flutter/material.dart';
import 'package:frontend/core/constants/app_spacing.dart';
import 'package:frontend/core/constants/app_typography.dart';
import 'package:frontend/features/discovery/presentation/components/note_preview_sheet.dart';
import 'package:frontend/features/notes/domain/entities/note.dart';
import 'package:frontend/features/notes/presentation/components/note_card.dart';

class DiscoveryNotesResults extends StatelessWidget {
  final List<Note> notes;
  final String emptyMessage;

  const DiscoveryNotesResults({super.key, required this.notes, required this.emptyMessage});

  @override
  Widget build(BuildContext context) {
    if (notes.isEmpty) {
      return Center(
        child: Text(
          emptyMessage,
          textAlign: .center,
          style: AppTypography.of(context).bodySmall,
        ),
      );
    }
    return ListView.separated(
      itemCount: notes.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (context, i) => NoteCard(
        note: notes[i],
        onTap: () => showNotePreviewSheet(context, notes[i]),
      ),
    );
  }
}
