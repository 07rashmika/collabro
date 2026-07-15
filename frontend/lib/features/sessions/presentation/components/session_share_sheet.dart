import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:share_plus/share_plus.dart';

import 'package:frontend/core/constants/app_colors.dart';
import 'package:frontend/core/constants/app_spacing.dart';
import 'package:frontend/core/constants/app_typography.dart';
import 'package:frontend/core/widgets/primary_button.dart';
import 'package:frontend/features/sessions/domain/entities/study_session.dart';

/// Shown right after creating a session — hands the creator a join code they
/// can copy or push through the OS share sheet to any app (chat, SMS, etc).
/// The app has no verified web domain yet, so this is a code the recipient
/// pastes into "Join via Code" rather than a tap-to-open deep link.
Future<void> showSessionShareSheet(BuildContext context, StudySession session) {
  final colors = AppColors.of(context);
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: colors.backgroundMedium,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusLg)),
    ),
    isScrollControlled: true,
    builder: (sheetContext) => _SessionShareSheet(session: session),
  );
}

class _SessionShareSheet extends StatelessWidget {
  final StudySession session;

  const _SessionShareSheet({required this.session});

  // This sheet only ever appears immediately after the viewer creates the
  // session, so the backend always includes the join code for them.
  String get _joinCode => session.joinCode!;

  String get _shareText {
    final buffer = StringBuffer(
      'Join my study session "${session.title}" on Collabro!\n\nCode: $_joinCode',
    );
    if (session.hasPassword) {
      buffer.write('\n\nThis session is password-protected — ask me for the password.');
    }
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final typography = AppTypography.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.screenHorizontal,
        right: AppSpacing.screenHorizontal,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle, color: colors.success),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text('Session created', style: typography.titleLarge)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Share this code so others can join "${session.title}".',
            style: typography.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.lg),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            decoration: BoxDecoration(
              color: colors.backgroundInput,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(color: colors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _joinCode,
                    style: typography.titleMedium.copyWith(letterSpacing: 1.1),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.copy_outlined, color: colors.textTertiary),
                  tooltip: 'Copy code',
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: _joinCode));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Code copied')),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
          if (session.hasPassword) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Icon(
                  Icons.lock_outline,
                  size: AppSpacing.iconSm,
                  color: colors.textTertiary,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text('Password protected', style: typography.bodySmall),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          PrimaryButton(
            label: 'Share Invite',
            leadingIcon: Icons.ios_share,
            onPressed: () => SharePlus.instance.share(ShareParams(text: _shareText)),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Done',
              style: typography.bodyMedium.copyWith(color: colors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
