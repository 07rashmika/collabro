import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import 'package:frontend/core/constants/app_colors.dart';
import 'package:frontend/core/constants/app_spacing.dart';
import 'package:frontend/core/constants/app_typography.dart';
import 'package:frontend/core/services/text_recognition_service.dart';
import 'package:frontend/core/widgets/app_text_field.dart';
import 'package:frontend/core/widgets/primary_button.dart';
import 'package:frontend/core/widgets/secondary_button.dart';
import 'package:frontend/features/notes/domain/entities/note.dart';
import 'package:frontend/features/notes/domain/entities/note_photo.dart';
import 'package:frontend/features/notes/domain/repos/notes_repo.dart';
import 'package:frontend/features/notes/presentation/components/note_photo_gallery.dart';
import 'package:frontend/features/notes/presentation/cubits/notes_cubit.dart';

/// Used for both creating a new note (initialNote == null) and editing an
/// existing one.
class NoteEditorScreen extends StatelessWidget {
  final Note? initialNote;

  const NoteEditorScreen({super.key, this.initialNote});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => NotesCubit(notesRepo: context.read<NotesRepo>()),
      child: _NoteEditorView(initialNote: initialNote),
    );
  }
}

class _NoteEditorView extends StatefulWidget {
  final Note? initialNote;

  const _NoteEditorView({required this.initialNote});

  @override
  State<_NoteEditorView> createState() => _NoteEditorViewState();
}

class _NoteEditorViewState extends State<_NoteEditorView> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  late final TextEditingController _tagsController;
  late bool _isPublic;

  final _imagePicker = ImagePicker();
  final _textRecognitionService = TextRecognitionService();
  bool _isScanning = false;
  late List<NotePhoto> _photos;

  bool get _isEditing => widget.initialNote != null;

  @override
  void initState() {
    super.initState();
    final note = widget.initialNote;
    _titleController = TextEditingController(text: note?.title ?? '');
    _contentController = TextEditingController(text: note?.content ?? '');
    _tagsController = TextEditingController(text: note?.tags.join(', ') ?? '');
    _isPublic = note?.isPublic ?? false;
    _photos = note?.photos ?? [];
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _tagsController.dispose();
    _textRecognitionService.close();
    super.dispose();
  }

  Future<void> _scanText(BuildContext context) async {
    final colors = AppColors.of(context);
    final typography = AppTypography.of(context);
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: colors.backgroundDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusMd)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.photo_camera_outlined, color: colors.textPrimary),
              title: Text('Take a photo', style: typography.titleMedium),
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.camera),
            ),
            ListTile(
              leading: Icon(Icons.photo_library_outlined, color: colors.textPrimary),
              title: Text('Choose from gallery', style: typography.titleMedium),
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.gallery),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
    if (source == null || !context.mounted) return;

    final image = await _imagePicker.pickImage(source: source, imageQuality: 90);
    if (image == null || !context.mounted) return;

    setState(() => _isScanning = true);
    try {
      final scannedText = await _textRecognitionService.recognizeText(image.path);
      if (!context.mounted) return;

      if (scannedText.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Couldn't find any text in that image."),
            backgroundColor: colors.error,
          ),
        );
        return;
      }

      final existing = _contentController.text;
      _contentController.text = existing.trim().isEmpty
          ? scannedText
          : '$existing\n$scannedText';
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to scan text: $e'),
          backgroundColor: colors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  Future<void> _addPhotos(BuildContext context) async {
    final images = await _imagePicker.pickMultiImage(imageQuality: 85, limit: 6);
    if (images.isEmpty || !context.mounted) return;

    context.read<NotesCubit>().uploadPhotos(
      widget.initialNote!.id,
      images.map((x) => x.path).toList(),
    );
  }

  void _deletePhoto(BuildContext context, NotePhoto photo) {
    context.read<NotesCubit>().deletePhoto(widget.initialNote!.id, photo.id);
  }

  void _save(BuildContext context) {
    if (!_formKey.currentState!.validate()) return;

    final tags = _tagsController.text
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    final cubit = context.read<NotesCubit>();
    if (_isEditing) {
      cubit.updateNote(
        widget.initialNote!.id,
        title: _titleController.text.trim(),
        content: _contentController.text.trim(),
        tags: tags,
        isPublic: _isPublic,
      );
    } else {
      cubit.createNote(
        title: _titleController.text.trim(),
        content: _contentController.text.trim(),
        tags: tags,
        isPublic: _isPublic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final typography = AppTypography.of(context);
    return Scaffold(
      backgroundColor: colors.backgroundDark,
      body: SafeArea(
        child: BlocListener<NotesCubit, NotesState>(
          listener: (context, state) {
            if (state is NoteSaved) {
              context.pop(true);
            } else if (state is NotePhotosUpdated) {
              setState(() => _photos = state.note.photos);
            } else if (state is NotesError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(state.message), backgroundColor: colors.error),
              );
            }
          },
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenHorizontal),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => context.pop(),
                        icon: Icon(Icons.arrow_back, color: colors.textPrimary),
                      ),
                      Expanded(
                        child: Text(
                          _isEditing ? 'Edit Note' : 'New Note',
                          textAlign: TextAlign.center,
                          style: typography.headlineMedium,
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppTextField(
                    label: 'Title',
                    hint: 'e.g. Chapter 4: Machine Learning Basics',
                    icon: Icons.title,
                    controller: _titleController,
                    validator: (value) =>
                        (value == null || value.trim().isEmpty) ? 'Title is required' : null,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppTextField(
                    label: 'Content',
                    hint: 'Write or paste your notes here...',
                    icon: Icons.description_outlined,
                    controller: _contentController,
                    maxLines: 8,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.newline,
                    validator: (value) =>
                        (value == null || value.trim().isEmpty) ? 'Content is required' : null,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  SecondaryButton(
                    label: 'Scan Text from Image',
                    leadingIcon: Icons.document_scanner_outlined,
                    isLoading: _isScanning,
                    onPressed: () => _scanText(context),
                  ),
                  if (_isEditing) ...[
                    const SizedBox(height: AppSpacing.lg),
                    Text('Photos', style: typography.titleMedium),
                    const SizedBox(height: AppSpacing.sm),
                    BlocBuilder<NotesCubit, NotesState>(
                      builder: (context, state) {
                        return NotePhotoGallery(
                          photos: _photos,
                          editable: true,
                          isBusy: state is NotePhotosUpdating,
                          onAdd: () => _addPhotos(context),
                          onDelete: (photo) => _deletePhoto(context, photo),
                        );
                      },
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  AppTextField(
                    label: 'Tags (comma separated)',
                    hint: 'algorithms, midterm, chapter4',
                    icon: Icons.sell_outlined,
                    controller: _tagsController,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Make public', style: typography.titleMedium),
                            Text(
                              'Public notes can be discovered by other students.',
                              style: typography.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _isPublic,
                        activeThumbColor: colors.primary,
                        onChanged: (value) => setState(() => _isPublic = value),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  BlocBuilder<NotesCubit, NotesState>(
                    builder: (context, state) {
                      return PrimaryButton(
                        label: _isEditing ? 'Save Changes' : 'Create Note',
                        isLoading: state is NoteSaving,
                        onPressed: () => _save(context),
                      );
                    },
                  ),
                  const SizedBox(height: AppSpacing.xl),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
