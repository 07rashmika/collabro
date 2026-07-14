import '../../domain/entities/session_message.dart';
import 'signaling_service.dart';

/// Reuses the *same* WebSocket connection as [SignalingService] (multiplexed
/// by message `type`) rather than opening a second socket for chat — video
/// sessions can have a side chat this way with no extra connection.
class ChatSocketService {
  final SignalingService signalingService;

  ChatSocketService({required this.signalingService});

  Stream<SessionMessage> get messages => signalingService.messages
      .where((m) => m is ChatMessageReceived)
      .map((m) => (m as ChatMessageReceived).message);

  void sendMessage(String content) => signalingService.sendChatMessage(content);
}
