import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:frontend/core/network/secure_storage_keys.dart';

class NotificationPreferences extends Equatable {
  final bool messageNotifications;
  final bool connectionNotifications;
  final bool videoSessionNotifications;

  const NotificationPreferences({
    this.messageNotifications = true,
    this.connectionNotifications = true,
    this.videoSessionNotifications = true,
  });

  // The main toggle reflects the group, not a separately stored value —
  // any category on counts as notifications being "received"; only when
  // every category is off does the app consider them fully off.
  bool get anyEnabled =>
      messageNotifications ||
      connectionNotifications ||
      videoSessionNotifications;

  @override
  List<Object?> get props => [
    messageNotifications,
    connectionNotifications,
    videoSessionNotifications,
  ];
}

/// This only stores the user's preference locally, for now — it's not
/// wired to anything that actually sends push notifications yet, that's a
/// separate follow-up. Once push delivery exists, the backend will need to
/// know these too so it can decide whether to send.
class NotificationPreferencesCubit extends Cubit<NotificationPreferences> {
  final FlutterSecureStorage storage;

  NotificationPreferencesCubit({required this.storage})
    : super(const NotificationPreferences()) {
    _load();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      storage.read(key: SecureStorageKeys.notifyMessages),
      storage.read(key: SecureStorageKeys.notifyConnections),
      storage.read(key: SecureStorageKeys.notifyVideoSessions),
    ]);
    emit(
      NotificationPreferences(
        messageNotifications: results[0] != 'false',
        connectionNotifications: results[1] != 'false',
        videoSessionNotifications: results[2] != 'false',
      ),
    );
  }

  Future<void> setMessageNotifications(bool value) async {
    emit(
      NotificationPreferences(
        messageNotifications: value,
        connectionNotifications: state.connectionNotifications,
        videoSessionNotifications: state.videoSessionNotifications,
      ),
    );
    await storage.write(
      key: SecureStorageKeys.notifyMessages,
      value: value.toString(),
    );
  }

  Future<void> setConnectionNotifications(bool value) async {
    emit(
      NotificationPreferences(
        messageNotifications: state.messageNotifications,
        connectionNotifications: value,
        videoSessionNotifications: state.videoSessionNotifications,
      ),
    );
    await storage.write(
      key: SecureStorageKeys.notifyConnections,
      value: value.toString(),
    );
  }

  Future<void> setVideoSessionNotifications(bool value) async {
    emit(
      NotificationPreferences(
        messageNotifications: state.messageNotifications,
        connectionNotifications: state.connectionNotifications,
        videoSessionNotifications: value,
      ),
    );
    await storage.write(
      key: SecureStorageKeys.notifyVideoSessions,
      value: value.toString(),
    );
  }

  /// Turning the main toggle on/off cascades to every category.
  Future<void> setAll(bool value) async {
    emit(
      NotificationPreferences(
        messageNotifications: value,
        connectionNotifications: value,
        videoSessionNotifications: value,
      ),
    );
    await Future.wait([
      storage.write(
        key: SecureStorageKeys.notifyMessages,
        value: value.toString(),
      ),
      storage.write(
        key: SecureStorageKeys.notifyConnections,
        value: value.toString(),
      ),
      storage.write(
        key: SecureStorageKeys.notifyVideoSessions,
        value: value.toString(),
      ),
    ]);
  }
}
