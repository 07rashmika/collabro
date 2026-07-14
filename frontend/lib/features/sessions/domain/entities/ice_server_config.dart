import 'package:equatable/equatable.dart';

/// A single STUN/TURN server entry as WebRTC's `RTCConfiguration` expects it.
class IceServerConfig extends Equatable {
  final List<String> urls;

  const IceServerConfig({required this.urls});

  factory IceServerConfig.fromJson(Map<String, dynamic> json) {
    final rawUrls = json['urls'];
    return IceServerConfig(
      urls: rawUrls is List ? rawUrls.map((u) => u.toString()).toList() : [rawUrls.toString()],
    );
  }

  Map<String, dynamic> toRtcConfig() => {'urls': urls};

  @override
  List<Object?> get props => [urls];
}

/// ICE server list minted by the backend per video-session join request —
/// never hardcoded client-side, so it can change without an app release.
class IceServersResponse extends Equatable {
  final List<IceServerConfig> iceServers;

  const IceServersResponse({required this.iceServers});

  factory IceServersResponse.fromJson(Map<String, dynamic> json) {
    final servers = (json['iceServers'] as List<dynamic>?) ?? [];
    return IceServersResponse(
      iceServers: servers.map((s) => IceServerConfig.fromJson(s as Map<String, dynamic>)).toList(),
    );
  }

  @override
  List<Object?> get props => [iceServers];
}
