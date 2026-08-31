import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../inbox/application/inbox_providers.dart';
import '../data/push_api.dart';

// Android freezes a channel's sound after first creation. v4 intentionally
// creates a fresh channel so installs that received a silent v3 channel get
// the bundled alert sound.
const _androidChannelId = 'inbox_messages_v4';
const _tokenRefreshGenerationKey = 'fcm_token_refresh_generation';
// Bump when a release must rebind the installation. This repairs devices that
// kept an FCM token locally while its server-side row was removed/invalidated.
const _tokenRefreshGeneration = 3;
const _androidSound = RawResourceAndroidNotificationSound('omni_message_alert');

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
/// that wakes a terminated Android or iOS process.
///
/// Firebase configuration is deliberately optional for development builds, so
/// callers may catch an initialization error and leave the rest of the app
/// usable.
Future<void> initializePushRuntime() async {
  final platform = _runtimePushPlatform;
  if (_pushRuntimeInitialized || platform == null) return;

  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    _pushRuntimeInitialized = true;
  } catch (error, stackTrace) {
    debugPrint(
      'Push runtime initialization failed [$platform]: '
      '$error\n$stackTrace',
    );
    rethrow;
  }
}

String? get _runtimePushPlatform =>
    kIsWeb ? null : pushPlatformForTarget(defaultTargetPlatform);

@visibleForTesting
String? pushPlatformForTarget(TargetPlatform platform) => switch (platform) {
  TargetPlatform.android => 'android',
  TargetPlatform.iOS => 'ios',
  _ => null,
};

@visibleForTesting
Future<String> waitForApnsToken({
  required Future<String?> Function() readToken,
  Future<void> Function(Duration)? delay,
  int maxAttempts = 20,
  Duration retryDelay = const Duration(milliseconds: 500),
}) async {
  if (maxAttempts < 1) {
    throw ArgumentError.value(maxAttempts, 'maxAttempts', 'must be positive');
  }

  for (var attempt = 1; attempt <= maxAttempts; attempt++) {
    final token = await readToken();
    if (token != null && token.isNotEmpty) return token;
    if (attempt < maxAttempts) {
      await (delay?.call(retryDelay) ?? Future<void>.delayed(retryDelay));
    }
  }

  throw StateError('APNs token was unavailable after $maxAttempts attempts.');
}

@visibleForTesting
bool shouldShowLocalForegroundNotification({
  required String platform,
  required bool hasRemoteNotification,
}) => platform == 'android' || !hasRemoteNotification;

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

