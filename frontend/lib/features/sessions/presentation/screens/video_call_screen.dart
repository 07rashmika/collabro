import 'dart:io' show File;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:frontend/core/constants/app_colors.dart';
import 'package:frontend/core/constants/app_routes.dart';
import 'package:frontend/core/constants/app_spacing.dart';
import 'package:frontend/core/constants/app_typography.dart';
import 'package:frontend/core/constants/error_messages.dart';
import 'package:frontend/core/utils/snackbar_utils.dart';
import 'package:frontend/core/widgets/primary_button.dart';
import 'package:frontend/features/auth/domain/repos/auth_repo.dart';
import 'package:frontend/features/sessions/data/services/chat_socket_service.dart';
import 'package:frontend/features/sessions/data/services/signaling_service.dart';
import 'package:frontend/features/sessions/data/services/webrtc_service.dart';
import 'package:frontend/features/sessions/domain/entities/study_session.dart';
import 'package:frontend/features/sessions/domain/repos/sessions_repo.dart';
import 'package:frontend/features/sessions/presentation/components/active_call_view.dart';
import 'package:frontend/features/sessions/presentation/components/session_info_panel.dart';
import 'package:frontend/features/sessions/presentation/components/session_summary_dialog.dart';
import 'package:frontend/features/sessions/presentation/cubits/session_chat_cubit.dart';
import 'package:frontend/features/sessions/presentation/cubits/sessions_cubit.dart';
import 'package:frontend/features/sessions/presentation/cubits/video_call_cubit.dart';
import 'package:go_router/go_router.dart';

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

  bool _summaryHandled = false;

  Future<void> _handleSessionEndSummary(StudySession fallbackSession) async {
    if (_summaryHandled) return;
    _summaryHandled = true;

    final webRTCService = context.read<VideoCallCubit>().webRTCService;
    await webRTCService.finishRecording();
    if (!mounted) return;

    debugPrint(
      '[VideoCall] Call ended — ${webRTCService.recordedTracks.length} recorded track(s) '
      '(${webRTCService.recordedTracks.map((t) => t.label).join(', ')})',
    );

    var session = fallbackSession;
    if (webRTCService.recordedTracks.isNotEmpty) {
      try {
        debugPrint(
          '[VideoCall] Uploading recording for session ${fallbackSession.id}...',
        );
        session = await context
            .read<SessionsRepo>()
            .uploadRecording(fallbackSession.id, [
              for (final track in webRTCService.recordedTracks)
                (
                  path: track.path,
                  label: track.label,
                  startedAt: track.startedAt,
                ),
            ]);
        debugPrint(
          '[VideoCall] Recording uploaded and processed successfully.',
        );

        for (final track in webRTCService.recordedTracks) {
          File(track.path).delete().ignore();
        }
      } catch (e) {
        debugPrint('[VideoCall] Recording upload failed: $e');

        if (mounted) showErrorSnackBar(context);
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
        title: Text('End session permanently?', style: typography.titleMedium),
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
            child: Text('End Session', style: TextStyle(color: colors.error)),
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
              showErrorSnackBar(context);
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
                    showErrorSnackBar(context);
                  }
                  if (state is CallDisconnected) {
                    if (state.sessionEnded) {
                      await _handleSessionEndSummary(widget.session);
                      if (!context.mounted) return;
                    }
                    context.go(AppRoutes.sessions);
                  }
                },
                builder: (context, state) {
                  if (state is CallConnecting) {
                    return Center(
                      child: CircularProgressIndicator(color: colors.primary),
                    );
                  }

                  if (state is CallError) {
                    return Padding(
                      padding: const .all(AppSpacing.screenHorizontal),
                      child: Column(
                        mainAxisAlignment: .center,
                        children: [
                          Icon(
                            Icons.videocam_off_outlined,
                            color: colors.error,
                            size: 48,
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          Text(
                            genericErrorMessage,
                            textAlign: .center,
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
                    return ActiveCallView(
                      state: state,
                      localRenderer: _localRenderer,
                      localRendererReady: _localRendererReady,
                      remoteRenderers: _remoteRenderers,
                      showChat: _showChat,
                      onToggleChat: () =>
                          setState(() => _showChat = !_showChat),
                      onCloseChat: () => setState(() => _showChat = false),
                    );
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
                  icon: Icon(Icons.more_vert, color: colors.textPrimary),
                  style: IconButton.styleFrom(backgroundColor: colors.overlay),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
