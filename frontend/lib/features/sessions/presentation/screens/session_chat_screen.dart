import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';

import 'package:frontend/core/constants/app_colors.dart';
import 'package:frontend/core/constants/app_spacing.dart';
import 'package:frontend/core/constants/app_typography.dart';
import 'package:frontend/features/auth/domain/repos/auth_repo.dart';
import 'package:frontend/features/sessions/data/services/chat_socket_service.dart';
import 'package:frontend/features/sessions/data/services/signaling_service.dart';
import 'package:frontend/features/sessions/domain/entities/study_session.dart';
import 'package:frontend/features/sessions/domain/repos/sessions_repo.dart';
import 'package:frontend/features/sessions/presentation/components/message_bubble.dart';
import 'package:frontend/features/sessions/presentation/components/session_info_panel.dart';
import 'package:frontend/features/sessions/presentation/cubits/session_chat_cubit.dart';
import 'package:frontend/features/sessions/presentation/cubits/sessions_cubit.dart';

/// Pure chat UI for a TEXT session, backed by [SessionChatCubit]. This is
/// the sole owner of its [SignalingService] (no video call sharing it), so
/// it constructs and disposes one directly.
class SessionChatScreen extends StatefulWidget {
  final StudySession session;

  const SessionChatScreen({super.key, required this.session});

  @override
  State<SessionChatScreen> createState() => _SessionChatScreenState();
}

class _SessionChatScreenState extends State<SessionChatScreen> {
  late final SessionChatCubit _sessionChatCubit;

  @override
  void initState() {
    super.initState();
    final storage = context.read<FlutterSecureStorage>();
    final signalingService = SignalingService(
      storage: storage,
      sessionId: widget.session.id,
    );
    _sessionChatCubit = SessionChatCubit(
      chatSocketService: ChatSocketService(signalingService: signalingService),
      signalingService: signalingService,
      sessionsRepo: context.read<SessionsRepo>(),
      authRepo: context.read<AuthRepo>(),
      sessionId: widget.session.id,
    )..start();
  }

  @override
  void dispose() {
    _sessionChatCubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: _sessionChatCubit),
        BlocProvider(
          create: (context) =>
              SessionsCubit(sessionsRepo: context.read<SessionsRepo>()),
        ),
      ],
      child: _SessionChatView(session: widget.session),
    );
  }
}

class _SessionChatView extends StatefulWidget {
  final StudySession session;

  const _SessionChatView({required this.session});

  @override
  State<_SessionChatView> createState() => _SessionChatViewState();
}

class _SessionChatViewState extends State<_SessionChatView> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  bool get _isClosed => widget.session.status == SessionStatus.closed;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _send() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    context.read<SessionChatCubit>().sendMessage(text);
    _messageController.clear();
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

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.backgroundDark,
      endDrawer: BlocBuilder<SessionChatCubit, SessionChatState>(
        builder: (context, state) {
          final currentUserId = state is ChatConnected ? state.currentUserId : null;
          final isCreator = currentUserId == widget.session.creatorId;
          return SessionInfoPanel(
            session: widget.session,
            currentUserId: currentUserId,
            onEndSession:
                isCreator && !_isClosed ? () => _confirmEndSession(context) : null,
          );
        },
      ),
      body: SafeArea(
        child: BlocListener<SessionsCubit, SessionsState>(
          listener: (context, state) {
            if (state is SessionSaved) {
              context.pop();
            } else if (state is SessionsError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: AppColors.error,
                ),
              );
            }
          },
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.screenHorizontal,
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => context.pop(),
                      icon: const Icon(
                        Icons.arrow_back,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.session.title,
                            style: AppTypography.titleLarge,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${widget.session.participants.length} participants'
                            '${_isClosed ? ' · Closed' : ''}',
                            style: AppTypography.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
                      tooltip: 'Session info',
                      icon: const Icon(
                        Icons.more_vert,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: AppSpacing.lg, color: AppColors.border),
              Expanded(
                child: BlocConsumer<SessionChatCubit, SessionChatState>(
                  listener: (context, state) {
                    if (state is ChatConnected) _scrollToBottom();
                    if (state is ChatError) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(state.message),
                          backgroundColor: AppColors.error,
                        ),
                      );
                    }
                    if (state is ChatSessionEnded) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'This session has been permanently ended.',
                          ),
                          backgroundColor: AppColors.warning,
                        ),
                      );
                      context.pop();
                    }
                  },
                  builder: (context, state) {
                    if (state is ChatConnecting) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                        ),
                      );
                    }

                    if (state is ChatError) {
                      return Center(
                        child: Text(
                          state.message,
                          textAlign: TextAlign.center,
                          style: AppTypography.bodySmall,
                        ),
                      );
                    }

                    if (state is ChatSessionEnded) {
                      return const SizedBox.shrink();
                    }

                    final connected = state as ChatConnected;
                    if (connected.messages.isEmpty) {
                      return Center(
                        child: Text(
                          'No messages yet. Say hello!',
                          style: AppTypography.bodySmall,
                        ),
                      );
                    }

                    return ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.screenHorizontal,
                      ),
                      itemCount: connected.messages.length,
                      itemBuilder: (context, i) {
                        final message = connected.messages[i];
                        final isMine =
                            message.senderId == connected.currentUserId;
                        return MessageBubble(
                          message: message,
                          isMine: isMine,
                          onLongPress: isMine
                              ? () => context
                                    .read<SessionChatCubit>()
                                    .deleteMessage(message.id)
                              : null,
                        );
                      },
                    );
                  },
                ),
              ),
              if (!_isClosed)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenHorizontal,
                    AppSpacing.sm,
                    AppSpacing.screenHorizontal,
                    AppSpacing.sm,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          style: AppTypography.bodyLarge.copyWith(
                            color: AppColors.textPrimary,
                          ),
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _send(),
                          decoration: InputDecoration(
                            hintText: 'Type a message...',
                            hintStyle: AppTypography.bodyLarge.copyWith(
                              color: AppColors.textHint,
                            ),
                            filled: true,
                            fillColor: AppColors.backgroundInput,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.lg,
                              vertical: AppSpacing.md,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                AppSpacing.radiusFull,
                              ),
                              borderSide: const BorderSide(
                                color: AppColors.border,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                AppSpacing.radiusFull,
                              ),
                              borderSide: const BorderSide(
                                color: AppColors.border,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                AppSpacing.radiusFull,
                              ),
                              borderSide: const BorderSide(
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      IconButton(
                        onPressed: _send,
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: const CircleBorder(),
                        ),
                        icon: const Icon(Icons.send, color: Colors.white),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
