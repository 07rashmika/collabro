import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:frontend/core/constants/app_colors.dart';
import 'package:frontend/core/constants/app_spacing.dart';
import 'package:frontend/core/constants/app_typography.dart';
import 'package:frontend/core/utils/session_time_label.dart';
import 'package:frontend/core/widgets/user_avatar.dart';
import 'package:frontend/features/sessions/domain/entities/study_session.dart';
import 'package:frontend/features/sessions/presentation/cubits/sessions_cubit.dart';

/// Session details side panel, opened from the 3-dot menu on both the chat
/// and video call screens. Categorized top to bottom: Overview (topic, type,
/// visibility, created time, tags), Access (join code / password — gated by
/// who's allowed to see what), Participants, and — creator only — Owner
/// Actions. Reads the [SessionsCubit] already provided by the host screen
/// rather than owning one, so "reveal password" shares the same instance.
class SessionInfoPanel extends StatefulWidget {
  final StudySession session;
  final String? currentUserId;
  final VoidCallback? onEndSession;

  const SessionInfoPanel({
    super.key,
    required this.session,
    required this.currentUserId,
    this.onEndSession,
  });

  @override
  State<SessionInfoPanel> createState() => _SessionInfoPanelState();
}

class _SessionInfoPanelState extends State<SessionInfoPanel> {
  String? _revealedPassword;
  bool _passwordRevealed = false;
  bool _loadingPassword = false;

  bool get _isCreator =>
      widget.currentUserId != null && widget.currentUserId == widget.session.creatorId;
  bool get _canSeeCode => _isCreator || widget.session.isPublic;

  void _revealPassword() {
    setState(() => _loadingPassword = true);
    context.read<SessionsCubit>().loadSessionPassword(widget.session.id);
  }

  Future<void> _copyCode() async {
    final code = widget.session.joinCode;
    if (code == null) return;
    await Clipboard.setData(ClipboardData(text: code));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Code copied')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final typography = AppTypography.of(context);
    final session = widget.session;
    final showAccessSection = _canSeeCode || _isCreator;

    return Drawer(
      backgroundColor: colors.backgroundMedium,
      width: MediaQuery.of(context).size.width * 0.86,
      child: BlocListener<SessionsCubit, SessionsState>(
        listener: (context, state) {
          if (state is SessionPasswordViewed) {
            setState(() {
              _revealedPassword = state.password;
              _passwordRevealed = true;
              _loadingPassword = false;
            });
          } else if (state is SessionsError && _loadingPassword) {
            setState(() => _loadingPassword = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: colors.error),
            );
          }
        },
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('Session Info', style: typography.headlineSmall),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close, color: colors.textPrimary),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),

              _SectionLabel('Overview'),
              const SizedBox(height: AppSpacing.sm),
              _InfoCard(
                children: [
                  Text(session.title, style: typography.titleLarge),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      _Badge(
                        icon: session.type == SessionType.video
                            ? Icons.videocam_outlined
                            : Icons.chat_bubble_outline,
                        label: session.type == SessionType.video ? 'Video Call' : 'Text Chat',
                      ),
                      _Badge(
                        icon: session.isPublic ? Icons.public : Icons.lock_outline,
                        label: session.isPublic ? 'Public' : 'Private',
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _IconLabel(
                    icon: Icons.schedule,
                    label: 'Created ${sessionTimeLabel(session.createdAt)}',
                  ),
                  if (session.tags.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: session.tags.map((t) => _TagChip(t.name)).toList(),
                    ),
                  ],
                ],
              ),

              if (showAccessSection) ...[
                const SizedBox(height: AppSpacing.lg),
                _SectionLabel('Access'),
                const SizedBox(height: AppSpacing.sm),
                _InfoCard(
                  children: [
                    if (_canSeeCode) ...[
                      Text('Join Code', style: typography.labelMedium),
                      const SizedBox(height: AppSpacing.xs),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              session.joinCode!,
                              style: typography.bodyMedium.copyWith(letterSpacing: 1.1),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.copy_outlined,
                              size: AppSpacing.iconSm,
                              color: colors.textTertiary,
                            ),
                            visualDensity: VisualDensity.compact,
                            onPressed: _copyCode,
                          ),
                        ],
                      ),
                    ],
                    if (_isCreator) ...[
                      if (_canSeeCode)
                        Divider(color: colors.border, height: AppSpacing.lg),
                      Text('Password', style: typography.labelMedium),
                      const SizedBox(height: AppSpacing.xs),
                      if (!session.hasPassword)
                        Text('No password set', style: typography.bodySmall)
                      else if (_passwordRevealed)
                        Text(
                          _revealedPassword ?? '—',
                          style: typography.bodyMedium.copyWith(letterSpacing: 1.1),
                        )
                      else
                        TextButton.icon(
                          onPressed: _loadingPassword ? null : _revealPassword,
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          icon: _loadingPassword
                              ? SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: colors.primary,
                                  ),
                                )
                              : Icon(
                                  Icons.visibility_outlined,
                                  size: AppSpacing.iconSm,
                                  color: colors.primary,
                                ),
                          label: Text(
                            'Reveal password',
                            style: typography.bodyMedium.copyWith(color: colors.primary),
                          ),
                        ),
                    ],
                  ],
                ),
              ],

              const SizedBox(height: AppSpacing.lg),
              _SectionLabel('Participants (${session.participants.length})'),
              const SizedBox(height: AppSpacing.sm),
              _InfoCard(
                children: [
                  for (final p in session.participants) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                      child: Row(
                        children: [
                          UserAvatar(name: p.name, size: AppSpacing.avatarSm),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              p.name,
                              style: typography.bodyMedium,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (p.userId == session.creatorId)
                            const _Badge(icon: Icons.star, label: 'Host'),
                        ],
                      ),
                    ),
                  ],
                ],
              ),

              if (_isCreator && widget.onEndSession != null) ...[
                const SizedBox(height: AppSpacing.lg),
                _SectionLabel('Owner Actions'),
                const SizedBox(height: AppSpacing.sm),
                _InfoCard(
                  children: [
                    TextButton.icon(
                      onPressed: widget.onEndSession,
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      icon: Icon(Icons.stop_circle_outlined, color: colors.error),
                      label: Text(
                        'End Session Permanently',
                        style: typography.bodyMedium.copyWith(color: colors.error),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final typography = AppTypography.of(context);
    return Text(
      label.toUpperCase(),
      style: typography.labelSmall.copyWith(
        color: colors.textTertiary,
        letterSpacing: 0.6,
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final List<Widget> children;
  const _InfoCard({required this.children});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: colors.backgroundCard,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: colors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }
}

class _Badge extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Badge({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final typography = AppTypography.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
      decoration: BoxDecoration(
        color: colors.backgroundElevated,
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: AppSpacing.iconSm, color: colors.primaryLight),
          const SizedBox(width: 4),
          Text(label, style: typography.labelSmall),
        ],
      ),
    );
  }
}

class _IconLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  const _IconLabel({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final typography = AppTypography.of(context);
    return Row(
      children: [
        Icon(icon, size: AppSpacing.iconSm, color: colors.textTertiary),
        const SizedBox(width: AppSpacing.xs),
        Text(label, style: typography.bodySmall),
      ],
    );
  }
}

class _TagChip extends StatelessWidget {
  final String label;
  const _TagChip(this.label);

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final typography = AppTypography.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
      decoration: BoxDecoration(
        color: colors.chipBackground,
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        border: Border.all(color: colors.chipBorder),
      ),
      child: Text(label, style: typography.labelSmall),
    );
  }
}
