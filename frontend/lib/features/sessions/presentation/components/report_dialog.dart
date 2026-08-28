import 'package:flutter/material.dart';
import 'package:frontend/core/constants/app_colors.dart';
import 'package:frontend/core/constants/app_spacing.dart';
import 'package:frontend/core/constants/app_typography.dart';
import 'package:frontend/features/sessions/domain/entities/report_reason.dart';

typedef ReportSubmission = ({ReportReason reason, String? details});

class ReportDialog extends StatefulWidget {
  final String title;
  final String description;

  const ReportDialog({
    super.key,
    required this.title,
    required this.description,
  });

  static Future<ReportSubmission?> show(
    BuildContext context, {
    required String title,
    required String description,
  }) {
    return showDialog<ReportSubmission>(
      context: context,
      builder: (_) => ReportDialog(title: title, description: description),
    );
  }

  @override
  State<ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<ReportDialog> {
  ReportReason? _selected;
  final _detailsController = TextEditingController();

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final typography = AppTypography.of(context);

    return AlertDialog(
      backgroundColor: colors.backgroundCard,
      title: Text(widget.title, style: typography.headlineSmall),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.description, style: typography.bodyMedium),
              const SizedBox(height: AppSpacing.sm),
              RadioGroup<ReportReason>(
                groupValue: _selected,
                onChanged: (value) => setState(() => _selected = value),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final reason in ReportReason.values)
                      RadioListTile<ReportReason>(
                        value: reason,
                        title: Text(reason.label, style: typography.bodyMedium),
                        activeColor: colors.primary,
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _detailsController,
                maxLines: 3,
                maxLength: 500,
                style: typography.bodyMedium,
                decoration: InputDecoration(
                  hintText: 'Add details (optional)',
                  hintStyle: typography.bodySmall.copyWith(
                    color: colors.textTertiary,
                  ),
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancel', style: typography.labelMedium),
        ),
        TextButton(
          onPressed: _selected == null
              ? null
              : () {
                  final details = _detailsController.text.trim();
                  Navigator.of(context).pop((
                    reason: _selected!,
                    details: details.isEmpty ? null : details,
                  ));
                },
          child: Text(
            'Submit',
            style: typography.labelMedium.copyWith(color: colors.error),
          ),
        ),
      ],
    );
  }
}
