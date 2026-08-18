import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/core/constants/app_colors.dart';
import 'package:frontend/core/constants/app_spacing.dart';
import 'package:frontend/core/constants/app_typography.dart';
import 'package:frontend/core/constants/error_messages.dart';
import 'package:frontend/core/utils/session_time_label.dart';
import 'package:frontend/core/utils/snackbar_utils.dart';
import 'package:frontend/core/widgets/app_text_field.dart';
import 'package:frontend/core/widgets/pill_button.dart';
import 'package:frontend/core/widgets/primary_button.dart';
import 'package:frontend/core/widgets/selectable_chip.dart';
import 'package:frontend/core/widgets/typeahead_chip_picker.dart';
import 'package:frontend/core/widgets/user_avatar.dart';
import 'package:frontend/features/matching/domain/repos/matching_repo.dart';
import 'package:frontend/features/matching/presentation/cubits/matching_cubit.dart';
import 'package:frontend/features/sessions/domain/entities/study_session.dart';
import 'package:frontend/features/sessions/domain/repos/sessions_repo.dart';
import 'package:frontend/features/sessions/presentation/components/session_picker_field.dart';
import 'package:frontend/features/sessions/presentation/cubits/sessions_cubit.dart';
import 'package:frontend/features/skills/domain/entities/skill.dart';
import 'package:frontend/features/skills/domain/repos/skills_repo.dart';
import 'package:go_router/go_router.dart';

class NewSessionScreen extends StatelessWidget {
  const NewSessionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) =>
              SessionsCubit(sessionsRepo: context.read<SessionsRepo>()),
        ),
        BlocProvider(
          create: (context) =>
              MatchingCubit(matchingRepo: context.read<MatchingRepo>())
                ..loadMatches(),
        ),
      ],
      child: const _NewSessionView(),
    );
  }
}

class _NewSessionView extends StatefulWidget {
  const _NewSessionView();

  @override
  State<_NewSessionView> createState() => _NewSessionViewState();
}

