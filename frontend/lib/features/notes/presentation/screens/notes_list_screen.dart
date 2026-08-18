import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/core/constants/app_colors.dart';
import 'package:frontend/core/constants/app_routes.dart';
import 'package:frontend/core/constants/app_spacing.dart';
import 'package:frontend/core/constants/app_typography.dart';
import 'package:frontend/core/constants/error_messages.dart';
import 'package:frontend/core/widgets/app_search_field.dart';
import 'package:frontend/features/notes/domain/entities/note.dart';
import 'package:frontend/features/notes/domain/repos/notes_repo.dart';
import 'package:frontend/features/notes/presentation/components/note_card.dart';
import 'package:frontend/features/notes/presentation/cubits/notes_cubit.dart';
import 'package:go_router/go_router.dart';

class NotesListScreen extends StatelessWidget {
  const NotesListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          NotesCubit(notesRepo: context.read<NotesRepo>())..loadNotes(),
      child: const _NotesListView(),
    );
  }
}

class _NotesListView extends StatefulWidget {
  const _NotesListView();

  @override
  State<_NotesListView> createState() => _NotesListViewState();
}

class _NotesListViewState extends State<_NotesListView> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openEditor() async {
    await context.push(AppRoutes.noteEditor);
    if (mounted)
      context.read<NotesCubit>().loadNotes(search: _searchController.text);
  }

  Future<void> _openDetail(Note note) async {
    await context.push(AppRoutes.noteDetail, extra: note);
    if (mounted)
      context.read<NotesCubit>().loadNotes(search: _searchController.text);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final typography = AppTypography.of(context);
    return Scaffold(
      backgroundColor: colors.backgroundDark,
      body: SafeArea(
        child: Padding(
          padding: const .symmetric(horizontal: AppSpacing.screenHorizontal),
          child: Column(
            crossAxisAlignment: .stretch,
            children: [
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  const SizedBox(width: 48),
                  Expanded(
                    child: Text(
                      'My Notes',
                      textAlign: .center,
                      style: typography.headlineMedium,
                    ),
                  ),
                  IconButton(
                    onPressed: _openEditor,
                    icon: Icon(Icons.add, color: colors.textPrimary),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              AppSearchField(
                hint: 'Search your notes...',
                controller: _searchController,
                onSubmitted: (value) =>
                    context.read<NotesCubit>().loadNotes(search: value),
              ),
              const SizedBox(height: AppSpacing.lg),
              Expanded(
                child: BlocBuilder<NotesCubit, NotesState>(
                  builder: (context, state) {
                    if (state is NotesLoading || state is NotesInitial) {
                      return Center(
                        child: CircularProgressIndicator(color: colors.primary),
                      );
                    }

                    if (state is NotesError) {
                      return Center(
                        child: Text(
                          genericErrorMessage,
                          textAlign: .center,
                          style: typography.bodySmall,
                        ),
                      );
                    }

                    final notes = state is NotesLoaded
                        ? state.notes
                        : const <Note>[];
                    if (notes.isEmpty) {
                      return Center(
                        child: Text(
                          'No notes yet. Tap + to create your first one.',
                          textAlign: .center,
                          style: typography.bodySmall,
                        ),
                      );
                    }

                    return ListView.separated(
                      itemCount: notes.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: AppSpacing.md),
                      itemBuilder: (context, i) => NoteCard(
                        note: notes[i],
                        onTap: () => _openDetail(notes[i]),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
