import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_exception.dart';
import '../../inbox/application/inbox_providers.dart';
import '../data/push_api.dart';

const _androidChannel = AndroidNotificationChannel(
  'inbox_messages',
  'Tin nhắn khách hàng',
  description: 'Thông báo khi khách hàng gửi tin nhắn mới.',
  importance: Importance.max,
);

/// A deliberately small, routing-only payload. Notification text is for the
/// lock screen; navigation always uses the conversation id and reloads data.
class PushIntent {
  const PushIntent({required this.conversationId});

  final String conversationId;

  static PushIntent? fromData(Map<String, dynamic> data) {
    if (data['type'] != 'inbox_message') return null;
    final id = data['conversation_id']?.toString() ?? '';
    return id.isEmpty ? null : PushIntent(conversationId: id);
  }
}

final pushIntentProvider = StateProvider<PushIntent?>((ref) => null);

/// Required by FCM for Android background delivery. Do not do navigation or
/// network work here: Android gives the isolate only a short execution window.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

class PushNotifications {
  PushNotifications(this._ref);

  final Ref _ref;
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();
  StreamSubscription<String>? _tokenRefresh;
  StreamSubscription<RemoteMessage>? _foregroundMessages;
  StreamSubscription<RemoteMessage>? _openedMessages;
  bool _started = false;
  bool _firebaseReady = false;
  String? _token;

  Future<void> start() async {
    if (_started || !_isAndroid) return;
    _started = true;
    try {
      await Firebase.initializeApp();
      _firebaseReady = true;
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      await _initializeLocalNotifications();
      await FirebaseMessaging.instance.requestPermission();
      _token = await FirebaseMessaging.instance.getToken();
      if (_token != null) await _register(_token!);

      _tokenRefresh = FirebaseMessaging.instance.onTokenRefresh.listen(
        _register,
      );
      _foregroundMessages = FirebaseMessaging.onMessage.listen(_showForeground);
      _openedMessages = FirebaseMessaging.onMessageOpenedApp.listen(_open);
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) _open(initial);
    } catch (_) {
      // The app remains usable when a development build has no Firebase config.
      // Registration retries at the next authenticated app launch.
      _firebaseReady = false;
    }
  }

  Future<void> stop() async {
    await _tokenRefresh?.cancel();
    await _foregroundMessages?.cancel();
    await _openedMessages?.cancel();
    _tokenRefresh = null;
    _foregroundMessages = null;
    _openedMessages = null;
    if (_firebaseReady && _token != null) {
      try {
        await _ref.read(pushApiProvider).unregister(_token!);
      } on AppException {
        // Local logout wins; a stale token is harmless because the next login
        // moves it to the current tenant/user.
      }
    }
    _token = null;
    _started = false;
  }

  Future<void> _initializeLocalNotifications() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _local.initialize(
      const InitializationSettings(android: android),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload == null) return;
        try {
          final data = jsonDecode(payload) as Map<String, dynamic>;
          final intent = PushIntent.fromData(data);
          if (intent != null) {
            _ref.read(pushIntentProvider.notifier).state = intent;
          }
        } catch (_) {}
      },
    );
    await _local
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_androidChannel);
  }

  Future<void> _register(String token) async {
    _token = token;
    try {
      await _ref.read(pushApiProvider).registerAndroid(token);
    } on AppException {
      // Token refresh must never break the authenticated session.
    }
  }

  Future<void> _showForeground(RemoteMessage message) async {
    if (PushIntent.fromData(message.data) != null) {
      final signal = _ref.read(inboxRealtimeSignalProvider.notifier);
      signal.state = signal.state + 1;
    }
    final notification = message.notification;
    await _local.show(
      message.messageId?.hashCode ?? DateTime.now().microsecondsSinceEpoch,
      notification?.title ?? 'Tin nhắn mới',
      notification?.body ?? 'Khách hàng vừa gửi tin nhắn.',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'inbox_messages',
          'Tin nhắn khách hàng',
          channelDescription: 'Thông báo khi khách hàng gửi tin nhắn mới.',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
      payload: jsonEncode(message.data),
    );
  }

  void _open(RemoteMessage message) {
    final intent = PushIntent.fromData(message.data);
    if (intent != null) _ref.read(pushIntentProvider.notifier).state = intent;
  }

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
}

final pushNotificationsProvider = Provider<PushNotifications>((ref) {
  final notifications = PushNotifications(ref);
  ref.onDispose(notifications.stop);
  return notifications;
});
