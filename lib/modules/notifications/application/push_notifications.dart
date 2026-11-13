import 'dart:async';
import 'dart:convert';
import 'dart:ui' show Color;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../security/session/session.dart';
import '../../inbox/application/inbox_providers.dart';
import 'notifications_providers.dart';
import '../data/push_api.dart';

// Android freezes a channel's sound after first creation. v4 intentionally
// creates a fresh channel so installs that received a silent v3 channel get
// the bundled alert sound.
const _androidChannelId = 'inbox_messages_v4';

/// Màu nhuộm icon nhỏ của thông báo; khớp `@color/notification_accent` mà
/// thông báo FCM dùng khi app đóng.
const _androidAccent = Color(0xFF0159DB);
const _tokenRefreshGenerationKey = 'fcm_token_refresh_generation';
// Bump when a release must rebind the installation. This repairs devices that
// kept an FCM token locally while its server-side row was removed/invalidated.
const _tokenRefreshGeneration = 3;
const _androidSound = RawResourceAndroidNotificationSound('omni_message_alert');

// Work gets a channel of its own so it can be muted — or kept — separately
// from customer messages. A worker who silences the shop inbox at night must
// still be reachable about tomorrow's pianos, and someone who mutes work
// notifications should not lose customer messages with them. It also keeps the
// message alert sound off notifications that are not messages.
const _taskChannelId = 'tasks_v1';
const _taskChannelName = 'Công việc';
const _taskChannelDescription =
    'Thông báo khi bạn được giao việc, đến lượt bạn, hoặc việc đã hoàn thành.';

