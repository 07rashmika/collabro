import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../data/services/signaling_service.dart';
import '../../data/services/webrtc_service.dart';
import '../../domain/entities/call_participant.dart';
import '../../domain/repos/sessions_repo.dart';

part 'video_call_state.dart';

class VideoCallCubit extends Cubit<VideoCallState> {
  final WebRTCService webRTCService;
  final SignalingService signalingService;
  final SessionsRepo sessionsRepo;
  final String sessionId;

  StreamSubscription? _signalingSubscription;
  StreamSubscription? _remoteStreamSubscription;

  List<CallParticipant> _participants = [];
  Map<String, MediaStream> _remoteStreams = {};
  bool _isMicMuted = false;
  bool _isCameraOff = false;
  bool _isReconnecting = false;
  bool _isScreenSharing = false;

  VideoCallCubit({
    required this.webRTCService,
    required this.signalingService,
    required this.sessionsRepo,
    required this.sessionId,
  }) : super(const CallConnecting());

  Future<void> start() async {
    emit(const CallConnecting());
    try {
      final iceServersResponse = await sessionsRepo.getIceServers(sessionId);
      final iceServers = iceServersResponse.iceServers
          .map((s) => s.toRtcConfig())
          .toList();

      await webRTCService.initLocalMedia(iceServers);

      webRTCService.onIceCandidate = (targetUserId, candidate) {
        signalingService.sendIceCandidate(
          targetUserId: targetUserId,
          candidate: candidate.candidate ?? '',
          sdpMid: candidate.sdpMid,
          sdpMLineIndex: candidate.sdpMLineIndex,
        );
      };

      _remoteStreamSubscription = webRTCService.onRemoteStream.listen((entry) {
        final updated = Map<String, MediaStream>.from(_remoteStreams);
        if (entry.value == null) {
          updated.remove(entry.key);
        } else {
          updated[entry.key] = entry.value!;
        }
        _remoteStreams = updated;
        _emitActiveState();
      });

      await signalingService.connect();
      _signalingSubscription = signalingService.messages.listen(
        _handleSignalingMessage,
      );
    } catch (e) {
      emit(CallError(e.toString().replaceFirst('Exception: ', '')));
    }
  }

  Future<void> _handleSignalingMessage(SignalingMessage message) async {
    switch (message) {
      case RoomSnapshotReceived(:final participants):
        _participants = participants;
        for (final p in participants) {
          final sdp = await webRTCService.createOfferFor(p.userId);
          signalingService.sendOffer(targetUserId: p.userId, sdp: sdp);
        }
        _emitActiveState();

      case ReconnectedStateReceived(:final participants):
        _participants = participants;
        _isReconnecting = false;
        _emitActiveState();

      case ParticipantJoined(:final participant):
        _participants = [..._participants, participant];
        _emitActiveState();

      case ParticipantLeft(:final userId):
        _participants = _participants.where((p) => p.userId != userId).toList();
        await webRTCService.closePeerConnectionFor(userId);

      case OfferReceived(:final fromUserId, :final sdp):
        final answerSdp = await webRTCService.createAnswerFor(fromUserId, sdp);
        signalingService.sendAnswer(targetUserId: fromUserId, sdp: answerSdp);
        _emitActiveState();

      case AnswerReceived(:final fromUserId, :final sdp):
        await webRTCService.setRemoteAnswerFor(fromUserId, sdp);

      case IceCandidateReceived(
        :final fromUserId,
        :final candidate,
        :final sdpMid,
        :final sdpMLineIndex,
      ):
        await webRTCService.addIceCandidateFor(
          fromUserId,
          candidate,
          sdpMid,
          sdpMLineIndex,
        );

      case ChatMessageReceived():
        break;

      case ScreenShareStateChanged(:final userId, :final isScreenSharing):
        _updateParticipant(
          userId,
          (p) => p.copyWith(isScreenSharing: isScreenSharing),
        );

      case MicStateChanged(:final userId, :final isMicMuted):
        _updateParticipant(userId, (p) => p.copyWith(isMicMuted: isMicMuted));

      case CameraStateChanged(:final userId, :final isCameraOff):
        _updateParticipant(userId, (p) => p.copyWith(isCameraOff: isCameraOff));

      case SignalingReconnecting():
        _isReconnecting = true;
        _emitActiveState();

      case SignalingReconnected():
        _isReconnecting = false;
        _emitActiveState();

      case SessionEndedReceived():
        await webRTCService.hangUp();
        emit(const CallDisconnected(sessionEnded: true));

      case SignalingError():
        break;
    }
  }

  void _updateParticipant(
    String userId,
    CallParticipant Function(CallParticipant) update,
  ) {
    _participants = _participants
        .map((p) => p.userId == userId ? update(p) : p)
        .toList();
    _emitActiveState();
  }

  Future<void> toggleMic() async {
    _isMicMuted = webRTCService.toggleMic();
    signalingService.sendMicState(_isMicMuted);
    _emitActiveState();
  }

  Future<void> toggleCamera() async {
    _isCameraOff = webRTCService.toggleCamera();
    signalingService.sendCameraState(_isCameraOff);
    _emitActiveState();
  }

  Future<void> startScreenShare() async {
    try {
      await webRTCService.startScreenShare();
      _isScreenSharing = true;
      signalingService.sendScreenShareState(true);
      final localStream = webRTCService.activeLocalStream;
      if (localStream == null) return;
      emit(
        ScreenSharing(
          localStream: localStream,
          participants: _participants,
          remoteStreams: _remoteStreams,
          isMicMuted: _isMicMuted,
          isCameraOff: _isCameraOff,
          isReconnecting: _isReconnecting,
        ),
      );
    } catch (e) {
      emit(CallError(e.toString().replaceFirst('Exception: ', '')));
    }
  }

  Future<void> stopScreenShare() async {
    await webRTCService.stopScreenShare();
    _isScreenSharing = false;
    signalingService.sendScreenShareState(false);
    final localStream = webRTCService.activeLocalStream;
    if (localStream == null) return;
    emit(
      ScreenShareStopped(
        localStream: localStream,
        participants: _participants,
        remoteStreams: _remoteStreams,
        isMicMuted: _isMicMuted,
        isCameraOff: _isCameraOff,
        isReconnecting: _isReconnecting,
      ),
    );
  }

  Future<void> hangUp() async {
    await webRTCService.hangUp();
    emit(const CallDisconnected());
  }

  void _emitActiveState() {
    final localStream = webRTCService.activeLocalStream;
    if (localStream == null) return;

    if (_isScreenSharing) {
      emit(
        ScreenSharing(
          localStream: localStream,
          participants: _participants,
          remoteStreams: _remoteStreams,
          isMicMuted: _isMicMuted,
          isCameraOff: _isCameraOff,
          isReconnecting: _isReconnecting,
        ),
      );
    } else {
      emit(
        CallConnected(
          localStream: localStream,
          participants: _participants,
          remoteStreams: _remoteStreams,
          isMicMuted: _isMicMuted,
          isCameraOff: _isCameraOff,
          isReconnecting: _isReconnecting,
        ),
      );
    }
  }

  @override
  Future<void> close() async {
    await _signalingSubscription?.cancel();
    await _remoteStreamSubscription?.cancel();
    await webRTCService.hangUp();
    await signalingService.dispose();
    return super.close();
  }
}
