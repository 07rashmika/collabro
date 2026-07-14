import 'package:equatable/equatable.dart';

/// Live in-call presence for one participant of an active video call —
/// distinct from [SessionParticipant] in study_session.dart, which is the
/// static "added to this session" membership record. This entity tracks
/// ephemeral per-connection state (mic/camera/screen-share flags) that only
/// exists while the participant's signaling socket is open.
class CallParticipant extends Equatable {
  final String userId;
  final String name;
  final bool isMicMuted;
  final bool isCameraOff;
  final bool isScreenSharing;

  const CallParticipant({
    required this.userId,
    required this.name,
    this.isMicMuted = false,
    this.isCameraOff = false,
    this.isScreenSharing = false,
  });

  factory CallParticipant.fromJson(Map<String, dynamic> json) {
    return CallParticipant(
      userId: json['userId'] as String,
      name: json['name'] as String,
      isMicMuted: json['isMicMuted'] as bool? ?? false,
      isCameraOff: json['isCameraOff'] as bool? ?? false,
      isScreenSharing: json['isScreenSharing'] as bool? ?? false,
    );
  }

  CallParticipant copyWith({
    bool? isMicMuted,
    bool? isCameraOff,
    bool? isScreenSharing,
  }) {
    return CallParticipant(
      userId: userId,
      name: name,
      isMicMuted: isMicMuted ?? this.isMicMuted,
      isCameraOff: isCameraOff ?? this.isCameraOff,
      isScreenSharing: isScreenSharing ?? this.isScreenSharing,
    );
  }

  @override
  List<Object?> get props => [userId, name, isMicMuted, isCameraOff, isScreenSharing];
}
