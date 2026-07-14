import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';

import 'package:frontend/core/constants/app_colors.dart';
import 'package:frontend/core/constants/app_spacing.dart';
import 'package:frontend/core/constants/app_typography.dart';
import 'package:frontend/core/widgets/primary_button.dart';
import 'package:frontend/features/auth/domain/entities/app_user.dart';
import 'package:frontend/features/auth/domain/repos/auth_repo.dart';
import 'package:frontend/features/sessions/data/services/chat_socket_service.dart';
import 'package:frontend/features/sessions/data/services/signaling_service.dart';
import 'package:frontend/features/sessions/domain/entities/session_message.dart';
import 'package:frontend/features/sessions/domain/entities/study_session.dart';
import 'package:frontend/features/sessions/domain/entities/zego_call_credentials.dart';
import 'package:frontend/features/sessions/domain/repos/sessions_repo.dart';
import 'package:frontend/features/sessions/presentation/components/session_info_panel.dart';
import 'package:frontend/features/sessions/presentation/cubits/session_chat_cubit.dart';
import 'package:frontend/features/sessions/presentation/cubits/sessions_cubit.dart';

/// Owns the chat signaling connection and session-management cubits for one
/// call. The call itself is entirely owned by [ZegoUIKitPrebuiltCall] — its
/// own widget tree, controls, and peer connections — so there's no
/// VideoCallCubit here: there's no local call state left to track once the
/// join credentials are fetched.
class VideoCallScreen extends StatefulWidget {
  final StudySession session;

  const VideoCallScreen({super.key, required this.session});

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  late final SignalingService _signalingService;
  late final SessionChatCubit _sessionChatCubit;
  late final SessionsCubit _sessionsCubit;
  AppUser? _currentUser;

  @override
  void initState() {
    super.initState();
    final storage = context.read<FlutterSecureStorage>();
    final sessionsRepo = context.read<SessionsRepo>();
    final authRepo = context.read<AuthRepo>();

    _signalingService = SignalingService(
      storage: storage,
      sessionId: widget.session.id,
    );

    _sessionChatCubit = SessionChatCubit(
      chatSocketService: ChatSocketService(signalingService: _signalingService),
      signalingService: _signalingService,
      sessionsRepo: sessionsRepo,
      authRepo: authRepo,
      sessionId: widget.session.id,
    )..start();

    _sessionsCubit = SessionsCubit(sessionsRepo: sessionsRepo);

    authRepo.getCurrentUser().then((user) {
      if (mounted) setState(() => _currentUser = user);
    });
  }

  @override
  void dispose() {
    _sessionChatCubit.close();
    _sessionsCubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: _sessionChatCubit),
        BlocProvider.value(value: _sessionsCubit),
      ],
      child: _VideoCallView(session: widget.session, currentUser: _currentUser),
    );
  }
}

class _VideoCallView extends StatefulWidget {
  final StudySession session;
  final AppUser? currentUser;

  const _VideoCallView({required this.session, required this.currentUser});

  @override
  State<_VideoCallView> createState() => _VideoCallViewState();
}

class _VideoCallViewState extends State<_VideoCallView> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _showChat = false;
  late final Future<ZegoCallCredentials> _credentialsFuture;

  @override
  void initState() {
    super.initState();
    _credentialsFuture =
        context.read<SessionsRepo>().getZegoCallCredentials(widget.session.id);
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
    final currentUser = widget.currentUser;
    final isCreator = currentUser != null && currentUser.id == widget.session.creatorId;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.backgroundDark,
      endDrawer: SessionInfoPanel(
        session: widget.session,
        currentUserId: currentUser?.id,
        onEndSession: isCreator ? () => _confirmEndSession(context) : null,
      ),
      body: SafeArea(
        child: MultiBlocListener(
          listeners: [
            BlocListener<SessionsCubit, SessionsState>(
              listener: (context, state) {
                if (state is SessionSaved) {
                  Navigator.of(context).pop();
                } else if (state is SessionsError) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(state.message),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              },
            ),
            BlocListener<SessionChatCubit, SessionChatState>(
              listener: (context, state) {
                if (state is ChatSessionEnded) Navigator.of(context).pop();
              },
            ),
          ],
          child: Stack(
            children: [
              if (currentUser == null)
                const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                )
              else
                _buildCall(currentUser),
              Positioned(
                top: AppSpacing.sm,
                right: AppSpacing.sm,
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => setState(() => _showChat = !_showChat),
                      tooltip: 'Chat',
                      icon: const Icon(
                        Icons.chat_bubble_outline,
                        color: AppColors.textPrimary,
                      ),
                      style: IconButton.styleFrom(backgroundColor: AppColors.overlay),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    IconButton(
                      onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
                      tooltip: 'Session info',
                      icon: const Icon(
                        Icons.more_vert,
                        color: AppColors.textPrimary,
                      ),
                      style: IconButton.styleFrom(backgroundColor: AppColors.overlay),
                    ),
                  ],
                ),
              ),
              if (_showChat) _buildChatDrawer(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCall(AppUser currentUser) {
    return FutureBuilder<ZegoCallCredentials>(
      future: _credentialsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }

        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.videocam_off_outlined, color: AppColors.error, size: 48),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  snapshot.error.toString().replaceFirst('Exception: ', ''),
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

        final credentials = snapshot.data!;
        return ZegoUIKitPrebuiltCall(
          appID: credentials.appId,
          token: credentials.token,
          userID: currentUser.id,
          userName: currentUser.name,
          callID: credentials.roomId,
          config: ZegoUIKitPrebuiltCallConfig.groupVideoCall(),
        );
      },
    );
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
                      child: CircularProgressIndicator(color: AppColors.primary),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
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
              style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary),
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
          isMine ? message.content : '${message.senderName}: ${message.content}',
          style: AppTypography.bodySmall,
        ),
      ),
    );
  }
}
