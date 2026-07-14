import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../../core/network/api_config.dart';
import '../../../../core/network/secure_storage_keys.dart';
import '../../domain/entities/call_participant.dart';
import '../../domain/entities/session_message.dart';
import '../sessions_endpoints.dart';
import '../signaling_message_types.dart';

sealed class SignalingMessage {}

class RoomSnapshotReceived extends SignalingMessage {
  final List<CallParticipant> participants;
  RoomSnapshotReceived(this.participants);
}

class ReconnectedStateReceived extends SignalingMessage {
  final List<CallParticipant> participants;
  ReconnectedStateReceived(this.participants);
}

class ParticipantJoined extends SignalingMessage {
  final CallParticipant participant;
  ParticipantJoined(this.participant);
}

class ParticipantLeft extends SignalingMessage {
  final String userId;
  ParticipantLeft(this.userId);
}

class OfferReceived extends SignalingMessage {
  final String fromUserId;
  final String sdp;
  OfferReceived(this.fromUserId, this.sdp);
}

class AnswerReceived extends SignalingMessage {
  final String fromUserId;
  final String sdp;
  AnswerReceived(this.fromUserId, this.sdp);
}

class IceCandidateReceived extends SignalingMessage {
  final String fromUserId;
  final String candidate;
  final String? sdpMid;
  final int? sdpMLineIndex;
  IceCandidateReceived(this.fromUserId, this.candidate, this.sdpMid, this.sdpMLineIndex);
}

class ChatMessageReceived extends SignalingMessage {
  final SessionMessage message;
  ChatMessageReceived(this.message);
}

class ScreenShareStateChanged extends SignalingMessage {
  final String userId;
  final bool isScreenSharing;
  ScreenShareStateChanged(this.userId, this.isScreenSharing);
}

class MicStateChanged extends SignalingMessage {
  final String userId;
  final bool isMicMuted;
  MicStateChanged(this.userId, this.isMicMuted);
}

class CameraStateChanged extends SignalingMessage {
  final String userId;
  final bool isCameraOff;
  CameraStateChanged(this.userId, this.isCameraOff);
}

class SessionEndedReceived extends SignalingMessage {}

class SignalingReconnecting extends SignalingMessage {}

class SignalingReconnected extends SignalingMessage {}

class SignalingError extends SignalingMessage {
  final String message;
  SignalingError(this.message);
}

const _initialBackoff = Duration(seconds: 1);
const _maxBackoff = Duration(seconds: 15);

/// Owns a single WebSocket connection per active session, carrying
/// signaling (offer/answer/ICE), chat, and screen-share/mic/camera state
/// together, multiplexed by a `type` field on each JSON message. Reconnects
/// with backoff on an unexpected close; never silently drops the socket.
class SignalingService {
  final FlutterSecureStorage storage;
  final String sessionId;

  WebSocketChannel? _channel;
  StreamSubscription? _channelSubscription;
  final _messageController = StreamController<SignalingMessage>.broadcast();
  bool _isDisposing = false;
  Duration _backoff = _initialBackoff;

  SignalingService({required this.storage, required this.sessionId});

  Stream<SignalingMessage> get messages => _messageController.stream;

  /// Idempotent — safe to call from more than one owner (a VideoCallCubit
  /// and a SessionChatCubit may share one instance); only the first call
  /// actually opens the socket.
  Future<void> connect() async {
    if (_channel != null) return;
    try {
      final token = await storage.read(key: SecureStorageKeys.accessToken);
      if (token == null) {
        throw Exception('Not signed in');
      }
      final url = SessionsEndpoints.signalingWsUrl(ApiConfig.baseUrl, sessionId, token);
      final channel = WebSocketChannel.connect(Uri.parse(url));
      await channel.ready;
      _channel = channel;
      _backoff = _initialBackoff;

      _channelSubscription = channel.stream.listen(
        _handleRawMessage,
        onDone: _handleUnexpectedClose,
        onError: (_) => _handleUnexpectedClose(),
        cancelOnError: true,
      );
    } catch (e) {
      throw Exception('Connecting to session failed: $e');
    }
  }

  void _handleRawMessage(dynamic raw) {
    try {
      final json = jsonDecode(raw as String) as Map<String, dynamic>;
      final message = _parseMessage(json);
      if (message != null) {
        _messageController.add(message);
      }
    } catch (_) {
      // Malformed frame from the server — ignore rather than crash the stream.
    }
  }

