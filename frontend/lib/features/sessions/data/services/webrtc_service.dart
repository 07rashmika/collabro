import 'dart:async';
import 'dart:io';

import 'package:flutter_background/flutter_background.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:path_provider/path_provider.dart';

/// A finished call recording track, ready to upload.
class RecordedTrack {
  final String path;
  final String label;
  final DateTime startedAt;

  const RecordedTrack({required this.path, required this.label, required this.startedAt});
}

/// Wraps flutter_webrtc for a mesh-topology group call: one
/// [RTCPeerConnection] per *other* participant (keyed by userId), all
/// sharing the same local camera/mic [MediaStream]. Never constructed
/// inside a widget or Cubit — only here, one instance per call.
///
/// When opted in via [enableRecording] (only the session creator's device
/// should call it — see VideoCallScreen), records the call's audio to two
/// local files via flutter_webrtc's native MediaRecorder: one tapping this
/// device's mic (`INPUT`), one tapping the call's mixed playback of every
/// other participant (`OUTPUT`). Together they cover both sides of the
/// conversation without needing a recorder per remote peer. Recording spans
/// the whole call — started as soon as both the local stream is up and
/// recording has been enabled, stopped in [hangUp] — and is uploaded
/// afterward for transcription (see SessionsRepo.uploadRecording).
class WebRTCService {
  MediaStream? _localStream;
  MediaStream? _screenStream;
  MediaStreamTrack? _cameraTrack;
  List<Map<String, dynamic>> _iceServers = [];
  bool _isHungUp = false;
  bool _recordingEnabled = false;

  MediaRecorder? _inputRecorder;
  MediaRecorder? _outputRecorder;
  String? _inputRecordingPath;
  String? _outputRecordingPath;
  DateTime? _inputRecordingStartedAt;
  DateTime? _outputRecordingStartedAt;

  final Map<String, RTCPeerConnection> _peerConnections = {};
  final Map<String, MediaStream> _remoteStreams = {};

  final _remoteStreamController = StreamController<MapEntry<String, MediaStream?>>.broadcast();

  /// Emits `MapEntry(userId, stream)` when a remote stream arrives, and
  /// `MapEntry(userId, null)` when that participant's connection closes.
  Stream<MapEntry<String, MediaStream?>> get onRemoteStream => _remoteStreamController.stream;

  void Function(String targetUserId, RTCIceCandidate candidate)? onIceCandidate;
  void Function(String userId, RTCPeerConnectionState state)? onPeerConnectionState;

  MediaStream? get localStream => _localStream;

  /// What the local self-view should render: the screen-share stream while
  /// one is active, otherwise the camera. Peer connections get the track
  /// swap independently (see [startScreenShare]) — this is purely for the
  /// local preview to actually reflect what's being shared.
  MediaStream? get activeLocalStream => _screenStream ?? _localStream;