/// Required by FCM for background delivery. Do not do navigation or network
/// work here: the platform gives this isolate only a short execution window.
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
  int _lifecycleGeneration = 0;
  String? _token;

  Future<void> start() async {
    final platform = _runtimePushPlatform;
    if (_started || platform == null) return;
    _started = true;
    final generation = ++_lifecycleGeneration;
    _startupRetry?.cancel();
    _startupRetry = null;
    try {
      await initializePushRuntime();
      if (!_isActive(generation)) return;
      _firebaseReady = true;
      // Keep Firebase's registration sync enabled explicitly. This repairs
      // installations restored or upgraded across Firebase SDK generations,
      // where a cached token can still be accepted by FCM but receive nothing.
      await FirebaseMessaging.instance.setAutoInitEnabled(true);
      await _initializeLocalNotifications();
      if (!_isActive(generation)) return;

      // Install the listener before any registration network request. A slow
      // Viomni API must never leave a running app deaf to an FCM event.
      _tokenRefresh = FirebaseMessaging.instance.onTokenRefresh.listen(
        _register,
      );
      _foregroundMessages = FirebaseMessaging.onMessage.listen(_showForeground);
      // This stream fires only after the user taps an OS notification. Receiving
      // a push by itself must never navigate or bring a conversation forward.
      _openedMessages = FirebaseMessaging.onMessageOpenedApp.listen(
        _openFromNotificationTap,
      );

      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      if (!_isActive(generation)) return;
      debugPrint(
        'Push authorization [$platform]: ${settings.authorizationStatus}',
      );
      if (platform == 'ios') {
        await FirebaseMessaging.instance
            .setForegroundNotificationPresentationOptions(
              alert: true,
              badge: true,
              sound: true,
            );
      }
      _token = await _refreshStaleTokenOnce(platform);
      if (!_isActive(generation)) return;
      if (_token != null) await _register(_token!);
      if (!_isActive(generation)) return;
      _registrationHeartbeat?.cancel();
      _registrationHeartbeat = Timer.periodic(
        const Duration(minutes: 15),
        (_) => unawaited(ensureRegistered()),
      );
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) _openFromNotificationTap(initial);
    } catch (error, stackTrace) {
      if (!_isActive(generation)) return;
      // The inbox remains usable if Firebase or the network is temporarily down,
      // but push must heal in the SAME login session instead of waiting for the
      // user to kill and reopen the app.
      _firebaseReady = false;
      _started = false;
      await _cancelListeners();
      debugPrint('Push startup failed [$platform]: $error\n$stackTrace');
      _startupRetry?.cancel();
      _startupRetry = Timer(const Duration(seconds: 30), start);
    }
  }

  Future<void> stop() async {
    final generation = ++_lifecycleGeneration;
    _started = false;
    _firebaseReady = false;
    _startupRetry?.cancel();
    _registrationRetry?.cancel();
    _registrationHeartbeat?.cancel();
    _startupRetry = null;
    _registrationRetry = null;
    _registrationHeartbeat = null;
    final token = _token;
    _token = null;
    _registrationAttempts = 0;
    await _cancelListeners();
    if (token != null && !_started && generation == _lifecycleGeneration) {
      await _unregisterSafely(token, reason: 'stop');
    }
  }

  /// Rebind the current installation whenever the mobile app comes back.
  /// This repairs a missing server row without requiring logout/reinstall.
  Future<void> ensureRegistered() async {
    final platform = _runtimePushPlatform;
    if (platform == null) return;
    if (!_started) {
      await start();
      return;
    }
    if (!_firebaseReady) return;

    try {
      final token = await _getFcmToken(platform);
      if (token != null && token.isNotEmpty) await _register(token);
    } catch (error, stackTrace) {
      debugPrint(
        'Push registration refresh failed [$platform]: '
        '$error\n$stackTrace',
      );
      if (_started) _scheduleRegistrationRetry();
    }
  }

  Future<void> _initializeLocalNotifications() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _local.initialize(
      const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: (response) =>
          _openFromLocalNotificationPayload(response.payload),
    );
    await _local
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_androidChannel);
    final launchDetails = await _local.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp ?? false) {
      _openFromLocalNotificationPayload(
        launchDetails?.notificationResponse?.payload,
      );
    }
  }

  Future<void> _register(String token) async {
    final platform = _runtimePushPlatform;
    if (!_started || platform == null) return;
    _token = token;
    if (_registering) return;
    _registering = true;
    final generation = _lifecycleGeneration;
    final registeringToken = token;
    try {
      await _ref.read(pushApiProvider).register(registeringToken, platform);
      if (!_isActive(generation)) {
        await _unregisterSafely(
          registeringToken,
          reason: 'registration completed after stop',
        );
        return;
      }
      _registrationAttempts = 0;
      _registrationRetry?.cancel();
      _registrationRetry = null;
      debugPrint('Push token registered with Viomni [$platform].');
    } catch (error, stackTrace) {
      // Token refresh must never break the authenticated session. Retry with a
      // capped backoff: this covers an API deploy/restart and flaky mobile data.
      debugPrint(
        'Push token registration failed [$platform]: $error\n$stackTrace',
      );
      if (_isActive(generation)) _scheduleRegistrationRetry();
    } finally {
      _registering = false;
      final latestToken = _token;
      final lifecycleChanged = generation != _lifecycleGeneration;
      if (_started &&
          latestToken != null &&
          (lifecycleChanged || latestToken != registeringToken)) {
        unawaited(_register(latestToken));
      }
    }
  }

  /// Repairs registrations created before background push was enabled.
  ///
  /// FCM may keep accepting an obsolete token for a short period after an app
  /// update even though that installation no longer receives messages. Rotate
  /// it once for this migration, unregister the old value, then let the normal
  /// refresh listener maintain it from that point forward.
  Future<String?> _refreshStaleTokenOnce(String platform) async {
    final preferences = await SharedPreferences.getInstance();
    if ((preferences.getInt(_tokenRefreshGenerationKey) ?? 0) >=
        _tokenRefreshGeneration) {
      return _getFcmToken(platform);
    }

    final previous = await _getFcmToken(platform);
    if (previous != null && previous.isNotEmpty) {
      await _unregisterSafely(previous, reason: 'stale token rotation');
    }

    await FirebaseMessaging.instance.deleteToken();
    final replacement = await _getFcmToken(platform);
    if (replacement == null || replacement.isEmpty) {
      throw StateError('FCM did not issue a replacement token.');
    }
    await preferences.setInt(
      _tokenRefreshGenerationKey,
      _tokenRefreshGeneration,
    );
    return replacement;
  }

  Future<String?> _getFcmToken(String platform) async {
    if (platform == 'ios') {
      await waitForApnsToken(
        readToken: FirebaseMessaging.instance.getAPNSToken,
      );
    }
    return FirebaseMessaging.instance.getToken();
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
    final platform = _runtimePushPlatform;
    if (platform == null) return;
    if (PushIntent.fromData(message.data) != null) {
      final signal = _ref.read(inboxRealtimeSignalProvider.notifier);
      signal.state = signal.state + 1;
    }
    final notification = message.notification;
    if (!shouldShowLocalForegroundNotification(
      platform: platform,
      hasRemoteNotification: notification != null,
    )) {
      // Firebase presents iOS notification messages using the foreground
      // options configured in start(). Showing another local alert duplicates
      // the same customer message. Data-only messages still need a local alert.
      return;
    }
    final title = notification?.title ?? 'Tin nhắn mới';
    final body = notification?.body ?? 'Khách hàng vừa gửi tin nhắn.';
    final senderName = message.data['sender_name']?.toString().trim() ?? '';
    final sourceLabel = message.data['source_label']?.toString().trim() ?? '';
    final conversationId =
        message.data['conversation_id']?.toString().trim() ?? '';
    final isGroup = message.data['is_group']?.toString() == '1';
    final messagingStyle = senderName.isEmpty
        ? null
        : MessagingStyleInformation(
            const Person(name: 'Viomni', key: 'viomni'),
            conversationTitle: sourceLabel.isNotEmpty ? sourceLabel : title,
            groupConversation: isGroup,
            messages: [
              Message(
                body,
                message.sentTime ?? DateTime.now(),
                Person(
                  name: senderName,
                  key: 'customer-${senderName.hashCode}',
                  important: true,
                ),
              ),
            ],
          );
    await _local.show(
      conversationId.isNotEmpty
          ? conversationId.hashCode & 0x7fffffff
          : message.messageId?.hashCode ??
                DateTime.now().microsecondsSinceEpoch,
      title,
      body,
      NotificationDetails(
        android: platform == 'android'
            ? AndroidNotificationDetails(
                _androidChannelId,
                'Tin nhắn khách hàng',
                channelDescription:
                    'Thông báo khi khách hàng gửi tin nhắn mới.',
                importance: Importance.max,
                priority: Priority.max,
                playSound: true,
                sound: _androidSound,
                enableVibration: true,
                audioAttributesUsage: AudioAttributesUsage.notificationEvent,
                category: AndroidNotificationCategory.message,
                fullScreenIntent: false,
                styleInformation: messagingStyle,
              )
            : null,
        iOS: platform == 'ios'
            ? DarwinNotificationDetails(
                presentAlert: true,
                presentBadge: true,
                presentSound: true,
                presentBanner: true,
                presentList: true,
                threadIdentifier: conversationId.isEmpty
                    ? null
                    : conversationId,
              )
            : null,
      ),
      payload: jsonEncode(message.data),
    );
  }

  void _openFromLocalNotificationPayload(String? payload) {
    if (payload == null) return;
    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map) return;
      final intent = PushIntent.fromData(decoded.cast<String, dynamic>());
      if (intent != null) {
        _ref.read(pushIntentProvider.notifier).state = intent;
      }
    } catch (error) {
      debugPrint('Push local notification payload ignored: $error');
    }
  }

  void _openFromNotificationTap(RemoteMessage message) {
    final intent = PushIntent.fromData(message.data);
    if (intent != null) _ref.read(pushIntentProvider.notifier).state = intent;
  }

  bool _isActive(int generation) =>
      _started && generation == _lifecycleGeneration;

  Future<void> _cancelListeners() async {
    final tokenRefresh = _tokenRefresh;
    final foregroundMessages = _foregroundMessages;
    final openedMessages = _openedMessages;
    _tokenRefresh = null;
    _foregroundMessages = null;
    _openedMessages = null;
    await _cancelSubscription(tokenRefresh, 'token refresh');
    await _cancelSubscription(foregroundMessages, 'foreground messages');
    await _cancelSubscription(openedMessages, 'notification taps');
  }

  Future<void> _cancelSubscription(
    StreamSubscription<dynamic>? subscription,
    String label,
  ) async {
    try {
      await subscription?.cancel();
    } catch (error, stackTrace) {
      debugPrint(
        'Push listener cancellation failed [$label]: $error\n$stackTrace',
      );
    }
  }

  Future<void> _unregisterSafely(String token, {required String reason}) async {
    try {
      await _ref.read(pushApiProvider).unregister(token);
    } catch (error, stackTrace) {
      // Local logout wins. A stale token is harmless because the next login
      // moves it to the current tenant/user, and invalid tokens are pruned by
      // the server's delivery path.
      debugPrint('Push token unregister failed [$reason]: $error\n$stackTrace');
    }
  }
}

final pushNotificationsProvider = Provider<PushNotifications>((ref) {
  final notifications = PushNotifications(ref);
  ref.onDispose(notifications.stop);
  return notifications;
});
