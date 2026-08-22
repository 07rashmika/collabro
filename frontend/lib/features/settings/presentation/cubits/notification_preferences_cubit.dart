import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:frontend/core/network/secure_storage_keys.dart';
import 'package:frontend/features/users/domain/repos/users_repo.dart';

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

/// Stores the user's preference locally (for instant UI on launch) and
/// syncs each change up to the backend, which mirrors these on the User
/// row — that's what the push-sending code actually checks before sending,
/// since the on-device copy alone never reaches the server otherwise.
class NotificationPreferencesCubit extends Cubit<NotificationPreferences> {
  final FlutterSecureStorage storage;
  final UsersRepo usersRepo;

  NotificationPreferencesCubit({required this.storage, required this.usersRepo})
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
    _syncToBackend(notifyMessages: value);
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
    _syncToBackend(notifyConnections: value);
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
    _syncToBackend(notifyVideoSessions: value);
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
    _syncToBackend(
      notifyMessages: value,
      notifyConnections: value,
      notifyVideoSessions: value,
    );
  }

  /// Fire-and-forget — the local write above is already the source of
  /// truth for this device's UI, so a failed sync here (offline, etc.)
  /// shouldn't block or roll back the toggle the user just flipped.
  Future<void> _syncToBackend({
    bool? notifyMessages,
    bool? notifyConnections,
    bool? notifyVideoSessions,
  }) async {
    try {
      await usersRepo.updateNotificationPreferences(
        notifyMessages: notifyMessages,
        notifyConnections: notifyConnections,
        notifyVideoSessions: notifyVideoSessions,
      );
    } catch (_) {
      // Local state already reflects the change; the backend will pick it
      // up next time a toggle is flipped or the value is otherwise synced.
    }
  }
}
