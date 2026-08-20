import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_background/flutter_background.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:path_provider/path_provider.dart';

class RecordedTrack {
  final String path;
  final String label;
  final DateTime startedAt;

  const RecordedTrack({
    required this.path,
    required this.label,
    required this.startedAt,
  });
}

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

  final _remoteStreamController =
      StreamController<MapEntry<String, MediaStream?>>.broadcast();

  Stream<MapEntry<String, MediaStream?>> get onRemoteStream =>
      _remoteStreamController.stream;

  void Function(String targetUserId, RTCIceCandidate candidate)? onIceCandidate;
  void Function(String userId, RTCPeerConnectionState state)?
  onPeerConnectionState;

  MediaStream? get localStream => _localStream;

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

  Future<void> enableRecording() async {
    if (_recordingEnabled || _isHungUp) return;
    debugPrint(
      '[WebRTC] Recording enabled for this device (localStream up: ${_localStream != null})',
    );
    _recordingEnabled = true;
    if (_localStream != null) {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    final dir = await getTemporaryDirectory();

    _inputRecordingPath =
        '${dir.path}/call_input_${DateTime.now().microsecondsSinceEpoch}.mp4';
    _inputRecorder = MediaRecorder();
    _inputRecordingStartedAt = DateTime.now();
    await _inputRecorder!.start(
      _inputRecordingPath!,
      audioChannel: RecorderAudioChannel.INPUT,
    );
    debugPrint('[WebRTC] Started INPUT recorder → $_inputRecordingPath');

    _outputRecordingPath =
        '${dir.path}/call_output_${DateTime.now().microsecondsSinceEpoch}.mp4';
    _outputRecorder = MediaRecorder();
    _outputRecordingStartedAt = DateTime.now();
    await _outputRecorder!.start(
      _outputRecordingPath!,
      audioChannel: RecorderAudioChannel.OUTPUT,
    );
    debugPrint('[WebRTC] Started OUTPUT recorder → $_outputRecordingPath');
  }

  List<RecordedTrack> recordedTracks = [];

  Future<void> finishRecording() => _stopRecording();

  Future<void> _stopRecording() async {
    final inputRecorder = _inputRecorder;
    if (inputRecorder != null &&
        _inputRecordingPath != null &&
        _inputRecordingStartedAt != null) {
      _inputRecorder = null;
      try {
        await inputRecorder.stop();
        final file = File(_inputRecordingPath!);
        if (await file.exists()) {
          final size = await file.length();
          debugPrint(
            '[WebRTC] INPUT recording stopped: $_inputRecordingPath ($size bytes)',
          );
          recordedTracks.add(
            RecordedTrack(
              path: _inputRecordingPath!,
              label: 'me',
              startedAt: _inputRecordingStartedAt!,
            ),
          );
        } else {
          debugPrint(
            '[WebRTC] INPUT recorder stopped but no file was produced at $_inputRecordingPath',
          );
        }
      } catch (e) {
        //best-effort — a failed recording shouldn't block hanging up.
        debugPrint('[WebRTC] Failed to stop INPUT recorder: $e');
      }
    }

    final outputRecorder = _outputRecorder;
    if (outputRecorder != null &&
        _outputRecordingPath != null &&
        _outputRecordingStartedAt != null) {
      _outputRecorder = null;
      try {
        await outputRecorder.stop();
        final file = File(_outputRecordingPath!);
        if (await file.exists()) {
          final size = await file.length();
          debugPrint(
            '[WebRTC] OUTPUT recording stopped: $_outputRecordingPath ($size bytes)',
          );
          recordedTracks.add(
            RecordedTrack(
              path: _outputRecordingPath!,
              label: 'others',
              startedAt: _outputRecordingStartedAt!,
            ),
          );
        } else {
          debugPrint(
            '[WebRTC] OUTPUT recorder stopped but no file was produced at $_outputRecordingPath',
          );
        }
      } catch (e) {
        // Best-effort — a failed recording shouldn't block hanging up.
        debugPrint('[WebRTC] Failed to stop OUTPUT recorder: $e');
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

  Future<String> createOfferFor(String userId) async {
    final pc = await _ensurePeerConnection(userId);
    final offer = await pc.createOffer();
    await pc.setLocalDescription(offer);
    return offer.sdp!;
  }

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

  bool toggleMic() {
    final track = _firstOrNull(_localStream?.getAudioTracks());
    if (track == null) return false;
    track.enabled = !track.enabled;
    return !track.enabled;
  }

  bool toggleCamera() {
    final track = _firstOrNull(_localStream?.getVideoTracks());
    if (track == null) return false;
    track.enabled = !track.enabled;
    return !track.enabled;
  }

  Future<void> startScreenShare() async {
    if (WebRTC.platformIsAndroid) {
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
      if (!initialized ||
          !await FlutterBackground.enableBackgroundExecution()) {
        throw Exception('Could not start the screen-share foreground service');
      }
    }

    _screenStream = await navigator.mediaDevices.getDisplayMedia({
      'video': true,
      'audio': false,
    });
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

    if (WebRTC.platformIsAndroid &&
        FlutterBackground.isBackgroundExecutionEnabled) {
      await FlutterBackground.disableBackgroundExecution();
    }
  }

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
    if (WebRTC.platformIsAndroid &&
        FlutterBackground.isBackgroundExecutionEnabled) {
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
