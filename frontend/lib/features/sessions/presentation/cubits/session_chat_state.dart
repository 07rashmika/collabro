part of 'session_chat_cubit.dart';

sealed class SessionChatState extends Equatable {
  const SessionChatState();

  @override
  List<Object?> get props => [];
}

final class ChatConnecting extends SessionChatState {
  const ChatConnecting();
}

final class ChatConnected extends SessionChatState {
  final List<SessionMessage> messages;
  final String currentUserId;
  const ChatConnected({required this.messages, required this.currentUserId});

  @override
  List<Object?> get props => [messages, currentUserId];
}

final class ChatError extends SessionChatState {
  final String message;
  const ChatError(this.message);

  @override
  List<Object?> get props => [message];
}

/// The session was permanently ended (by its creator, or auto-closed once
/// no one else was left) while this chat was open.
final class ChatSessionEnded extends SessionChatState {
  const ChatSessionEnded();
}
