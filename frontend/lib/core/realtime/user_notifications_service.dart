import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../network/api_config.dart';
import '../network/secure_storage_keys.dart';

// Must match NotificationMessageType.SESSIONS_CHANGED in
// backend/src/modules/sessions/signaling/signaling.types.ts.
const _sessionsChangedType = 'sessions-changed';

const _initialBackoff = Duration(seconds: 1);
const _maxBackoff = Duration(seconds: 15);

/// One persistent WebSocket per logged-in session, separate from
/// [SignalingService]'s per-session sockets — this is a personal push
/// channel ("something about your sessions changed, go refetch") that stays
/// connected regardless of which session, if any, is currently open.
/// Reconnects with backoff on an unexpected close, mirroring SignalingService.
class UserNotificationsService {
  final FlutterSecureStorage storage;

  WebSocketChannel? _channel;
  StreamSubscription? _channelSubscription;
  final _sessionsChangedController = StreamController<void>.broadcast();
  bool _isDisposing = false;
  Duration _backoff = _initialBackoff;

  UserNotificationsService({required this.storage});

  Stream<void> get sessionsChanged => _sessionsChangedController.stream;

  Future<void> connect() async {
    if (_channel != null) return;
    try {
      final token = await storage.read(key: SecureStorageKeys.accessToken);
      if (token == null) return; // not signed in yet — nothing to connect for

      final wsBase = ApiConfig.baseUrl.replaceFirst(RegExp(r'^http'), 'ws');
      final channel = WebSocketChannel.connect(Uri.parse('$wsBase/users/ws?token=$token'));
      await channel.ready;
      _channel = channel;
      _backoff = _initialBackoff;

      _channelSubscription = channel.stream.listen(
        _handleRawMessage,
        onDone: _handleUnexpectedClose,
        onError: (_) => _handleUnexpectedClose(),
        cancelOnError: true,
      );
    } catch (_) {
      _handleUnexpectedClose();
    }
  }

  void _handleRawMessage(dynamic raw) {
    try {
      final json = jsonDecode(raw as String) as Map<String, dynamic>;
      if (json['type'] == _sessionsChangedType) {
        _sessionsChangedController.add(null);
      }
    } catch (_) {
      // Malformed frame — ignore rather than crash the stream.
    }
  }

  void _handleUnexpectedClose() {
    _channelSubscription = null;
    _channel = null;
    if (_isDisposing) return;

    Future.delayed(_backoff, connect);
    _backoff = Duration(seconds: (_backoff.inSeconds * 2).clamp(1, _maxBackoff.inSeconds));
  }

  Future<void> dispose() async {
    if (_isDisposing) return;
    _isDisposing = true;
    await _channelSubscription?.cancel();
    await _channel?.sink.close();
    await _sessionsChangedController.close();
  }
}