const _taskChannel = AndroidNotificationChannel(
  _taskChannelId,
  _taskChannelName,
  description: _taskChannelDescription,
  importance: Importance.high,
  enableVibration: true,
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
    if (kDebugMode) {
      debugPrint(
        'Push runtime initialization failed [$platform]: '
        '$error\n$stackTrace',
      );
    }
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

/// The kind of screen a push wants opened.
enum PushTarget { conversation, task }

/// A deliberately small, routing-only payload. Notification text is for the
/// lock screen; navigation always uses an id and reloads the data.
///
/// This is a trust boundary: the payload is written by the server and handed
/// over by the OS, sometimes to a process that is still starting. Anything
/// unrecognised, or recognised but incomplete, resolves to null — a tap that
/// does nothing is the correct outcome, and far better than a crash on launch
/// or a route to a screen that does not exist.
class PushIntent {
  const PushIntent({required this.target, required this.id});

  final PushTarget target;

  /// Id of the thing to open — a conversation or a task, per [target].
  final String id;

  static PushIntent? fromData(Map<String, dynamic> data) {
    final target = switch (data['type']) {
      'inbox_message' => PushTarget.conversation,
      // Every task push opens the task itself. A stage is not a screen of its
      // own, and the worker needs the surrounding work to act on it anyway.
      'task_assigned' ||
      // Việc mới trong kế hoạch, và thợ báo vấn đề (bug sheet 12/11/2026):
      // thiếu ở đây thì push vẫn hiện, chạm vào không đi đâu.
      'task_created' ||
      'task_issue' ||
      'task_stage_open' ||
      'task_completed' ||
      'task_overdue' ||
      'task_due_soon' ||
      // Thiếu hai dòng này thì push bình luận/nhắc tên vẫn hiện trên màn hình
      // khoá nhưng chạm vào không mở được cây đàn, chuông trong app không tự
      // cập nhật, và ở tiền cảnh nó rơi nhầm sang kênh tin nhắn khách hàng.
      'task_commented' ||
      // Thiếu dòng này thì push tiến độ hiện trên màn khoá mà chạm vào không
      // mở được cây đàn — đúng lỗi đã xảy ra hai lần ngay trên, với
      // `task_commented` và `task_mentioned`. Danh sách này là HỢP ĐỒNG với
      // `NotificationType` bên API; thêm loại ở đó mà quên ở đây thì thông báo
      // vẫn hiện, chỉ là chạm vào không đi đâu cả.
      'task_progress' ||
      // Nhắc việc theo giờ tự chọn (`SendTaskRemindersCommand`).
      'task_reminder' ||
      'task_mentioned' => PushTarget.task,
      _ => null,
    };
    if (target == null) return null;

    final key = target == PushTarget.conversation
        ? 'conversation_id'
        : 'task_id';
    final id = data[key]?.toString() ?? '';

    return id.isEmpty ? null : PushIntent(target: target, id: id);
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

  /// Lần POST đăng ký thành công gần nhất. Thay cho heartbeat 15 phút: token
  /// đổi đã có `onTokenRefresh`, còn "hàng server bị mất" thì `ensureRegistered`
  /// (resume sau > 60s ở nền) sửa, nhưng không quá một lần mỗi 12 giờ.
  String? _lastRegisteredToken;
  DateTime? _lastRegisteredAt;
  static const _registrationFreshness = Duration(hours: 12);
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
      final forgetting = _forgetting;
      if (forgetting != null) await forgetting;
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
      if (kDebugMode) {
        debugPrint(
          'Push authorization [$platform]: ${settings.authorizationStatus}',
        );
      }
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
      if (kDebugMode) {
        debugPrint('Push startup failed [$platform]: $error\n$stackTrace');
      }
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
    _startupRetry = null;
    _registrationRetry = null;
    _lastRegisteredToken = null;
    _lastRegisteredAt = null;
    final token = _token;
    _token = null;
    _registrationAttempts = 0;
    await _cancelListeners();
    if (token != null && !_started && generation == _lifecycleGeneration) {
      await _unregisterSafely(token, reason: 'stop');
    }
  }

  /// Phiên đổi trạng thái (gốc app gọi). Đã đăng nhập → bật push; đổi không
  /// gian làm việc → chỉ dừng (vẫn là người đó); phiên KẾT THÚC → dừng, rồi
  /// huỷ FCM token và gỡ thông báo đang hiện.
  Future<void> onSessionChanged(Session? previous, Session next) async {
    if (next.isAuthenticated) {
      await start();
      return;
    }
    await stop();
    if (sessionEnded(previous, next)) {
      final forgetting = _forgetDevice();
      _forgetting = forgetting;
      await forgetting;
    }
  }

  /// Lượt huỷ token đang chạy: đăng nhập lại ngay sau đăng xuất thì [start]
  /// chờ nó xong, kẻo token mới vừa đăng ký lại bị lượt huỷ cũ xoá mất.
  Future<void>? _forgetting;

  /// Phiên kết thúc: hết hạn (kể cả ngay lúc mở app), hoặc đăng xuất/xoá tài
  /// khoản từ một phiên đang có. Mở app khi chưa đăng nhập hay đăng nhập hỏng
  /// thì không — chưa có gì để gỡ.
  @visibleForTesting
  static bool sessionEnded(Session? previous, Session next) =>
      next.status == SessionStatus.expired ||
      (next.status == SessionStatus.unauthenticated &&
          (previous?.hasCredentials ?? false));

  /// `DELETE /devices/push-tokens` (trong [stop] hay bước trước đăng xuất) cần
  /// phiên còn sống; hết hạn/mất mạng thì nó hỏng lặng và máy chủ vẫn đẩy tin
  /// của người cũ tới máy này. Huỷ token ở Firebase là đường không cần phiên:
  /// lần gửi sau máy chủ nhận "unregistered" và tự dọn hàng. Lần đăng nhập sau
  /// [start] lấy token mới và đăng ký cho người mới.
  Future<void> _forgetDevice() async {
    _ref.read(pushIntentProvider.notifier).state = null;
    final reset = _ref.read(pushDeviceResetProvider);
    try {
      await reset.deleteFcmToken();
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('Push token delete failed: $error\n$stackTrace');
      }
    }
    try {
      await reset.clearShownNotifications();
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('Clearing notifications failed: $error\n$stackTrace');
      }
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

    final lastAt = _lastRegisteredAt;
    if (_token != null &&
        _token == _lastRegisteredToken &&
        lastAt != null &&
        DateTime.now().difference(lastAt) < _registrationFreshness) {
      return;
    }

    try {
      final token = await _getFcmToken(platform);
      if (token != null && token.isNotEmpty) await _register(token);
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint(
          'Push registration refresh failed [$platform]: '
          '$error\n$stackTrace',
        );
      }
      if (_started) _scheduleRegistrationRetry();
    }
  }

  Future<void> _initializeLocalNotifications() async {
    // Icon nhỏ một màu (drawable/ic_stat_viomni), cùng icon với thông báo FCM
    // khai trong AndroidManifest. Icon app nhiều màu ở đây sẽ thành ô vuông trắng.
    const android = AndroidInitializationSettings('ic_stat_viomni');
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
    await _local
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_taskChannel);
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
      _lastRegisteredToken = registeringToken;
      _lastRegisteredAt = DateTime.now();
      if (kDebugMode) {
        debugPrint('Push token registered with Viomni [$platform].');
      }
    } catch (error, stackTrace) {
      // Token refresh must never break the authenticated session. Retry with a
      // capped backoff: this covers an API deploy/restart and flaky mobile data.
      if (kDebugMode) {
        debugPrint(
          'Push token registration failed [$platform]: $error\n$stackTrace',
        );
      }
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
    final intent = PushIntent.fromData(message.data);
    // Only an inbox push refreshes the inbox. A task assignment arriving while
    // the app is open would otherwise fire a pointless inbox refetch.
    if (intent?.target == PushTarget.conversation) {
      final signal = _ref.read(inboxRealtimeSignalProvider.notifier);
      signal.state = signal.state + 1;
    }
    if (intent?.target == PushTarget.task) {
      final signal = _ref.read(notificationSignalProvider.notifier);
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
    final isTask = intent?.target == PushTarget.task;
    final title =
        notification?.title ?? (isTask ? 'Công việc' : 'Tin nhắn mới');
    final body =
        notification?.body ??
        (isTask ? 'Có cập nhật về công việc.' : 'Khách hàng vừa gửi tin nhắn.');
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
      _notificationId(intent, message),
      title,
      body,
      NotificationDetails(
        android: platform == 'android'
            ? (isTask
                  ? const AndroidNotificationDetails(
                      _taskChannelId,
                      _taskChannelName,
                      channelDescription: _taskChannelDescription,
                      importance: Importance.high,
                      priority: Priority.high,
                      enableVibration: true,
                      color: _androidAccent,
                      category: AndroidNotificationCategory.reminder,
                    )
                  : AndroidNotificationDetails(
                      _androidChannelId,
                      'Tin nhắn khách hàng',
                      channelDescription:
                          'Thông báo khi khách hàng gửi tin nhắn mới.',
                      importance: Importance.max,
                      priority: Priority.max,
                      playSound: true,
                      sound: _androidSound,
                      enableVibration: true,
                      color: _androidAccent,
                      audioAttributesUsage:
                          AudioAttributesUsage.notificationEvent,
                      category: AndroidNotificationCategory.message,
                      fullScreenIntent: false,
                      styleInformation: messagingStyle,
                    ))
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

  /// One slot per thing, so a second update about the same task replaces the
  /// first instead of stacking. Six rows about one piano is how a worker learns
  /// to swipe the whole shade away without reading it.
  int _notificationId(PushIntent? intent, RemoteMessage message) {
    if (intent != null) return intent.id.hashCode & 0x7fffffff;

    return message.messageId?.hashCode ?? DateTime.now().microsecondsSinceEpoch;
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
      if (kDebugMode) {
        debugPrint('Push local notification payload ignored: $error');
      }
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
      if (kDebugMode) {
        debugPrint(
          'Push listener cancellation failed [$label]: $error\n$stackTrace',
        );
      }
    }
  }

  Future<void> _unregisterSafely(String token, {required String reason}) async {
    try {
      await _ref.read(pushApiProvider).unregister(token);
    } catch (error, stackTrace) {
      // Local logout wins. A still-valid token is NOT harmless (the server
      // keeps pushing the previous user's messages to this device), so when
      // the session ends `_forgetDevice` revokes it at Firebase instead.
      if (kDebugMode) {
        debugPrint(
          'Push token unregister failed [$reason]: $error\n$stackTrace',
        );
      }
    }
  }
}

/// Những việc chạm thẳng vào máy khi một phiên KẾT THÚC: thu hồi FCM token của
/// bản cài này và gỡ thông báo đang nằm trên khay. Tách ra provider để test
/// thay được (Firebase không chạy trong `flutter test`).
class PushDeviceReset {
  const PushDeviceReset();

  /// FCM token bị huỷ ở phía Firebase: máy chủ gửi tới token cũ sẽ nhận lỗi
  /// "unregistered" và tự dọn hàng — cách DUY NHẤT gỡ máy khỏi người cũ khi
  /// không còn phiên để gọi `DELETE /devices/push-tokens` (401, mất mạng).
  Future<void> deleteFcmToken() async {
    if (!_pushRuntimeInitialized) return;
    await FirebaseMessaging.instance.deleteToken();
  }

  /// Gỡ thông báo đang hiện (tên khách, trích tin) của người vừa rời phiên.
  Future<void> clearShownNotifications() async {
    if (_runtimePushPlatform == null) return;
    await FlutterLocalNotificationsPlugin().cancelAll();
  }
}

final pushDeviceResetProvider = Provider<PushDeviceReset>(
  (ref) => const PushDeviceReset(),
);

final pushNotificationsProvider = Provider<PushNotifications>((ref) {
  final notifications = PushNotifications(ref);
  ref.onDispose(notifications.stop);
  return notifications;
});