  Future<void> initLocalMedia(List<Map<String, dynamic>> iceServers) async {
    _iceServers = iceServers;
    _localStream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': {'facingMode': 'user'},
    });
    _cameraTrack = _localStream!.getVideoTracks().first;

    if (_recordingEnabled) {
      await _startRecording();
    }
  }

  /// Opts this device in as the call's recorder. Figuring out who the
  /// recorder is requires knowing the current user's id, which the caller
  /// only learns from an async `/auth/me` fetch that isn't guaranteed to
  /// resolve before [initLocalMedia] does — so this is safe to call either
  /// before or after: starts immediately if the local stream is already up,
  /// otherwise [initLocalMedia] picks up the flag once it finishes.
  Future<void> enableRecording() async {
    if (_recordingEnabled || _isHungUp) return;
    _recordingEnabled = true;
    if (_localStream != null) {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    final dir = await getTemporaryDirectory();

    _inputRecordingPath = '${dir.path}/call_input_${DateTime.now().microsecondsSinceEpoch}.mp4';
    _inputRecorder = MediaRecorder();
    _inputRecordingStartedAt = DateTime.now();
    await _inputRecorder!.start(_inputRecordingPath!, audioChannel: RecorderAudioChannel.INPUT);

    _outputRecordingPath = '${dir.path}/call_output_${DateTime.now().microsecondsSinceEpoch}.mp4';
    _outputRecorder = MediaRecorder();
    _outputRecordingStartedAt = DateTime.now();
    await _outputRecorder!.start(_outputRecordingPath!, audioChannel: RecorderAudioChannel.OUTPUT);
  }

  /// Populated once recording has been stopped (via [finishRecording] or
  /// [hangUp]). Empty when this device wasn't the recorder, or recording
  /// never started.
  List<RecordedTrack> recordedTracks = [];

  /// Stops both recorders (if running) without touching peer connections or
  /// the local stream — call sites need the finished files before the call
  /// is necessarily torn down (e.g. to upload while a "session ended"
  /// dialog is being prepared). Safe to call more than once, and safe to
  /// call before [hangUp] (which also stops recording, but is a no-op here
  /// by then) or standalone.
  Future<void> finishRecording() => _stopRecording();

  Future<void> _stopRecording() async {
    final inputRecorder = _inputRecorder;
    if (inputRecorder != null && _inputRecordingPath != null && _inputRecordingStartedAt != null) {
      _inputRecorder = null;
      try {
        await inputRecorder.stop();
        if (await File(_inputRecordingPath!).exists()) {
          recordedTracks.add(RecordedTrack(
            path: _inputRecordingPath!,
            label: 'me',
            startedAt: _inputRecordingStartedAt!,
          ));
        }
      } catch (_) {
        // Best-effort — a failed recording shouldn't block hanging up.
      }
    }

    final outputRecorder = _outputRecorder;
    if (outputRecorder != null && _outputRecordingPath != null && _outputRecordingStartedAt != null) {
      _outputRecorder = null;
      try {
        await outputRecorder.stop();
        if (await File(_outputRecordingPath!).exists()) {
          recordedTracks.add(RecordedTrack(
            path: _outputRecordingPath!,
            label: 'others',
            startedAt: _outputRecordingStartedAt!,
          ));
        }
      } catch (_) {
        // Best-effort — a failed recording shouldn't block hanging up.
      }
    }
  }

  Future<RTCPeerConnection> _ensurePeerConnection(String userId) async {
    final existing = _peerConnections[userId];
    if (existing != null) return existing;

    final pc = await createPeerConnection({'iceServers': _iceServers});
    _peerConnections[userId] = pc;

    for (final track in _localStream!.getTracks()) {
      await pc.addTrack(track, _localStream!);
    }

    pc.onTrack = (RTCTrackEvent event) {
      if (event.streams.isNotEmpty) {
        _remoteStreams[userId] = event.streams.first;
        _remoteStreamController.add(MapEntry(userId, event.streams.first));
      }
    };

    pc.onIceCandidate = (RTCIceCandidate candidate) {
      onIceCandidate?.call(userId, candidate);
    };

    pc.onConnectionState = (RTCPeerConnectionState state) {
      onPeerConnectionState?.call(userId, state);
    };

    return pc;
  }

  /// Called when joining a room to reach every already-present participant.
  Future<String> createOfferFor(String userId) async {
    final pc = await _ensurePeerConnection(userId);
    final offer = await pc.createOffer();
    await pc.setLocalDescription(offer);
    return offer.sdp!;
  }

  /// Called when a new participant's offer arrives — answers it.
  Future<String> createAnswerFor(String userId, String remoteSdp) async {
    final pc = await _ensurePeerConnection(userId);
    await pc.setRemoteDescription(RTCSessionDescription(remoteSdp, 'offer'));
    final answer = await pc.createAnswer();
    await pc.setLocalDescription(answer);
    return answer.sdp!;
  }

  Future<void> setRemoteAnswerFor(String userId, String sdp) async {
    final pc = _peerConnections[userId];
    if (pc == null) return;
    await pc.setRemoteDescription(RTCSessionDescription(sdp, 'answer'));
  }

  Future<void> addIceCandidateFor(
    String userId,
    String candidate,
    String? sdpMid,
    int? sdpMLineIndex,
  ) async {
    final pc = _peerConnections[userId];
    if (pc == null) return;
    await pc.addCandidate(RTCIceCandidate(candidate, sdpMid, sdpMLineIndex));
  }

  Future<void> closePeerConnectionFor(String userId) async {
    final pc = _peerConnections.remove(userId);
    await pc?.close();
    _remoteStreams.remove(userId);
    _remoteStreamController.add(MapEntry(userId, null));
  }

  /// Returns the new muted state.
  bool toggleMic() {
    final track = _firstOrNull(_localStream?.getAudioTracks());
    if (track == null) return false;
    track.enabled = !track.enabled;
    return !track.enabled;
  }

  /// Returns the new camera-off state.
  bool toggleCamera() {
    final track = _firstOrNull(_localStream?.getVideoTracks());
    if (track == null) return false;
    track.enabled = !track.enabled;
    return !track.enabled;
  }

  /// Captures the screen (Android MediaProjection) and swaps it onto every
  /// peer connection's outgoing video track via `replaceTrack` — no
  /// renegotiation needed for either side.
  Future<void> startScreenShare() async {
    if (WebRTC.platformIsAndroid) {
      // Android 14+ requires screen-capture consent to be granted *before*
      // a mediaProjection-typed foreground service is started — starting
      // the service first throws a SecurityException natively (which
      // crashes the whole app, not just this call) rather than a
      // catchable Dart exception. Consent first, then the service.
      final granted = await Helper.requestCapturePermission();
      if (!granted) {
        throw Exception('Screen capture permission was denied');
      }

      final initialized = await FlutterBackground.initialize(
        androidConfig: const FlutterBackgroundAndroidConfig(
          notificationTitle: 'Screen sharing',
          notificationText: 'Your screen is being shared in the call',
        ),
      );
      if (!initialized || !await FlutterBackground.enableBackgroundExecution()) {
        throw Exception('Could not start the screen-share foreground service');
      }
    }

    _screenStream = await navigator.mediaDevices.getDisplayMedia({'video': true, 'audio': false});
    final screenTrack = _screenStream!.getVideoTracks().first;

    for (final pc in _peerConnections.values) {
      final videoSender = _firstOrNull(
        (await pc.getSenders()).where((s) => s.track?.kind == 'video').toList(),
      );
      await videoSender?.replaceTrack(screenTrack);
    }
  }

  Future<void> stopScreenShare() async {
    if (_cameraTrack == null) return;

    for (final pc in _peerConnections.values) {
      final videoSender = _firstOrNull(
        (await pc.getSenders()).where((s) => s.track?.kind == 'video').toList(),
      );
      await videoSender?.replaceTrack(_cameraTrack);
    }

    await _screenStream?.dispose();
    _screenStream = null;

    if (WebRTC.platformIsAndroid && FlutterBackground.isBackgroundExecutionEnabled) {
      await FlutterBackground.disableBackgroundExecution();
    }
  }

  /// Idempotent — safe to call more than once (e.g. once from a
  /// session-ended signal and again from the owning Cubit's `close()`).
  Future<void> hangUp() async {
    if (_isHungUp) return;
    _isHungUp = true;

    if (_recordingEnabled) {
      await _stopRecording();
    }

    for (final pc in _peerConnections.values) {
      await pc.close();
    }
    _peerConnections.clear();
    _remoteStreams.clear();
    await _screenStream?.dispose();
    _screenStream = null;
    if (WebRTC.platformIsAndroid && FlutterBackground.isBackgroundExecutionEnabled) {
      await FlutterBackground.disableBackgroundExecution();
    }
    await _localStream?.dispose();
    await _remoteStreamController.close();
  }

  T? _firstOrNull<T>(List<T>? list) {
    if (list == null || list.isEmpty) return null;
    return list.first;
  }
}
