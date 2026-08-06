import 'dart:io' show File, Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:go_router/go_router.dart';

import 'package:frontend/core/constants/app_colors.dart';
import 'package:frontend/core/constants/app_routes.dart';
import 'package:frontend/core/constants/app_spacing.dart';
import 'package:frontend/core/constants/app_typography.dart';
import 'package:frontend/core/widgets/primary_button.dart';
import 'package:frontend/features/auth/domain/repos/auth_repo.dart';
import 'package:frontend/features/sessions/data/services/chat_socket_service.dart';
import 'package:frontend/features/sessions/data/services/signaling_service.dart';
import 'package:frontend/features/sessions/data/services/webrtc_service.dart';
import 'package:frontend/features/sessions/domain/entities/call_participant.dart';
import 'package:frontend/features/sessions/domain/entities/session_message.dart';
import 'package:frontend/features/sessions/domain/entities/study_session.dart';
import 'package:frontend/features/sessions/domain/repos/sessions_repo.dart';
import 'package:frontend/features/sessions/presentation/components/session_info_panel.dart';
import 'package:frontend/features/sessions/presentation/components/session_summary_dialog.dart';
import 'package:frontend/features/sessions/presentation/cubits/session_chat_cubit.dart';
import 'package:frontend/features/sessions/presentation/cubits/sessions_cubit.dart';
import 'package:frontend/features/sessions/presentation/cubits/video_call_cubit.dart';

bool get _isIOS => !kIsWeb && Platform.isIOS;

/// Owns the WebRTC/signaling connection lifecycle for one call: constructs a
/// single [SignalingService] shared by [VideoCallCubit] (call) and
/// [SessionChatCubit] (optional chat drawer, same socket, multiplexed by
/// message `type`), and closes both Cubits (each disposal is idempotent) on
/// teardown.
class VideoCallScreen extends StatefulWidget {
  final StudySession session;

  const VideoCallScreen({super.key, required this.session});

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  late final SignalingService _signalingService;
  late final VideoCallCubit _videoCallCubit;
  late final SessionChatCubit _sessionChatCubit;
  late final SessionsCubit _sessionsCubit;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    final storage = context.read<FlutterSecureStorage>();
    final sessionsRepo = context.read<SessionsRepo>();

    _signalingService = SignalingService(
      storage: storage,
      sessionId: widget.session.id,
    );

    _videoCallCubit = VideoCallCubit(
      webRTCService: WebRTCService(),
      signalingService: _signalingService,
      sessionsRepo: sessionsRepo,
      sessionId: widget.session.id,
    )..start();

    _sessionChatCubit = SessionChatCubit(
      chatSocketService: ChatSocketService(signalingService: _signalingService),
      signalingService: _signalingService,
      sessionsRepo: sessionsRepo,
      authRepo: context.read<AuthRepo>(),
      sessionId: widget.session.id,
    )..start();

    _sessionsCubit = SessionsCubit(sessionsRepo: sessionsRepo);

    context.read<AuthRepo>().getCurrentUser().then((user) {
      if (mounted) setState(() => _currentUserId = user?.id);
      // Only the creator's device records the call (see WebRTCService) —
      // avoids every participant uploading a duplicate of the same audio.
      // This resolves after the call may already be connecting (it's a
      // network fetch), which is fine: enableRecording() picks up local
      // media whenever it's ready, in either order.
      if (user?.id == widget.session.creatorId) {
        _videoCallCubit.webRTCService.enableRecording();
      }
    });
  }

  @override
  void dispose() {
    _videoCallCubit.close();
    _sessionChatCubit.close();
    _sessionsCubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: _videoCallCubit),
        BlocProvider.value(value: _sessionChatCubit),
        BlocProvider.value(value: _sessionsCubit),
      ],
      child: _VideoCallView(
        session: widget.session,
        currentUserId: _currentUserId,
      ),
    );
  }
}

