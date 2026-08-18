import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/features/auth/domain/repos/auth_repo.dart';

import '../../data/services/chat_socket_service.dart';
import '../../data/services/signaling_service.dart';
import '../../domain/entities/session_message.dart';
import '../../domain/repos/sessions_repo.dart';

part 'session_chat_state.dart';

class SessionChatCubit extends Cubit<SessionChatState> {
  final ChatSocketService chatSocketService;
  final SignalingService signalingService;
  final SessionsRepo sessionsRepo;
  final AuthRepo authRepo;
  final String sessionId;

  StreamSubscription? _messageSubscription;
  StreamSubscription? _sessionEndedSubscription;
  String _currentUserId = '';

  SessionChatCubit({
    required this.chatSocketService,
    required this.signalingService,
    required this.sessionsRepo,
    required this.authRepo,
    required this.sessionId,
  }) : super(const ChatConnecting());

  Future<void> start() async {
    emit(const ChatConnecting());
    try {
      final user = await authRepo.getCurrentUser();
      _currentUserId = user?.id ?? '';
      final messages = await sessionsRepo.getMessages(sessionId);
      emit(ChatConnected(messages: messages, currentUserId: _currentUserId));

      await signalingService.connect();
      _messageSubscription?.cancel();
      _messageSubscription = chatSocketService.messages.listen(
        _onMessageReceived,
      );

      _sessionEndedSubscription?.cancel();
      _sessionEndedSubscription = signalingService.messages
          .where((m) => m is SessionEndedReceived)
          .listen((m) => emit(const ChatSessionEnded()));
    } catch (e) {
      emit(ChatError(e.toString().replaceFirst('Exception: ', '')));
    }
  }

  void _onMessageReceived(SessionMessage message) {
    final current = state;
    if (current is! ChatConnected) return;
    emit(
      ChatConnected(
        messages: [...current.messages, message],
        currentUserId: current.currentUserId,
      ),
    );
  }

  void sendMessage(String content) {
    chatSocketService.sendMessage(content);
  }

  Future<void> deleteMessage(String messageId) async {
    final current = state;
    if (current is! ChatConnected) return;
    try {
      await sessionsRepo.deleteMessage(sessionId, messageId);
      emit(
        ChatConnected(
          messages: current.messages.where((m) => m.id != messageId).toList(),
          currentUserId: current.currentUserId,
        ),
      );
    } catch (e) {
      emit(ChatError(e.toString().replaceFirst('Exception: ', '')));
    }
  }

  @override
  Future<void> close() async {
    await _messageSubscription?.cancel();
    await _sessionEndedSubscription?.cancel();
    await signalingService.dispose();
    return super.close();
  }
}
