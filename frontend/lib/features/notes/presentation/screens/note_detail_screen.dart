import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/core/constants/app_colors.dart';
import 'package:frontend/core/constants/app_routes.dart';
import 'package:frontend/core/constants/app_spacing.dart';
import 'package:frontend/core/constants/app_typography.dart';
import 'package:frontend/core/utils/snackbar_utils.dart';
import 'package:frontend/core/utils/time_ago.dart';
import 'package:frontend/core/widgets/danger_button.dart';
import 'package:frontend/core/widgets/primary_button.dart';
import 'package:frontend/core/widgets/skill_chip.dart';
import 'package:frontend/features/notes/domain/entities/note.dart';
import 'package:frontend/features/notes/domain/repos/notes_repo.dart';
import 'package:frontend/features/notes/presentation/components/ai_summary_section.dart';
import 'package:frontend/features/notes/presentation/components/note_photo_gallery.dart';
import 'package:frontend/features/notes/presentation/cubits/notes_cubit.dart';
import 'package:go_router/go_router.dart';

class NoteDetailScreen extends StatelessWidget {
  final Note note;

  const NoteDetailScreen({super.key, required this.note});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => NotesCubit(notesRepo: context.read<NotesRepo>()),
      child: _NoteDetailView(initialNote: note),
    );
  }
}

class _NoteDetailView extends StatefulWidget {
  final Note initialNote;

  const _NoteDetailView({required this.initialNote});

  @override
  State<_NoteDetailView> createState() => _NoteDetailViewState();
}

class _NoteDetailViewState extends State<_NoteDetailView> {
  late Note _note;

  @override
  void initState() {
    super.initState();
    _note = widget.initialNote;
  }

  Future<void> _editNote(BuildContext context) async {
    await context.push(AppRoutes.noteEditor, extra: _note);
    if (context.mounted) context.pop();
  }

  void _confirmDelete(BuildContext context) {
    final colors = AppColors.of(context);
    final typography = AppTypography.of(context);
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: colors.backgroundCard,
        title: Text('Delete note?', style: typography.headlineSmall),
        content: Text(
          'This permanently deletes "${_note.title}". This can\'t be undone.',
          style: typography.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => dialogContext.pop(),
            child: Text('Cancel', style: typography.labelMedium),
          ),
          DangerButton(
            label: 'Delete',
            onPressed: () {
              dialogContext.pop();
              context.read<NotesCubit>().deleteNote(_note.id);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final typography = AppTypography.of(context);
    return Scaffold(
      backgroundColor: colors.backgroundDark,
      body: SafeArea(
        child: BlocConsumer<NotesCubit, NotesState>(
          listener: (context, state) {
            if (state is NoteDeleted) {
              context.pop();
            } else if (state is NoteSaved) {
              setState(() => _note = state.note);
            } else if (state is NoteSummarized) {
              setState(() => _note = state.note);
            } else if (state is NotesError) {
              showErrorSnackBar(context);
            }
          },
          builder: (context, state) {
            final isBusy = state is NoteSaving;
            return SingleChildScrollView(
              padding: const .symmetric(
                horizontal: AppSpacing.screenHorizontal,
              ),
              child: Column(
                crossAxisAlignment: .stretch,
                children: [
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => context.pop(),
                        icon: Icon(Icons.arrow_back, color: colors.textPrimary),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: isBusy
                            ? null
                            : () => context.read<NotesCubit>().toggleVisibility(
                                _note.id,
                              ),
                        icon: Icon(
                          _note.isPublic ? Icons.public : Icons.lock_outline,
                          color: colors.textPrimary,
                        ),
                        tooltip: _note.isPublic
                            ? 'Make private'
                            : 'Make public',
                      ),
                      IconButton(
                        onPressed: isBusy ? null : () => _editNote(context),
                        icon: Icon(
                          Icons.edit_outlined,
                          color: colors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  Text(_note.title, style: typography.displayMedium),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Updated ${timeAgo(_note.updatedAt)}',
                    style: typography.bodySmall,
                  ),
                  if (_note.tags.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: _note.tags
                          .map((t) => SkillChip(label: t))
                          .toList(),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                  Container(
                    width: double.infinity,
                    padding: const .all(AppSpacing.cardPadding),
                    decoration: BoxDecoration(
                      color: colors.backgroundCard,
                      borderRadius: .circular(AppSpacing.radiusLg),
                      border: .all(color: colors.border),
                    ),
                    child: Text(_note.content, style: typography.bodyLarge),
                  ),
                  if (_note.photos.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xl),
                    Text('Photos', style: typography.titleMedium),
                    const SizedBox(height: AppSpacing.sm),
                    NotePhotoGallery(photos: _note.photos),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                  AiSummarySection(
                    summary: _note.summary,
                    isGenerating: state is NoteSummarizing,
                    onGenerate: () =>
                        context.read<NotesCubit>().summarizeNote(_note),
                  ),
                  if (_note.summary != null && !_note.isPublic) ...[
                    const SizedBox(height: AppSpacing.lg),
                    PrimaryButton(
                      label: 'Post Note',
                      leadingIcon: Icons.publish_outlined,
                      isLoading: isBusy,
                      onPressed: isBusy
                          ? null
                          : () => context.read<NotesCubit>().toggleVisibility(
                              _note.id,
                            ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xxl),
                  Center(
                    child: DangerButton(
                      label: 'Delete Note',
                      icon: Icons.delete_outline,
                      onPressed: isBusy ? null : () => _confirmDelete(context),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
