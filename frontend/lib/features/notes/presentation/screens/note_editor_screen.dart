import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/core/constants/app_colors.dart';
import 'package:frontend/core/constants/app_spacing.dart';
import 'package:frontend/core/constants/app_typography.dart';
import 'package:frontend/core/services/text_recognition_service.dart';
import 'package:frontend/core/utils/snackbar_utils.dart';
import 'package:frontend/core/widgets/app_text_field.dart';
import 'package:frontend/core/widgets/primary_button.dart';
import 'package:frontend/core/widgets/secondary_button.dart';
import 'package:frontend/features/notes/domain/entities/note.dart';
import 'package:frontend/features/notes/domain/entities/note_photo.dart';
import 'package:frontend/features/notes/domain/repos/notes_repo.dart';
import 'package:frontend/features/notes/presentation/components/draft_summary_section.dart';
import 'package:frontend/features/notes/presentation/components/note_photo_gallery.dart';
import 'package:frontend/features/notes/presentation/components/note_tags_picker.dart';
import 'package:frontend/features/notes/presentation/cubits/notes_cubit.dart';
import 'package:frontend/features/skills/domain/entities/skill.dart';
import 'package:frontend/features/skills/domain/repos/skills_repo.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:read_pdf_text/read_pdf_text.dart';

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

  final _imagePicker = ImagePicker();
  final _textRecognitionService = TextRecognitionService();
  bool _isScanning = false;
  bool _isImportingPdf = false;
  late List<NotePhoto> _photos;

  List<Skill> _allSkills = [];
  final List<Skill> _selectedTags = [];
  bool _tagsBusy = false;

  String? _draftNoteId;
  Note? _draftNote;

  bool get _isEditing => widget.initialNote != null;

  @override
  void initState() {
    super.initState();
    final note = widget.initialNote;
    _titleController = TextEditingController(text: note?.title ?? '');
    _contentController = TextEditingController(text: note?.content ?? '');
    _photos = note?.photos ?? [];
    _selectedTags.addAll(
      (note?.tags ?? []).map((t) => Skill(id: t, name: t, category: '')),
    );
    context.read<SkillsRepo>().getAllSkills().then((skills) {
      if (mounted) setState(() => _allSkills = skills);
    });
    _contentController.addListener(_clearStaleSummary);
  }

  void _clearStaleSummary() {
    if (_draftNote != null) setState(() => _draftNote = null);
  }

  @override
  void dispose() {
    _contentController.removeListener(_clearStaleSummary);
    _titleController.dispose();
    _contentController.dispose();
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
        borderRadius: .vertical(top: .circular(AppSpacing.radiusMd)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: .min,
          children: [
            ListTile(
              leading: Icon(
                Icons.photo_camera_outlined,
                color: colors.textPrimary,
              ),
              title: Text('Take a photo', style: typography.titleMedium),
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.camera),
            ),
            ListTile(
              leading: Icon(
                Icons.photo_library_outlined,
                color: colors.textPrimary,
              ),
              title: Text('Choose from gallery', style: typography.titleMedium),
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.gallery),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
    if (source == null || !context.mounted) return;

    final image = await _imagePicker.pickImage(
      source: source,
      imageQuality: 90,
    );
    if (image == null || !context.mounted) return;

    setState(() => _isScanning = true);
    try {
      final scannedText = await _textRecognitionService.recognizeText(
        image.path,
      );
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
      showErrorSnackBar(context);
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  Future<void> _importPdf(BuildContext context) async {
    final colors = AppColors.of(context);
    final result = await FilePicker.pickFiles(
      type: .custom,
      allowedExtensions: ['pdf'],
    );
    final path = result?.files.single.path;
    if (path == null || !context.mounted) return;

    setState(() => _isImportingPdf = true);
    try {
      final text = await ReadPdfText.getPDFtext(path);
      if (!context.mounted) return;

      if (text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Couldn't find any text in that PDF."),
            backgroundColor: colors.error,
          ),
        );
        return;
      }

      final existing = _contentController.text;
      _contentController.text = existing.trim().isEmpty
          ? text
          : '$existing\n$text';
    } catch (e) {
      if (!context.mounted) return;
      showErrorSnackBar(context);
    } finally {
      if (mounted) setState(() => _isImportingPdf = false);
    }
  }

  Future<void> _addPhotos(BuildContext context) async {
    final images = await _imagePicker.pickMultiImage(
      imageQuality: 85,
      limit: 6,
    );
    if (images.isEmpty || !context.mounted) return;

    context.read<NotesCubit>().uploadPhotos(
      widget.initialNote!.id,
      images.map((x) => x.path).toList(),
    );
  }

  void _deletePhoto(BuildContext context, NotePhoto photo) {
    context.read<NotesCubit>().deletePhoto(widget.initialNote!.id, photo.id);
  }

  List<String> get _tags => _selectedTags.map((s) => s.name).toList();

  Future<void> _createAndSelectTag(String name) async {
    setState(() => _tagsBusy = true);
    try {
      final skill = await context.read<SkillsRepo>().findOrCreateSkill(name);
      if (!mounted) return;
      setState(() {
        if (!_allSkills.any((s) => s.id == skill.id)) _allSkills.add(skill);
        if (!_selectedTags.any(
          (t) => t.name.toLowerCase() == skill.name.toLowerCase(),
        )) {
          _selectedTags.add(skill);
        }
        _tagsBusy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _tagsBusy = false);
      showErrorSnackBar(context);
    }
  }

  void _save(BuildContext context) {
    if (!_formKey.currentState!.validate()) return;
    context.read<NotesCubit>().updateNote(
      widget.initialNote!.id,
      title: _titleController.text.trim(),
      content: _contentController.text.trim(),
      tags: _tags,
    );
  }

  String _deriveTitleFromContent(String content) {
    final firstLine = content.trim().split('\n').first.trim();
    if (firstLine.isEmpty) return 'Untitled Note';
    return firstLine.length > 100
        ? '${firstLine.substring(0, 100)}...'
        : firstLine;
  }

  void _summarize(BuildContext context) {
    if (!_formKey.currentState!.validate()) return;
    final content = _contentController.text.trim();
    final title = _titleController.text.trim();
    context.read<NotesCubit>().summarizeAndSaveDraft(
      existingNoteId: _draftNoteId,
      title: title.isEmpty ? _deriveTitleFromContent(content) : title,
      content: content,
      tags: _tags,
    );
  }

  void _post(BuildContext context) {
    if (!_formKey.currentState!.validate()) return;
    final noteId = _draftNoteId;
    if (noteId == null) return;
    context.read<NotesCubit>().updateNote(
      noteId,
      title: _titleController.text.trim(),
      tags: _tags,
      isPublic: true,
    );
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
            } else if (state is DraftSaved) {
              setState(() {
                _draftNoteId = state.note.id;
                _draftNote = state.note;
                if (_titleController.text.trim().isEmpty) {
                  _titleController.text = state.note.title;
                }
              });
            } else if (state is NotesError) {
              showErrorSnackBar(context);
            }
          },
          child: SingleChildScrollView(
            padding: const .symmetric(horizontal: AppSpacing.screenHorizontal),
            child: Form(
              key: _formKey,
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
                      Expanded(
                        child: Text(
                          _isEditing ? 'Edit Note' : 'New Note',
                          textAlign: .center,
                          style: typography.headlineMedium,
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                  if (_isEditing) ...[
                    const SizedBox(height: AppSpacing.lg),
                    AppTextField(
                      label: 'Title',
                      hint: 'e.g. Chapter 4: Machine Learning Basics',
                      icon: Icons.title,
                      controller: _titleController,
                      validator: (value) =>
                          (value == null || value.trim().isEmpty)
                          ? 'Title is required'
                          : null,
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  AppTextField(
                    label: 'Content',
                    hint: 'Write or paste your notes here...',
                    icon: Icons.description_outlined,
                    controller: _contentController,
                    maxLines: 8,
                    keyboardType: .multiline,
                    textInputAction: .newline,
                    validator: (value) =>
                        (value == null || value.trim().isEmpty)
                        ? 'Content is required'
                        : null,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  SecondaryButton(
                    label: 'Scan Text from Image',
                    leadingIcon: Icons.document_scanner_outlined,
                    isLoading: _isScanning,
                    onPressed: () => _scanText(context),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  SecondaryButton(
                    label: 'Import PDF',
                    leadingIcon: Icons.picture_as_pdf_outlined,
                    isLoading: _isImportingPdf,
                    onPressed: () => _importPdf(context),
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
                  if (_isEditing) ...[
                    const SizedBox(height: AppSpacing.lg),
                    NoteTagsPicker(
                      allSkills: _allSkills,
                      selectedTags: _selectedTags,
                      isBusy: _tagsBusy,
                      onSelectExisting: (s) =>
                          setState(() => _selectedTags.add(s)),
                      onRemoveTag: (tag) => setState(
                        () => _selectedTags.removeWhere(
                          (t) => t.name.toLowerCase() == tag.name.toLowerCase(),
                        ),
                      ),
                      onCreateNew: _createAndSelectTag,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    BlocBuilder<NotesCubit, NotesState>(
                      builder: (context, state) {
                        return PrimaryButton(
                          label: 'Save Changes',
                          isLoading: state is NoteSaving,
                          onPressed: () => _save(context),
                        );
                      },
                    ),
                  ] else ...[
                    const SizedBox(height: AppSpacing.lg),
                    DraftSummarySection(
                      draftNote: _draftNote,
                      onSummarize: () => _summarize(context),
                    ),
                    if (_draftNote != null) ...[
                      const SizedBox(height: AppSpacing.lg),
                      AppTextField(
                        label: 'Title',
                        hint: 'e.g. Chapter 4: Machine Learning Basics',
                        icon: Icons.title,
                        controller: _titleController,
                        validator: (value) =>
                            (value == null || value.trim().isEmpty)
                            ? 'Title is required to post publicly'
                            : null,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      NoteTagsPicker(
                        allSkills: _allSkills,
                        selectedTags: _selectedTags,
                        isBusy: _tagsBusy,
                        onSelectExisting: (s) =>
                            setState(() => _selectedTags.add(s)),
                        onRemoveTag: (tag) => setState(
                          () => _selectedTags.removeWhere(
                            (t) =>
                                t.name.toLowerCase() == tag.name.toLowerCase(),
                          ),
                        ),
                        onCreateNew: _createAndSelectTag,
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      BlocBuilder<NotesCubit, NotesState>(
                        builder: (context, state) {
                          return PrimaryButton(
                            label: 'Post Note',
                            leadingIcon: Icons.publish_outlined,
                            isLoading: state is NoteSaving,
                            onPressed: () => _post(context),
                          );
                        },
                      ),
                    ],
                  ],
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
