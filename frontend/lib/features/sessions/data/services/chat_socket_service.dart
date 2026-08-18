import '../../domain/entities/session_message.dart';
import 'signaling_service.dart';

class ChatSocketService {
  final SignalingService signalingService;

  ChatSocketService({required this.signalingService});

  Stream<SessionMessage> get messages => signalingService.messages
      .where((m) => m is ChatMessageReceived)
      .map((m) => (m as ChatMessageReceived).message);

  void sendMessage(String content) => signalingService.sendChatMessage(content);
}