class _VideoCallView extends StatefulWidget {
  final StudySession session;
  final String? currentUserId;

  const _VideoCallView({required this.session, required this.currentUserId});

  @override
  State<_VideoCallView> createState() => _VideoCallViewState();
}

class _VideoCallViewState extends State<_VideoCallView> {
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final Map<String, RTCVideoRenderer> _remoteRenderers = {};
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _localRendererReady = false;
  bool _showChat = false;

  // The session-ended signal can reach this device two ways for the same
  // close (the HTTP response to closeSession -> SessionsCubit's
  // SessionSaved, and the signaling broadcast every room member gets ->
  // VideoCallCubit's CallDisconnected(sessionEnded: true)) — whichever
  // fires first stops the recording, uploads it (if this device recorded),
  // and offers the summary; this guards the second firing into a no-op.
  bool _summaryHandled = false;

  Future<void> _handleSessionEndSummary(StudySession fallbackSession) async {
    if (_summaryHandled) return;
    _summaryHandled = true;

    final webRTCService = context.read<VideoCallCubit>().webRTCService;
    await webRTCService.finishRecording();
    if (!mounted) return;

    var session = fallbackSession;
    if (webRTCService.recordedTracks.isNotEmpty) {
      try {
        session = await context.read<SessionsRepo>().uploadRecording(
          fallbackSession.id,
          [
            for (final track in webRTCService.recordedTracks)
              (path: track.path, label: track.label, startedAt: track.startedAt),
          ],
        );
        // The backend deletes its copy once transcription finishes (see
        // processRecording's cleanup()) — mirror that here so the raw audio
        // doesn't linger in this device's temp dir once it's no longer
        // needed. Left in place on a failed upload in case it's worth
        // retrying later.
        for (final track in webRTCService.recordedTracks) {
          File(track.path).delete().ignore();
        }
      } catch (_) {
        // Best-effort — fall back to showing whatever summary already exists.
      }
    }
    if (!mounted) return;
    await maybeOfferSessionSummary(context, session);
  }

  @override
  void initState() {
    super.initState();
    _localRenderer.initialize().then((_) {
      if (!mounted) return;
      setState(() => _localRendererReady = true);
      final state = context.read<VideoCallCubit>().state;
      if (state is ActiveCallState) {
        _localRenderer.srcObject = state.localStream;
      }
    });
  }

  @override
  void dispose() {
    _localRenderer.dispose();
    for (final renderer in _remoteRenderers.values) {
      renderer.dispose();
    }
    super.dispose();
  }

  Future<void> _syncRemoteRenderers(
    Map<String, MediaStream> remoteStreams,
  ) async {
    for (final entry in remoteStreams.entries) {
      final existing = _remoteRenderers[entry.key];
      if (existing == null) {
        final renderer = RTCVideoRenderer();
        await renderer.initialize();
        renderer.srcObject = entry.value;
        if (!mounted) {
          await renderer.dispose();
          return;
        }
        setState(() => _remoteRenderers[entry.key] = renderer);
      } else if (existing.srcObject != entry.value) {
        existing.srcObject = entry.value;
      }
    }

    final removedKeys = _remoteRenderers.keys
        .where((key) => !remoteStreams.containsKey(key))
        .toList();
    for (final key in removedKeys) {
      final renderer = _remoteRenderers.remove(key);
      await renderer?.dispose();
    }
    if (removedKeys.isNotEmpty && mounted) setState(() {});
  }

