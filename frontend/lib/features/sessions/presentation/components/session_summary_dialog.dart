import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:frontend/core/constants/app_colors.dart';
import 'package:frontend/core/constants/app_spacing.dart';
import 'package:frontend/core/constants/app_typography.dart';
import 'package:frontend/features/sessions/domain/entities/study_session.dart';
import 'package:frontend/features/sessions/domain/repos/sessions_repo.dart';

/// Asks whether the caller wants an AI summary of a session that just
/// ended, then runs [showSessionSummaryDialog] if they say yes. Used right
/// before navigating away once a session closes (manually or by expiry).
Future<void> maybeOfferSessionSummary(BuildContext context, StudySession session) async {
  final colors = AppColors.of(context);
  final typography = AppTypography.of(context);
  final wantsSummary = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: colors.backgroundCard,
      title: Text('Session ended', style: typography.titleMedium),
      content: Text(
        'Would you like an AI-generated summary of this session?',
        style: typography.bodyMedium,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Not now'),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text('Summarize', style: TextStyle(color: colors.primary)),
        ),
      ],
    ),
  );

  if (wantsSummary == true && context.mounted) {
    await showSessionSummaryDialog(context, session);
  }
}

/// Shows the session's summary, generating it first if there isn't one yet.
/// Used both after [maybeOfferSessionSummary] says yes, and directly from
/// the "Summary" button on an ended session in the sessions list.
Future<void> showSessionSummaryDialog(BuildContext context, StudySession session) {
  return showDialog<void>(
    context: context,
    builder: (_) => _SessionSummaryDialog(
      sessionId: session.id,
      initialSummary: session.summary,
    ),
  );
}

class _SessionSummaryDialog extends StatefulWidget {
  final String sessionId;
  final String? initialSummary;

  const _SessionSummaryDialog({required this.sessionId, required this.initialSummary});

  @override
  State<_SessionSummaryDialog> createState() => _SessionSummaryDialogState();
}

class _SessionSummaryDialogState extends State<_SessionSummaryDialog> {
  String? _summary;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _summary = widget.initialSummary;
    if (_summary == null) _generate();
  }

  Future<void> _generate() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final session = await context.read<SessionsRepo>().generateSummary(widget.sessionId);
      if (!mounted) return;
      setState(() {
        _summary = session.summary;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final typography = AppTypography.of(context);
    return AlertDialog(
      backgroundColor: colors.backgroundCard,
      title: Row(
        children: [
          Icon(Icons.auto_awesome, color: colors.primary, size: AppSpacing.iconMd),
          const SizedBox(width: AppSpacing.xs),
          Text('Session Summary', style: typography.titleMedium),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: _loading
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                child: Center(child: CircularProgressIndicator(color: colors.primary)),
              )
            : _error != null
                ? Text(_error!, style: typography.bodyMedium.copyWith(color: colors.error))
                : SingleChildScrollView(
                    child: Text(
                      _summary ?? 'No summary available.',
                      style: typography.bodyMedium,
                    ),
                  ),
      ),
      actions: [
        if (!_loading)
          TextButton(
            onPressed: _generate,
            child: Text('Regenerate', style: TextStyle(color: colors.primaryLight)),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
