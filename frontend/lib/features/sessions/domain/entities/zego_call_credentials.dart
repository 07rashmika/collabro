import 'package:equatable/equatable.dart';

/// Short-lived credentials for joining a ZegoCloud video call room, minted
/// by the backend per session-join request — never generated client-side.
class ZegoCallCredentials extends Equatable {
  final String token;
  final int appId;
  final String roomId;

  const ZegoCallCredentials({required this.token, required this.appId, required this.roomId});

  factory ZegoCallCredentials.fromJson(Map<String, dynamic> json) {
    return ZegoCallCredentials(
      token: json['token'] as String,
      appId: json['appId'] as int,
      roomId: json['roomId'] as String,
    );
  }

  @override
  List<Object?> get props => [token, appId, roomId];
}
