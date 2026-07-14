import 'dart:io' show Platform;

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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.backgroundCard,
        title: const Text(
          'End session permanently?',
          style: AppTypography.titleMedium,
        ),
        content: const Text(
          'This closes the session for everyone and can\'t be undone.',
          style: AppTypography.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(
              'End Session',
              style: TextStyle(color: AppColors.error),
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
    final isCreator =
        widget.currentUserId != null &&
        widget.currentUserId == widget.session.creatorId;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.backgroundDark,
      endDrawer: SessionInfoPanel(
        session: widget.session,
        currentUserId: widget.currentUserId,
        onEndSession: isCreator ? () => _confirmEndSession(context) : null,
      ),
      body: SafeArea(
        child: BlocListener<SessionsCubit, SessionsState>(
          listener: (context, state) {
            if (state is SessionSaved) {
              context.read<VideoCallCubit>().hangUp();
            } else if (state is SessionsError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: AppColors.error,
                ),
              );
            }
          },
          child: Stack(
            children: [
              BlocConsumer<VideoCallCubit, VideoCallState>(
                listener: (context, state) {
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
                        backgroundColor: AppColors.error,
                      ),
                    );
                  }
                  if (state is CallDisconnected) {
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
                    return const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
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
                          const Icon(
                            Icons.videocam_off_outlined,
                            color: AppColors.error,
                            size: 48,
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          Text(
                            state.message,
                            textAlign: TextAlign.center,
                            style: AppTypography.bodyMedium,
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
                  icon: const Icon(
                    Icons.more_vert,
                    color: AppColors.textPrimary,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.overlay,
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
            if (state.isReconnecting) _buildReconnectingBanner(),
            Expanded(child: _buildVideoGrid(state)),
            _buildControls(context, state),
          ],
        ),
        if (_showChat) _buildChatDrawer(context),
      ],
    );
  }

  Widget _buildReconnectingBanner() {
    return Container(
      width: double.infinity,
      color: AppColors.warning,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: const Text(
        'Reconnecting…',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildVideoGrid(ActiveCallState state) {
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
                  : const Center(
                      child: CircularProgressIndicator(color: AppColors.primary),
                    ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text('Waiting for others to join…', style: AppTypography.bodyMedium),
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

  Widget _buildVideoTile({
    required RTCVideoRenderer renderer,
    required CallParticipant? participant,
    required bool mirror,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.backgroundCard,
          border: Border.all(color: AppColors.border, width: 1.5),
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
              const Center(
                child: Icon(
                  Icons.videocam_off,
                  color: AppColors.textTertiary,
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
                    color: AppColors.overlay,
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
                          style: AppTypography.caption.copyWith(
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
    final cubit = context.read<VideoCallCubit>();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _controlButton(
            icon: state.isMicMuted ? Icons.mic_off : Icons.mic,
            active: !state.isMicMuted,
            onPressed: cubit.toggleMic,
          ),
          _controlButton(
            icon: state.isCameraOff ? Icons.videocam_off : Icons.videocam,
            active: !state.isCameraOff,
            onPressed: cubit.toggleCamera,
          ),
          if (!_isIOS)
            _controlButton(
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
              icon: Icons.screen_share_outlined,
              active: false,
              onPressed: null,
              tooltip: 'Screen share isn\'t supported on iOS yet',
            ),
          _controlButton(
            icon: Icons.chat_bubble_outline,
            active: _showChat,
            onPressed: () => setState(() => _showChat = !_showChat),
          ),
          _controlButton(
            icon: Icons.call_end,
            active: false,
            backgroundColor: AppColors.error,
            onPressed: cubit.hangUp,
          ),
        ],
      ),
    );
  }

  Widget _controlButton({
    required IconData icon,
    required bool active,
    VoidCallback? onPressed,
    Color? backgroundColor,
    String? tooltip,
  }) {
    final button = IconButton(
      onPressed: onPressed,
      icon: Icon(icon, color: Colors.white),
      style: IconButton.styleFrom(
        backgroundColor:
            backgroundColor ??
            (active ? AppColors.primary : AppColors.backgroundElevated),
        shape: const CircleBorder(),
        padding: const EdgeInsets.all(AppSpacing.md),
      ),
    );
    return tooltip != null ? Tooltip(message: tooltip, child: button) : button;
  }

  Widget _buildChatDrawer(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      height: MediaQuery.of(context).size.height * 0.45,
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.backgroundMedium,
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
                  const Text('Chat', style: AppTypography.titleLarge),
                  IconButton(
                    onPressed: () => setState(() => _showChat = false),
                    icon: const Icon(Icons.close, color: AppColors.textPrimary),
                  ),
                ],
              ),
            ),
            Expanded(
              child: BlocBuilder<SessionChatCubit, SessionChatState>(
                builder: (context, chatState) {
                  if (chatState is! ChatConnected) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
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
    final controller = TextEditingController();
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: 'Message…',
                filled: true,
                fillColor: AppColors.backgroundInput,
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
            icon: const Icon(Icons.send, color: AppColors.primary),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Align(
        alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
        child: Text(
          isMine
              ? message.content
              : '${message.senderName}: ${message.content}',
          style: AppTypography.bodySmall,
        ),
      ),
    );
  }
}
