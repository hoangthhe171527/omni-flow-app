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

// Android freezes a channel's sound after first creation. v3 intentionally
// creates a fresh channel so existing installs receive the clearer bundled
// chime instead of retaining the quiet system default from v2.
const _androidChannelId = 'inbox_messages_v3';
const _androidSound = RawResourceAndroidNotificationSound(
  'omni_message_alert',
);

const _androidChannel = AndroidNotificationChannel(
  _androidChannelId,
  'Tin nhắn khách hàng',
  description: 'Thông báo khi khách hàng gửi tin nhắn mới.',
  importance: Importance.max,
  playSound: true,
  sound: _androidSound,
  enableVibration: true,
  audioAttributesUsage: AudioAttributesUsage.notificationEvent,
);

bool _pushRuntimeInitialized = false;

/// Installs the native FCM background callback before the Flutter widget tree
/// starts. Registering this after authentication is too late for a notification
/// that wakes a terminated Android process.
///
/// Firebase configuration is deliberately optional for development builds, so
/// callers may catch an initialization error and leave the rest of the app
/// usable.
Future<void> initializePushRuntime() async {
  if (_pushRuntimeInitialized || !_isAndroidRuntime) return;

  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  _pushRuntimeInitialized = true;
}

bool get _isAndroidRuntime =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

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
  Timer? _startupRetry;
  Timer? _registrationRetry;
  Timer? _registrationHeartbeat;
  bool _started = false;
  bool _firebaseReady = false;
  bool _registering = false;
  int _registrationAttempts = 0;
  String? _token;

  Future<void> start() async {
    if (_started || !_isAndroid) return;
    _started = true;
    _startupRetry?.cancel();
    _startupRetry = null;
    try {
      await initializePushRuntime();
      _firebaseReady = true;
      await _initializeLocalNotifications();

      // Install the listener before any registration network request. A slow
      // OmniCRM API must never leave a running app deaf to an FCM event.
      _tokenRefresh = FirebaseMessaging.instance.onTokenRefresh.listen(
        _register,
      );
      _foregroundMessages = FirebaseMessaging.onMessage.listen(_showForeground);
      // This stream fires only after the user taps an OS notification. Receiving
      // a push by itself must never navigate or bring a conversation forward.
      _openedMessages = FirebaseMessaging.onMessageOpenedApp.listen(
        _openFromNotificationTap,
      );

      await FirebaseMessaging.instance.requestPermission();
      _token = await FirebaseMessaging.instance.getToken();
      if (_token != null) await _register(_token!);
      _registrationHeartbeat?.cancel();
      _registrationHeartbeat = Timer.periodic(
        const Duration(minutes: 15),
        (_) => unawaited(ensureRegistered()),
      );
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) _openFromNotificationTap(initial);
    } catch (error, stackTrace) {
      // The inbox remains usable if Firebase or the network is temporarily down,
      // but push must heal in the SAME login session instead of waiting for the
      // user to kill and reopen the app.
      _firebaseReady = false;
      _started = false;
      debugPrint('Push startup failed: $error\n$stackTrace');
      _startupRetry?.cancel();
      _startupRetry = Timer(const Duration(seconds: 30), start);
    }
  }

  Future<void> stop() async {
    _startupRetry?.cancel();
    _registrationRetry?.cancel();
    _registrationHeartbeat?.cancel();
    _startupRetry = null;
    _registrationRetry = null;
    _registrationHeartbeat = null;
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
    _registrationAttempts = 0;
    _started = false;
  }

  /// Rebind the current installation whenever Android brings the app back.
  /// This repairs a missing server row without requiring logout/reinstall.
  Future<void> ensureRegistered() async {
    if (!_isAndroid) return;
    if (!_started) {
      await start();
      return;
    }
    if (!_firebaseReady) return;

    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) await _register(token);
    } catch (error, stackTrace) {
      debugPrint('Push registration refresh failed: $error\n$stackTrace');
      _scheduleRegistrationRetry();
    }
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
    if (_registering) return;
    _registering = true;
    try {
      await _ref.read(pushApiProvider).registerAndroid(token);
      _registrationAttempts = 0;
      _registrationRetry?.cancel();
      _registrationRetry = null;
      debugPrint('Push token registered with OmniCRM.');
    } on AppException catch (error, stackTrace) {
      // Token refresh must never break the authenticated session. Retry with a
      // capped backoff: this covers an API deploy/restart and flaky mobile data.
      debugPrint('Push token registration failed: $error\n$stackTrace');
      _scheduleRegistrationRetry();
    } finally {
      _registering = false;
    }
  }

  void _scheduleRegistrationRetry() {
    _registrationRetry?.cancel();
    final seconds = switch (_registrationAttempts++) {
      0 => 15,
      1 => 60,
      _ => 300,
    };
    _registrationRetry = Timer(Duration(seconds: seconds), () {
      final token = _token;
      if (_started && token != null) unawaited(_register(token));
    });
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
          _androidChannelId,
          'Tin nhắn khách hàng',
          channelDescription: 'Thông báo khi khách hàng gửi tin nhắn mới.',
          importance: Importance.max,
          priority: Priority.max,
          playSound: true,
          sound: _androidSound,
          enableVibration: true,
          audioAttributesUsage: AudioAttributesUsage.notificationEvent,
          category: AndroidNotificationCategory.message,
          fullScreenIntent: false,
        ),
      ),
      payload: jsonEncode(message.data),
    );
  }

  void _openFromNotificationTap(RemoteMessage message) {
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