class _NewSessionViewState extends State<_NewSessionView> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _passwordController = TextEditingController();
  SessionType _type = .text;
  final Set<String> _selectedParticipantIds = {};

  bool _scheduleForLater = false;
  DateTime? _scheduledDate;
  TimeOfDay? _scheduledTime;

  bool _isPublic = false;
  List<Skill> _allSkills = [];
  final List<Skill> _selectedTags = [];
  bool _tagsBusy = false;

  @override
  void initState() {
    super.initState();
    context.read<SkillsRepo>().getAllSkills().then((skills) {
      if (mounted) setState(() => _allSkills = skills);
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _createAndSelectTag(String name) async {
    setState(() => _tagsBusy = true);
    try {
      final skill = await context.read<SkillsRepo>().findOrCreateSkill(name);
      if (!mounted) return;
      setState(() {
        if (!_allSkills.any((s) => s.id == skill.id)) _allSkills.add(skill);
        if (!_selectedTags.any((s) => s.id == skill.id))
          _selectedTags.add(skill);
        _tagsBusy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _tagsBusy = false);
      showErrorSnackBar(context);
    }
  }

  DateTime? get _scheduledAt {
    if (!_scheduleForLater || _scheduledDate == null || _scheduledTime == null)
      return null;
    return DateTime(
      _scheduledDate!.year,
      _scheduledDate!.month,
      _scheduledDate!.day,
      _scheduledTime!.hour,
      _scheduledTime!.minute,
    );
  }

  Future<void> _pickDate(BuildContext context) async {
    final colors = AppColors.of(context);
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _scheduledDate ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: .dark(
            primary: colors.primary,
            surface: colors.backgroundCard,
            onSurface: colors.textPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _scheduledDate = picked);
  }

  Future<void> _pickTime(BuildContext context) async {
    final colors = AppColors.of(context);
    final picked = await showTimePicker(
      context: context,
      initialTime: _scheduledTime ?? TimeOfDay.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: .dark(
            primary: colors.primary,
            surface: colors.backgroundCard,
            onSurface: colors.textPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _scheduledTime = picked);
  }

  void _create(BuildContext context) {
    final colors = AppColors.of(context);
    if (!_formKey.currentState!.validate()) return;
    if (_scheduleForLater &&
        (_scheduledDate == null || _scheduledTime == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Pick a date and time for the session'),
          backgroundColor: colors.error,
        ),
      );
      return;
    }
    if (_scheduleForLater && _scheduledAt!.isBefore(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Scheduled time must be in the future'),
          backgroundColor: colors.error,
        ),
      );
      return;
    }

    context.read<SessionsCubit>().createSession(
      title: _titleController.text.trim(),
      type: _type,
      participantIds: _selectedParticipantIds.toList(),
      scheduledAt: _scheduledAt,
      password: _passwordController.text.trim().isEmpty
          ? null
          : _passwordController.text.trim(),
      tagIds: _selectedTags.map((s) => s.id).toList(),
      isPublic: _isPublic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final typography = AppTypography.of(context);
    return Scaffold(
      backgroundColor: colors.backgroundDark,
      body: SafeArea(
        child: BlocListener<SessionsCubit, SessionsState>(
          listener: (context, state) {
            if (state is SessionSaved) {
              context.pop(state.session);
            } else if (state is SessionsError) {
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
                          'New Session',
                          textAlign: .center,
                          style: typography.headlineMedium,
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppTextField(
                    label: 'Title',
                    hint: 'e.g. Midterm Study Group',
                    icon: Icons.title,
                    controller: _titleController,
                    validator: (value) =>
                        (value == null || value.trim().isEmpty)
                        ? 'Title is required'
                        : null,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text('Type', style: typography.labelMedium),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      PillButton(
                        label: 'Text Chat',
                        variant: _type == .text ? .primary : .muted,
                        onPressed: () => setState(() => _type = .text),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      PillButton(
                        label: 'Video Call',
                        variant: _type == .video ? .primary : .muted,
                        onPressed: () => setState(() => _type = .video),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text('Visibility', style: typography.labelMedium),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    _isPublic
                        ? 'Anyone with matching interests can find this on their Home tab.'
                        : 'Only people you invite or share the code with can join.',
                    style: typography.bodySmall,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      PillButton(
                        label: 'Private',
                        variant: !_isPublic ? .primary : .muted,
                        onPressed: () => setState(() => _isPublic = false),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      PillButton(
                        label: 'Public',
                        variant: _isPublic ? .primary : .muted,
                        onPressed: () => setState(() => _isPublic = true),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  TypeaheadChipPicker<Skill>(
                    label: 'Tags',
                    hint: 'e.g. Python, Organic Chemistry',
                    suggestions: _allSkills
                        .where((s) => !_selectedTags.any((t) => t.id == s.id))
                        .toList(),
                    labelOf: (s) => s.name,
                    onSelectExisting: (s) =>
                        setState(() => _selectedTags.add(s)),
                    onCreateNew: _createAndSelectTag,
                    isBusy: _tagsBusy,
                    selectedChips: _selectedTags.map((tag) {
                      return SelectableChip(
                        label: tag.name,
                        selected: true,
                        onTap: () => setState(
                          () =>
                              _selectedTags.removeWhere((t) => t.id == tag.id),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text('When', style: typography.labelMedium),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      PillButton(
                        label: 'Now',
                        variant: !_scheduleForLater ? .primary : .muted,
                        onPressed: () =>
                            setState(() => _scheduleForLater = false),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      PillButton(
                        label: 'Schedule for Later',
                        variant: _scheduleForLater ? .primary : .muted,
                        onPressed: () =>
                            setState(() => _scheduleForLater = true),
                      ),
                    ],
                  ),
                  if (_scheduleForLater) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Expanded(
                          child: SessionPickerField(
                            icon: Icons.calendar_today_outlined,
                            label: _scheduledDate == null
                                ? 'Pick date'
                                : sessionDateLabel(_scheduledDate!),
                            onTap: () => _pickDate(context),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: SessionPickerField(
                            icon: Icons.access_time,
                            label: _scheduledTime == null
                                ? 'Pick time'
                                : _scheduledTime!.format(context),
                            onTap: () => _pickTime(context),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Participants (optional)',
                    style: typography.labelMedium,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Skip this to start solo — you can share an invite link or add people later.',
                    style: typography.bodySmall,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  BlocBuilder<MatchingCubit, MatchingState>(
                    builder: (context, state) {
                      if (state is MatchesInitial || state is MatchesLoading) {
                        return Padding(
                          padding: const .symmetric(vertical: AppSpacing.lg),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: colors.primary,
                            ),
                          ),
                        );
                      }

                      if (state is MatchesError) {
                        return Padding(
                          padding: const .symmetric(vertical: AppSpacing.lg),
                          child: Text(
                            genericErrorMessage,
                            style: typography.bodySmall,
                          ),
                        );
                      }

                      final matches = (state as MatchesLoaded).matches;
                      if (matches.isEmpty) {
                        return Padding(
                          padding: const .symmetric(vertical: AppSpacing.lg),
                          child: Text(
                            'No study partners to invite yet.',
                            style: typography.bodySmall,
                          ),
                        );
                      }

                      return Column(
                        children: matches.map((m) {
                          final isSelected = _selectedParticipantIds.contains(
                            m.userId,
                          );
                          return CheckboxListTile(
                            value: isSelected,
                            onChanged: (checked) => setState(() {
                              if (checked == true) {
                                _selectedParticipantIds.add(m.userId);
                              } else {
                                _selectedParticipantIds.remove(m.userId);
                              }
                            }),
                            activeColor: colors.primary,
                            contentPadding: .zero,
                            controlAffinity: .trailing,
                            title: Row(
                              children: [
                                UserAvatar(
                                  name: m.name,
                                  size: AppSpacing.avatarSm,
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Text(m.name, style: typography.bodyLarge),
                              ],
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppTextField(
                    label: 'Password (optional)',
                    hint: 'Required to join via the share link',
                    icon: Icons.lock_outline,
                    controller: _passwordController,
                    obscurable: true,
                    validator: (value) {
                      final trimmed = value?.trim() ?? '';
                      if (trimmed.isNotEmpty && trimmed.length < 4) {
                        return 'Password must be at least 4 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  BlocBuilder<SessionsCubit, SessionsState>(
                    builder: (context, state) {
                      return PrimaryButton(
                        label: 'Create Session',
                        isLoading: state is SessionSaving,
                        onPressed: () => _create(context),
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
