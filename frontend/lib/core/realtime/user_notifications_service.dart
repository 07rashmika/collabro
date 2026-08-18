import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../network/api_config.dart';
import '../network/secure_storage_keys.dart';
import '../network/token_refresher.dart';

const _sessionsChangedType = 'sessions-changed';
const _notificationsChangedType = 'notifications-changed';

const _initialBackoff = Duration(seconds: 1);
const _maxBackoff = Duration(seconds: 15);

class UserNotificationsService {
  final FlutterSecureStorage storage;
  late final TokenRefresher _tokenRefresher;

  WebSocketChannel? _channel;
  StreamSubscription? _channelSubscription;
  final _sessionsChangedController = StreamController<void>.broadcast();
  final _notificationsChangedController = StreamController<void>.broadcast();
  bool _isDisposing = false;
  Duration _backoff = _initialBackoff;

  UserNotificationsService({required this.storage}) {
    _tokenRefresher = TokenRefresher(storage: storage);
  }

  Stream<void> get sessionsChanged => _sessionsChangedController.stream;
  Stream<void> get notificationsChanged =>
      _notificationsChangedController.stream;

  Future<void> connect() async {
    if (_channel != null) return;
    try {
      final token = await storage.read(key: SecureStorageKeys.accessToken);
      if (token == null) return;

      final wsBase = ApiConfig.baseUrl.replaceFirst(RegExp(r'^http'), 'ws');
      final channel = WebSocketChannel.connect(
        Uri.parse('$wsBase/users/ws?token=$token'),
      );
      await channel.ready;
      _channel = channel;
      _backoff = _initialBackoff;

      _channelSubscription = channel.stream.listen(
        _handleRawMessage,
        onDone: _handleUnexpectedClose,
        onError: (error) => _handleUnexpectedClose(),
        cancelOnError: true,
      );
    } catch (error) {
      await _tokenRefresher.refresh();
      _handleUnexpectedClose();
    }
  }

  void _handleRawMessage(dynamic raw) {
    try {
      final json = jsonDecode(raw as String) as Map<String, dynamic>;
      if (json['type'] == _sessionsChangedType) {
        _sessionsChangedController.add(null);
      } else if (json['type'] == _notificationsChangedType) {
        _notificationsChangedController.add(null);
      }
    } catch (error) {
      //malformed frame — ignore rather than crash the stream.
      print('Malformed frame: $error');
    }
  }

  void _handleUnexpectedClose() {
    _channelSubscription = null;
    _channel = null;
    if (_isDisposing) return;

    Future.delayed(_backoff, connect);
    _backoff = Duration(
      seconds: (_backoff.inSeconds * 2).clamp(1, _maxBackoff.inSeconds),
    );
  }

  Future<void> dispose() async {
    if (_isDisposing) return;
    _isDisposing = true;
    await _channelSubscription?.cancel();
    await _channel?.sink.close();
    await _sessionsChangedController.close();
    await _notificationsChangedController.close();
  }
}