  SignalingMessage? _parseMessage(Map<String, dynamic> json) {
    switch (json['type'] as String?) {
      case SignalingMessageTypes.roomSnapshot:
        return RoomSnapshotReceived(_parseParticipants(json));
      case SignalingMessageTypes.reconnectedState:
        return ReconnectedStateReceived(_parseParticipants(json));
      case SignalingMessageTypes.participantJoined:
        return ParticipantJoined(
          CallParticipant.fromJson(json['participant'] as Map<String, dynamic>),
        );
      case SignalingMessageTypes.participantLeft:
        return ParticipantLeft(json['userId'] as String);
      case SignalingMessageTypes.offer:
        return OfferReceived(json['fromUserId'] as String, json['sdp'] as String);
      case SignalingMessageTypes.answer:
        return AnswerReceived(json['fromUserId'] as String, json['sdp'] as String);
      case SignalingMessageTypes.iceCandidate:
        return IceCandidateReceived(
          json['fromUserId'] as String,
          json['candidate'] as String,
          json['sdpMid'] as String?,
          json['sdpMLineIndex'] as int?,
        );
      case SignalingMessageTypes.chatMessage:
        return ChatMessageReceived(
          SessionMessage.fromSignalingJson(json['message'] as Map<String, dynamic>),
        );
      case SignalingMessageTypes.screenShareState:
        return ScreenShareStateChanged(json['userId'] as String, json['isScreenSharing'] as bool);
      case SignalingMessageTypes.micState:
        return MicStateChanged(json['userId'] as String, json['isMicMuted'] as bool);
      case SignalingMessageTypes.cameraState:
        return CameraStateChanged(json['userId'] as String, json['isCameraOff'] as bool);
      case SignalingMessageTypes.sessionEnded:
        return SessionEndedReceived();
      case SignalingMessageTypes.error:
        return SignalingError(json['message'] as String? ?? 'Unknown signaling error');
      default:
        return null;
    }
  }

  List<CallParticipant> _parseParticipants(Map<String, dynamic> json) {
    final participants = (json['participants'] as List<dynamic>?) ?? [];
    return participants.map((p) => CallParticipant.fromJson(p as Map<String, dynamic>)).toList();
  }

  void _handleUnexpectedClose() {
    _channelSubscription = null;
    _channel = null;
    if (_isDisposing) return;

    _messageController.add(SignalingReconnecting());
    Future.delayed(_backoff, _attemptReconnect);
    _backoff = Duration(seconds: (_backoff.inSeconds * 2).clamp(1, _maxBackoff.inSeconds));
  }

  Future<void> _attemptReconnect() async {
    if (_isDisposing) return;
    try {
      await connect();
      _messageController.add(SignalingReconnected());
    } catch (_) {
      _handleUnexpectedClose();
    }
  }

  void _send(Map<String, dynamic> message) {
    _channel?.sink.add(jsonEncode(message));
  }

  void sendOffer({required String targetUserId, required String sdp}) =>
      _send({'type': SignalingMessageTypes.offer, 'targetUserId': targetUserId, 'sdp': sdp});

  void sendAnswer({required String targetUserId, required String sdp}) =>
      _send({'type': SignalingMessageTypes.answer, 'targetUserId': targetUserId, 'sdp': sdp});

  void sendIceCandidate({
    required String targetUserId,
    required String candidate,
    String? sdpMid,
    int? sdpMLineIndex,
  }) => _send({
    'type': SignalingMessageTypes.iceCandidate,
    'targetUserId': targetUserId,
    'candidate': candidate,
    'sdpMid': sdpMid,
    'sdpMLineIndex': sdpMLineIndex,
  });

  void sendChatMessage(String content) =>
      _send({'type': SignalingMessageTypes.chatMessage, 'content': content});

  void sendScreenShareState(bool isScreenSharing) =>
      _send({'type': SignalingMessageTypes.screenShareState, 'isScreenSharing': isScreenSharing});

  void sendMicState(bool isMicMuted) =>
      _send({'type': SignalingMessageTypes.micState, 'isMicMuted': isMicMuted});

  void sendCameraState(bool isCameraOff) =>
      _send({'type': SignalingMessageTypes.cameraState, 'isCameraOff': isCameraOff});

  /// Idempotent — safe to call more than once (e.g. from both a
  /// VideoCallCubit and a SessionChatCubit sharing this instance).
  Future<void> dispose() async {
    if (_isDisposing) return;
    _isDisposing = true;
    await _channelSubscription?.cancel();
    await _channel?.sink.close();
    await _messageController.close();
  }
}
