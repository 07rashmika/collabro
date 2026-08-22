import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:frontend/core/constants/app_routes.dart';
import 'package:frontend/core/router/app_router.dart';
import 'package:frontend/features/users/domain/repos/users_repo.dart';

/// Must match the channel id the backend puts on `android.notification.channelId`
/// (see backend/src/modules/notifications/push.service.ts) and the
/// `com.google.firebase.messaging.default_notification_channel_id` meta-data
/// in AndroidManifest.xml — all three need to agree on the same channel.
const _highImportanceChannel = AndroidNotificationChannel(
  'high_importance_channel',
  'Notifications',
  description: 'Messages, connection requests, and session invites',
  importance: Importance.high,
);

/// Requests notification permission, grabs the device's FCM token, and
/// keeps the backend's copy of it up to date (registers it on startup,
/// re-registers whenever Firebase rotates it).
///
/// Also creates a high-importance Android notification channel — without
/// one, FCM falls back to its own default channel at IMPORTANCE_DEFAULT,
/// which only ever lands silently in the shade and never pops up as a
/// heads-up banner. Actually *displaying* a notification while the app is
/// backgrounded/terminated is otherwise handled by Android itself, using
/// that channel. While the app is open, live updates already arrive over
/// the existing WebSocket channel (see UserNotificationsService), so
/// foreground pushes are intentionally left unhandled rather than shown
/// twice.
class PushNotificationsService {
  final UsersRepo usersRepo;
  final _localNotifications = FlutterLocalNotificationsPlugin();
  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<RemoteMessage>? _openedAppSubscription;

  PushNotificationsService({required this.usersRepo});

  Future<void> start() async {
    final messaging = FirebaseMessaging.instance;

    final settings = await messaging.requestPermission();
    if (settings.authorizationStatus == AuthorizationStatus.denied) return;

    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_highImportanceChannel);

    final token = await messaging.getToken();
    if (token != null) {
      await _register(token);
    }

    _tokenRefreshSubscription = messaging.onTokenRefresh.listen(_register);

    // Tapping the notification while the app was backgrounded (not killed)
    // fires here; a cold start from a terminated app instead surfaces the
    // same RemoteMessage through getInitialMessage() below. PushNotifications
    // Service itself only ever starts once MainShell has mounted (i.e. past
    // auth/splash), so it's always safe to navigate immediately here.
    _openedAppSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
      _handleTap,
    );
    final initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) _handleTap(initialMessage);
  }

  /// Routes a tapped notification to the screen it's actually about — the
  /// request/invite living in the Notifications screen (with its
  /// Accept/Decline actions) or the sessions list, rather than just resuming
  /// the app on whatever screen it happened to be on before it backgrounded.
  void _handleTap(RemoteMessage message) {
    switch (message.data['type']) {
      case 'CONNECTION_REQUEST':
      case 'CONNECTION_ACCEPTED':
        AppRouter.router.go(AppRoutes.notifications);
      case 'SESSION_INVITE':
      case 'NEW_MESSAGE':
        AppRouter.router.go(AppRoutes.sessions);
    }
  }

  Future<void> _register(String token) async {
    try {
      await usersRepo.registerDeviceToken(token);
    } catch (_) {
      // Best-effort — a missed registration just means this device won't
      // get pushes until the next successful attempt (e.g. next launch).
    }
  }

  void dispose() {
    _tokenRefreshSubscription?.cancel();
    _openedAppSubscription?.cancel();
  }
}
