import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:frontend/core/constants/app_routes.dart';
import 'package:frontend/core/router/app_router.dart';
import 'package:frontend/features/users/domain/repos/users_repo.dart';

const _highImportanceChannel = AndroidNotificationChannel(
  'high_importance_channel',
  'Notifications',
  description: 'Messages, connection requests, and session invites',
  importance: Importance.high,
);

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

    _openedAppSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
      _handleTap,
    );
    final initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) _handleTap(initialMessage);
  }

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
      // Best-effort - a missed registration just means this device won't
      // get pushes until the next successful attempt (e.g. next launch).
    }
  }

  void dispose() {
    _tokenRefreshSubscription?.cancel();
    _openedAppSubscription?.cancel();
  }
}
