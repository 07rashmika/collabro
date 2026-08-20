import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/core/constants/app_colors.dart';
import 'package:frontend/core/constants/app_spacing.dart';
import 'package:frontend/core/constants/app_typography.dart';
import 'package:frontend/core/utils/session_time_label.dart';
import 'package:frontend/core/utils/snackbar_utils.dart';
import 'package:frontend/core/widgets/danger_button.dart';
import 'package:frontend/core/widgets/user_avatar.dart';
import 'package:frontend/features/sessions/domain/entities/study_session.dart';
import 'package:frontend/features/sessions/presentation/components/session_info_badge.dart';
import 'package:frontend/features/sessions/presentation/components/session_info_card.dart';
import 'package:frontend/features/sessions/presentation/components/session_info_icon_label.dart';
import 'package:frontend/features/sessions/presentation/components/session_info_section_label.dart';
import 'package:frontend/features/sessions/presentation/components/session_tag_chip.dart';
import 'package:frontend/features/sessions/presentation/cubits/sessions_cubit.dart';

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
  late final List<SessionParticipant> _participants;
  String? _removingUserId;

  @override
  void initState() {
    super.initState();
    _participants = [...widget.session.participants];
  }

  bool get _isCreator =>
      widget.currentUserId != null &&
      widget.currentUserId == widget.session.creatorId;
  bool get _canSeeCode => _isCreator || widget.session.isPublic;

  void _revealPassword() {
    setState(() => _loadingPassword = true);
    context.read<SessionsCubit>().loadSessionPassword(widget.session.id);
  }

  void _confirmRemoveParticipant(
    String sessionId,
    String userId,
    String userName,
  ) {
    final colors = AppColors.of(context);
    final typography = AppTypography.of(context);
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: colors.backgroundCard,
        title: Text('Remove participant?', style: typography.headlineSmall),
        content: Text(
          '$userName will be removed from this session and will need a new invite or the join code to come back.',
          style: typography.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text('Cancel', style: typography.labelMedium),
          ),
          DangerButton(
            label: 'Remove',
            onPressed: () {
              Navigator.of(dialogContext).pop();
              setState(() => _removingUserId = userId);
              context.read<SessionsCubit>().removeParticipant(
                sessionId,
                userId,
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _copyCode() async {
    final code = widget.session.joinCode;
    if (code == null) return;
    await Clipboard.setData(ClipboardData(text: code));
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Code copied')));
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
          } else if (state is ParticipantRemoved &&
              state.sessionId == widget.session.id) {
            setState(() {
              _participants.removeWhere((p) => p.userId == state.userId);
              _removingUserId = null;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Participant removed')),
            );
          } else if (state is SessionsError && _loadingPassword) {
            setState(() => _loadingPassword = false);
            showErrorSnackBar(context, state.message);
          } else if (state is SessionsError && _removingUserId != null) {
            setState(() => _removingUserId = null);
            showErrorSnackBar(context, state.message);
          }
        },
        child: SafeArea(
          child: ListView(
            padding: const .all(AppSpacing.screenHorizontal),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Session Info',
                      style: typography.headlineSmall,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close, color: colors.textPrimary),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),

              SessionInfoSectionLabel('Overview'),
              const SizedBox(height: AppSpacing.sm),
              SessionInfoCard(
                children: [
                  Text(session.title, style: typography.titleLarge),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      SessionInfoBadge(
                        icon: session.type == .video
                            ? Icons.videocam_outlined
                            : Icons.chat_bubble_outline,
                        label: session.type == .video
                            ? 'Video Call'
                            : 'Text Chat',
                      ),
                      SessionInfoBadge(
                        icon: session.isPublic
                            ? Icons.public
                            : Icons.lock_outline,
                        label: session.isPublic ? 'Public' : 'Private',
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  SessionInfoIconLabel(
                    icon: Icons.schedule,
                    label: 'Created ${sessionTimeLabel(session.createdAt)}',
                  ),
                  if (session.status == .active) ...[
                    const SizedBox(height: AppSpacing.xs),
                    SessionInfoIconLabel(
                      icon: Icons.timer_outlined,
                      label: 'Expires ${sessionTimeLabel(session.expiresAt)}',
                    ),
                  ],
                  if (session.tags.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: session.tags
                          .map((t) => SessionTagChip(t.name))
                          .toList(),
                    ),
                  ],
                ],
              ),

              if (showAccessSection) ...[
                const SizedBox(height: AppSpacing.lg),
                SessionInfoSectionLabel('Access'),
                const SizedBox(height: AppSpacing.sm),
                SessionInfoCard(
                  children: [
                    if (_canSeeCode) ...[
                      Text('Join Code', style: typography.labelMedium),
                      const SizedBox(height: AppSpacing.xs),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              session.joinCode!,
                              style: typography.bodyMedium.copyWith(
                                letterSpacing: 1.1,
                              ),
                              overflow: .ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.copy_outlined,
                              size: AppSpacing.iconSm,
                              color: colors.textTertiary,
                            ),
                            visualDensity: .compact,
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
                          style: typography.bodyMedium.copyWith(
                            letterSpacing: 1.1,
                          ),
                        )
                      else
                        TextButton.icon(
                          onPressed: _loadingPassword ? null : _revealPassword,
                          style: TextButton.styleFrom(
                            padding: .zero,
                            minimumSize: .zero,
                            tapTargetSize: .shrinkWrap,
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
                            style: typography.bodyMedium.copyWith(
                              color: colors.primary,
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
              ],

              const SizedBox(height: AppSpacing.lg),
              SessionInfoSectionLabel('Participants (${_participants.length})'),
              const SizedBox(height: AppSpacing.sm),
              SessionInfoCard(
                children: [
                  for (final p in _participants) ...[
                    Padding(
                      padding: const .symmetric(vertical: AppSpacing.xs),
                      child: Row(
                        children: [
                          UserAvatar(
                            name: p.name,
                            imageUrl: p.avatarUrl,
                            size: AppSpacing.avatarSm,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              p.name,
                              style: typography.bodyMedium,
                              overflow: .ellipsis,
                            ),
                          ),
                          if (p.userId == session.creatorId)
                            const SessionInfoBadge(
                              icon: Icons.star,
                              label: 'Host',
                            )
                          else if (_isCreator)
                            IconButton(
                              onPressed: _removingUserId != null
                                  ? null
                                  : () => _confirmRemoveParticipant(
                                      session.id,
                                      p.userId,
                                      p.name,
                                    ),
                              icon: _removingUserId == p.userId
                                  ? SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: colors.error,
                                      ),
                                    )
                                  : Icon(
                                      Icons.person_remove_outlined,
                                      size: AppSpacing.iconSm,
                                      color: colors.error,
                                    ),
                              visualDensity: .compact,
                              tooltip: 'Remove participant',
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),

              if (_isCreator && widget.onEndSession != null) ...[
                const SizedBox(height: AppSpacing.lg),
                SessionInfoSectionLabel('Owner Actions'),
                const SizedBox(height: AppSpacing.sm),
                SessionInfoCard(
                  children: [
                    TextButton.icon(
                      onPressed: widget.onEndSession,
                      style: TextButton.styleFrom(
                        padding: .zero,
                        minimumSize: Size.zero,
                        tapTargetSize: .shrinkWrap,
                      ),
                      icon: Icon(
                        Icons.stop_circle_outlined,
                        color: colors.error,
                      ),
                      label: Text(
                        'End Session Permanently',
                        style: typography.bodyMedium.copyWith(
                          color: colors.error,
                        ),
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
