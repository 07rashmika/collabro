part of 'video_call_cubit.dart';

sealed class VideoCallState extends Equatable {
  const VideoCallState();

  @override
  List<Object?> get props => [];
}

final class CallConnecting extends VideoCallState {
  const CallConnecting();
}

/// Shared data for every "call is up" state (normal, screen-sharing, or just
/// stopped sharing) so the UI can keep rendering the video grid across those
/// transitions without losing participant/stream data.
sealed class ActiveCallState extends VideoCallState {
  final MediaStream localStream;
  final List<CallParticipant> participants;
  final Map<String, MediaStream> remoteStreams;
  final bool isMicMuted;
  final bool isCameraOff;
  final bool isReconnecting;

  const ActiveCallState({
    required this.localStream,
    required this.participants,
    required this.remoteStreams,
    required this.isMicMuted,
    required this.isCameraOff,
    required this.isReconnecting,
  });

  @override
  List<Object?> get props => [
    localStream,
    participants,
    remoteStreams,
    isMicMuted,
    isCameraOff,
    isReconnecting,
  ];
}

final class CallConnected extends ActiveCallState {
  const CallConnected({
    required super.localStream,
    required super.participants,
    required super.remoteStreams,
    required super.isMicMuted,
    required super.isCameraOff,
    required super.isReconnecting,
  });
}

final class ScreenSharing extends ActiveCallState {
  const ScreenSharing({
    required super.localStream,
    required super.participants,
    required super.remoteStreams,
    required super.isMicMuted,
    required super.isCameraOff,
    required super.isReconnecting,
  });
}

final class ScreenShareStopped extends ActiveCallState {
  const ScreenShareStopped({
    required super.localStream,
    required super.participants,
    required super.remoteStreams,
    required super.isMicMuted,
    required super.isCameraOff,
    required super.isReconnecting,
  });
}

final class CallDisconnected extends VideoCallState {
  const CallDisconnected();
}

final class CallError extends VideoCallState {
  final String message;
  const CallError(this.message);

  @override
  List<Object?> get props => [message];
}