  Future<void> _confirmEndSession(BuildContext context) async {
    final colors = AppColors.of(context);
    final typography = AppTypography.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: colors.backgroundCard,
        title: Text(
          'End session permanently?',
          style: typography.titleMedium,
        ),
        content: Text(
          'This closes the session for everyone and can\'t be undone.',
          style: typography.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              'End Session',
              style: TextStyle(color: colors.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      context.read<SessionsCubit>().closeSession(widget.session.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final typography = AppTypography.of(context);
    final isCreator =
        widget.currentUserId != null &&
        widget.currentUserId == widget.session.creatorId;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: colors.backgroundDark,
      endDrawer: SessionInfoPanel(
        session: widget.session,
        currentUserId: widget.currentUserId,
        onEndSession: isCreator ? () => _confirmEndSession(context) : null,
      ),
      body: SafeArea(
        child: BlocListener<SessionsCubit, SessionsState>(
          listener: (context, state) async {
            if (state is SessionSaved) {
              await _handleSessionEndSummary(state.session);
              if (!context.mounted) return;
              context.read<VideoCallCubit>().hangUp();
            } else if (state is SessionsError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: colors.error,
                ),
              );
            }
          },
          child: Stack(
            children: [
              BlocConsumer<VideoCallCubit, VideoCallState>(
                listener: (context, state) async {
                  if (state is ActiveCallState) {
                    if (_localRendererReady &&
                        _localRenderer.srcObject != state.localStream) {
                      _localRenderer.srcObject = state.localStream;
                    }
                    _syncRemoteRenderers(state.remoteStreams);
                  }
                  if (state is CallError) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(state.message),
                        backgroundColor: colors.error,
                      ),
                    );
                  }
                  if (state is CallDisconnected) {
                    if (state.sessionEnded) {
                      await _handleSessionEndSummary(widget.session);
                      if (!context.mounted) return;
                    }
                    // A plain pop isn't reliable here: this listener can fire
                    // while the session-info end drawer is still open (the
                    // "End Session Permanently" button lives inside it), and
                    // Navigator.pop() closes an open drawer first rather than
                    // the route — leaving the now-dead call screen on screen.
                    // Going straight to the Sessions tab sidesteps that.
                    context.go(AppRoutes.sessions);
                  }
                },
                builder: (context, state) {
                  if (state is CallConnecting) {
                    return Center(
                      child: CircularProgressIndicator(
                        color: colors.primary,
                      ),
                    );
                  }

                  if (state is CallError) {
                    return Padding(
                      padding: const EdgeInsets.all(
                        AppSpacing.screenHorizontal,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.videocam_off_outlined,
                            color: colors.error,
                            size: 48,
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          Text(
                            state.message,
                            textAlign: TextAlign.center,
                            style: typography.bodyMedium,
                          ),
                          const SizedBox(height: AppSpacing.xl),
                          PrimaryButton(
                            label: 'Go Back',
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                    );
                  }

                  if (state is ActiveCallState) {
                    return _buildActiveCall(context, state);
                  }

                  return const SizedBox.shrink();
                },
              ),
              Positioned(
                top: AppSpacing.sm,
                right: AppSpacing.sm,
                child: IconButton(
                  onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
                  tooltip: 'Session info',
                  icon: Icon(
                    Icons.more_vert,
                    color: colors.textPrimary,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: colors.overlay,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActiveCall(BuildContext context, ActiveCallState state) {
    return Stack(
      children: [
        Column(
          children: [
            if (state.isReconnecting) _buildReconnectingBanner(context),
            Expanded(child: _buildVideoGrid(context, state)),
            _buildControls(context, state),
          ],
        ),
        if (_showChat) _buildChatDrawer(context),
      ],
    );
  }

  Widget _buildReconnectingBanner(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      width: double.infinity,
      color: colors.warning,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: const Text(
        'Reconnecting…',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildVideoGrid(BuildContext context, ActiveCallState state) {
    final colors = AppColors.of(context);
    final typography = AppTypography.of(context);
    final remoteEntries = _remoteRenderers.entries.toList();
    final isSharingScreen = state is ScreenSharing;

    if (remoteEntries.isEmpty) {
      // Nobody else has joined yet — show the local feed (camera or screen
      // share) as the main tile instead of burying it in a small corner PIP,
      // so screen sharing solo is actually visible while you set things up.
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          children: [
            Expanded(
              child: _localRendererReady
                  ? _buildVideoTile(
                      context,
                      renderer: _localRenderer,
                      participant: CallParticipant(
                        userId: 'local',
                        name: 'You',
                        isMicMuted: state.isMicMuted,
                        isCameraOff: state.isCameraOff,
                        isScreenSharing: isSharingScreen,
                      ),
                      mirror: !isSharingScreen,
                    )
                  : Center(
                      child: CircularProgressIndicator(color: colors.primary),
                    ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text('Waiting for others to join…', style: typography.bodyMedium),
          ],
        ),
      );
    }

    return Stack(
      children: [
        GridView.builder(
          padding: const EdgeInsets.all(AppSpacing.sm),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: switch (remoteEntries.length) {
              1 => 1,
              2 || 3 || 4 => 2,
              _ => 3,
            },
            mainAxisSpacing: AppSpacing.sm,
            crossAxisSpacing: AppSpacing.sm,
            childAspectRatio: 3 / 4,
          ),
          itemCount: remoteEntries.length,
          itemBuilder: (context, i) {
            final userId = remoteEntries[i].key;
            final renderer = remoteEntries[i].value;
            final participant = _findParticipant(state.participants, userId);
            return _buildVideoTile(
              context,
              renderer: renderer,
              participant: participant,
              mirror: false,
            );
          },
        ),
        if (_localRendererReady)
          Positioned(
            right: AppSpacing.md,
            bottom: AppSpacing.md,
            width: 100,
            height: 140,
            child: _buildVideoTile(
              context,
              renderer: _localRenderer,
              participant: CallParticipant(
                userId: 'local',
                name: 'You',
                isMicMuted: state.isMicMuted,
                isCameraOff: state.isCameraOff,
                isScreenSharing: isSharingScreen,
              ),
              mirror: !isSharingScreen,
            ),
          ),
      ],
    );
  }

  CallParticipant? _findParticipant(
    List<CallParticipant> participants,
    String userId,
  ) {
    for (final p in participants) {
      if (p.userId == userId) return p;
    }
    return null;
  }

  Widget _buildVideoTile(
    BuildContext context, {
    required RTCVideoRenderer renderer,
    required CallParticipant? participant,
    required bool mirror,
  }) {
    final colors = AppColors.of(context);
    final typography = AppTypography.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: Container(
        decoration: BoxDecoration(
          color: colors.backgroundCard,
          border: Border.all(color: colors.border, width: 1.5),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (participant?.isCameraOff != true)
              RTCVideoView(
                renderer,
                mirror: mirror,
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
              )
            else
              Center(
                child: Icon(
                  Icons.videocam_off,
                  color: colors.textTertiary,
                  size: 32,
                ),
              ),
            if (participant != null)
              Positioned(
                left: AppSpacing.xs,
                bottom: AppSpacing.xs,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xs,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: colors.overlay,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusXs),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (participant.isMicMuted)
                        const Icon(
                          Icons.mic_off,
                          color: Colors.white,
                          size: AppSpacing.iconSm,
                        ),
                      if (participant.isScreenSharing)
                        const Padding(
                          padding: EdgeInsets.only(left: 2),
                          child: Icon(
                            Icons.screen_share,
                            color: Colors.white,
                            size: AppSpacing.iconSm,
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.only(left: 2),
                        child: Text(
                          participant.name,
                          style: typography.caption.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildControls(BuildContext context, ActiveCallState state) {
    final colors = AppColors.of(context);
    final cubit = context.read<VideoCallCubit>();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _controlButton(
            context,
            icon: state.isMicMuted ? Icons.mic_off : Icons.mic,
            active: !state.isMicMuted,
            onPressed: cubit.toggleMic,
          ),
          _controlButton(
            context,
            icon: state.isCameraOff ? Icons.videocam_off : Icons.videocam,
            active: !state.isCameraOff,
            onPressed: cubit.toggleCamera,
          ),
          if (!_isIOS)
            _controlButton(
              context,
              icon: Icons.screen_share,
              active: state is ScreenSharing,
              onPressed: () {
                if (state is ScreenSharing) {
                  cubit.stopScreenShare();
                } else {
                  cubit.startScreenShare();
                }
              },
            )
          else
            _controlButton(
              context,
              icon: Icons.screen_share_outlined,
              active: false,
              onPressed: null,
              tooltip: 'Screen share isn\'t supported on iOS yet',
            ),
          _controlButton(
            context,
            icon: Icons.chat_bubble_outline,
            active: _showChat,
            onPressed: () => setState(() => _showChat = !_showChat),
          ),
          _controlButton(
            context,
            icon: Icons.call_end,
            active: false,
            backgroundColor: colors.error,
            onPressed: cubit.hangUp,
          ),
        ],
      ),
    );
  }

  Widget _controlButton(
    BuildContext context, {
    required IconData icon,
    required bool active,
    VoidCallback? onPressed,
    Color? backgroundColor,
    String? tooltip,
  }) {
    final colors = AppColors.of(context);
    final button = IconButton(
      onPressed: onPressed,
      icon: Icon(icon, color: Colors.white),
      style: IconButton.styleFrom(
        backgroundColor:
            backgroundColor ??
            (active ? colors.primary : colors.backgroundElevated),
        shape: const CircleBorder(),
        padding: const EdgeInsets.all(AppSpacing.md),
      ),
    );
    return tooltip != null ? Tooltip(message: tooltip, child: button) : button;
  }

  Widget _buildChatDrawer(BuildContext context) {
    final colors = AppColors.of(context);
    final typography = AppTypography.of(context);
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      height: MediaQuery.of(context).size.height * 0.45,
      child: Container(
        decoration: BoxDecoration(
          color: colors.backgroundMedium,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppSpacing.radiusLg),
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Chat', style: typography.titleLarge),
                  IconButton(
                    onPressed: () => setState(() => _showChat = false),
                    icon: Icon(Icons.close, color: colors.textPrimary),
                  ),
                ],
              ),
            ),
            Expanded(
              child: BlocBuilder<SessionChatCubit, SessionChatState>(
                builder: (context, chatState) {
                  if (chatState is! ChatConnected) {
                    return Center(
                      child: CircularProgressIndicator(
                        color: colors.primary,
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                    ),
                    itemCount: chatState.messages.length,
                    itemBuilder: (context, i) {
                      final message = chatState.messages[i];
                      return _CompactMessageRow(
                        message: message,
                        isMine: message.senderId == chatState.currentUserId,
                      );
                    },
                  );
                },
              ),
            ),
            _buildChatInput(context),
          ],
        ),
      ),
    );
  }

  Widget _buildChatInput(BuildContext context) {
    final colors = AppColors.of(context);
    final typography = AppTypography.of(context);
    final controller = TextEditingController();
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              style: typography.bodyMedium.copyWith(
                color: colors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: 'Message…',
                filled: true,
                fillColor: colors.backgroundInput,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (text) {
                if (text.trim().isEmpty) return;
                context.read<SessionChatCubit>().sendMessage(text.trim());
                controller.clear();
              },
            ),
          ),
          IconButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isEmpty) return;
              context.read<SessionChatCubit>().sendMessage(text);
              controller.clear();
            },
            icon: Icon(Icons.send, color: colors.primary),
          ),
        ],
      ),
    );
  }
}

class _CompactMessageRow extends StatelessWidget {
  final SessionMessage message;
  final bool isMine;

  const _CompactMessageRow({required this.message, required this.isMine});

  @override
  Widget build(BuildContext context) {
    final typography = AppTypography.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Align(
        alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
        child: Text(
          isMine
              ? message.content
              : '${message.senderName}: ${message.content}',
          style: typography.bodySmall,
        ),
      ),
    );
  }
}
