import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../config/app_config.dart';
import '../config/env.dart';
import '../network/dio_provider.dart';
import 'pusher_protocol.dart';

/// Where the Reverb server is, and whether there is one at all.
///
/// A value rather than a read of [Env] from inside the client: the client is the
/// piece worth testing, and reading global configuration would make every test
/// depend on how the test runner was invoked.
class RealtimeConfig {
  const RealtimeConfig({
    required this.key,
    required this.host,
    required this.port,
    required this.useTls,
  });

  const RealtimeConfig.disabled()
    : key = '',
      host = '',
      port = 0,
      useTls = true;

  factory RealtimeConfig.fromEnv() => RealtimeConfig(
    key: Env.realtimeKey,
    host: Env.realtimeHost,
    port: Env.realtimePort,
    useTls: Env.realtimeUseTls,
  );

  final String key;
  final String host;
  final int port;
  final bool useTls;

  /// No key or no host means no realtime: the app falls back to polling and
  /// never attempts a connection. That is the normal state of a local build.
  bool get isEnabled => key.isNotEmpty && host.isNotEmpty;
}

/// A realtime event, reduced to what a caller needs.
///
/// The payload is carried but should be treated as a *signal*, not as data:
/// acting on it means refetching through the REST API, which re-applies the
/// caller's permissions. A broadcast payload has not been through that filter.
class RealtimeEvent {
  const RealtimeEvent({
    required this.channel,
    required this.event,
    this.data = const {},
  });

  final String channel;
  final String event;
  final Map<String, dynamic> data;
}

enum RealtimeStatus { disabled, disconnected, connecting, connected }

/// Opens the WebSocket. Injected so a test can drive a fake socket.
typedef RealtimeSocketFactory = WebSocketChannel Function(Uri url);

/// Signs a private-channel subscription against `/broadcasting/auth`.
typedef RealtimeAuthorizer =
    Future<String> Function(String channel, String socketId);

/// The app's single connection to Laravel Reverb.
///
/// What it replaces: the inbox polled `/inbox/changes` every 5 seconds and an
/// open thread every 8 — about 20 requests a minute per rep, mostly to discover
/// that nothing had happened, while the server had been publishing these events
/// all along.
///
/// Polling is not deleted, only relaxed. A WebSocket can die quietly (a proxy
/// idle-timeout, a captive portal, a carrier dropping long-lived connections)
/// and the failure mode — a rep watching an inbox that silently stopped
/// updating — is worse than the request volume. So the poll stays as a
/// heartbeat; it just stops being the mechanism.
///
/// Channels are private, so each subscription is signed against the current JWT
/// by the same endpoint the web client uses. The server scopes the subscription
/// to the tenant in the token, not to a client-supplied header.
class RealtimeClient {
  RealtimeClient({
    required RealtimeConfig config,
    required RealtimeAuthorizer authorizer,
    RealtimeSocketFactory? socketFactory,
    @visibleForTesting Duration? watchdogPeriod,
    @visibleForTesting Duration? silenceLimit,
  }) : _config = config,
       _authorize = authorizer,
       _openSocket = socketFactory ?? WebSocketChannel.connect,
       _watchdogPeriod = watchdogPeriod ?? defaultWatchdogPeriod,
       _silenceLimit = silenceLimit ?? defaultSilenceLimit,
       _status = ValueNotifier<RealtimeStatus>(
         config.isEnabled
             ? RealtimeStatus.disconnected
             : RealtimeStatus.disabled,
       );

  final RealtimeConfig _config;
  final RealtimeAuthorizer _authorize;
  final RealtimeSocketFactory _openSocket;

  /// Nhịp và hạn im lặng của watchdog. Tiêm vào để bài kiểm khỏi chờ 90 giây
  /// thật.
  final Duration _watchdogPeriod;
  final Duration _silenceLimit;

  final ValueNotifier<RealtimeStatus> _status;

  WebSocketChannel? _socket;
  StreamSubscription<dynamic>? _frames;
  String? _socketId;
  Future<void>? _connecting;
  Timer? _reconnectTimer;
  Duration _reconnectBackoff = _initialBackoff;
  bool _closedDeliberately = false;
  DateTime? _lastFrameAt;
  Timer? _watchdog;

  /// Reconnect delay: 2s doubling to 60s. A server restart brings every client
  /// back at once, so the ceiling matters as much as the growth.
  static const _initialBackoff = Duration(seconds: 2);
  static const _maxBackoff = Duration(seconds: 60);

  /// Nhịp hỏi "còn sống không". Một hẹn giờ duy nhất cho cả client.
  static const defaultWatchdogPeriod = Duration(seconds: 30);

  /// Im lặng bấy lâu thì coi kết nối là đã chết.
  ///
  /// ~1,5× nhịp ping của Reverb (60 giây), nên một kết nối còn tốt mà không có
  /// sự kiện nghiệp vụ nào vẫn luôn có frame trong cửa sổ này.
  static const defaultSilenceLimit = Duration(seconds: 90);

  /// Listeners per channel. A channel is subscribed once however many parts of
  /// the app want it, and dropped when the last one leaves.
  final Map<String, Set<void Function(RealtimeEvent)>> _listeners = {};

  /// Channels confirmed on the wire.
  final Set<String> _subscribed = {};

  ValueListenable<RealtimeStatus> get status => _status;

  bool get isConnected => _status.value == RealtimeStatus.connected;

  @visibleForTesting
  Set<String> get subscribedChannels => Set.unmodifiable(_subscribed);

  /// Connects if configured. Concurrent calls share one attempt; calling again
  /// while connected does nothing.
  Future<void> connect() {
    if (!_config.isEnabled || _socket != null) return Future.value();
    return _connecting ??= _open().whenComplete(() => _connecting = null);
  }

  Future<void> _open() async {
    _closedDeliberately = false;
    _status.value = RealtimeStatus.connecting;
    _lastFrameAt = DateTime.now();
    _startWatchdog();

    try {
      final socket = _openSocket(
        PusherProtocol.endpoint(
          host: _config.host,
          port: _config.port,
          key: _config.key,
          useTls: _config.useTls,
        ),
      );
      _socket = socket;
      _frames = socket.stream.listen(
        _onFrame,
        onError: (Object error) => _onClosed(error),
        onDone: () => _onClosed(null),
        cancelOnError: false,
      );
    } catch (error) {
      _onClosed(error);
    }
  }

  void _onFrame(dynamic raw) {
    // MỌI frame, kể cả `pusher:ping` và một frame không đọc được, là dấu hiệu
    // kết nối còn sống.
    _lastFrameAt = DateTime.now();
    final frame = PusherProtocol.parse(raw);
    if (frame == null) return;

    if (frame.isPing) {
      _send(PusherProtocol.pong());
      return;
    }

    if (frame.isConnectionEstablished) {
      _socketId = frame.socketId;
      _status.value = RealtimeStatus.connected;
      _reconnectBackoff = _initialBackoff;
      // Claim everything the app asked for while the socket was down. This is
      // also what makes a reconnect restore the previous subscriptions instead
      // of coming back silent.
      for (final channel in _listeners.keys.toList()) {
        unawaited(_subscribe(channel));
      }
      return;
    }

    if (frame.isError) {
      debugPrint('Realtime error frame: ${frame.data}');
      return;
    }

    final channel = frame.channel;
    if (channel == null) return;

    if (frame.event == 'pusher_internal:subscription_succeeded') {
      _subscribed.add(channel);
      return;
    }
    if (PusherProtocol.isInternal(frame.event)) return;

    final listeners = _listeners[channel];
    if (listeners == null || listeners.isEmpty) return;

    final event = RealtimeEvent(
      channel: channel,
      event: PusherProtocol.normalizeEventName(frame.event),
      data: frame.data,
    );
    // Copy: a listener may unsubscribe itself while being notified.
    for (final listener in listeners.toList()) {
      listener(event);
    }
  }

  /// Đóng một kết nối đã chết lặng, để `_onClosed` bật lại nhịp poll và vòng
  /// nối lại.
  ///
  /// Vì sao cần: client chỉ TRẢ LỜI ping của server, nó không tự ping và không
  /// có `activity_timeout`. Một socket bị NAT/proxy bỏ giữa đường không sinh
  /// `onDone` hay `onError` nào, nên nếu không có cái này thì `_status` nằm mãi
  /// ở `connected` — và từ P1, `connected` nghĩa là KHÔNG còn lượt poll nào:
  /// hộp thư đứng im vô hạn, im lặng.
  void _startWatchdog() {
    if (_watchdog?.isActive ?? false) return;
    _watchdog = Timer.periodic(_watchdogPeriod, (_) {
      if (_status.value != RealtimeStatus.connected) return;
      final last = _lastFrameAt;
      if (last == null || DateTime.now().difference(last) <= _silenceLimit) {
        return;
      }
      debugPrint(
        'Realtime: không frame nào trong $_silenceLimit, đóng socket.',
      );
      // `sink.close()` → `onDone` → `_onClosed`: trạng thái, nhịp poll và vòng
      // nối lại đều đi qua đúng một đường như mọi lần rớt khác.
      unawaited(_socket?.sink.close());
    });
  }

  void _stopWatchdog() {
    _watchdog?.cancel();
    _watchdog = null;
  }

  void _onClosed(Object? error) {
    if (error != null) debugPrint('Realtime socket closed: $error');

    _stopWatchdog();
    unawaited(_frames?.cancel());
    _frames = null;
    _socket = null;
    _socketId = null;
    _subscribed.clear();
    _status.value = _config.isEnabled
        ? RealtimeStatus.disconnected
        : RealtimeStatus.disabled;

    // A deliberate disconnect (logout, disposal) must not reconnect, and there
    // is nothing to reconnect for if nobody is listening.
    if (_closedDeliberately || _listeners.isEmpty) return;
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_reconnectTimer?.isActive ?? false) return;

    final delay = _reconnectBackoff;
    final next = delay * 2;
    _reconnectBackoff = next > _maxBackoff ? _maxBackoff : next;

    _reconnectTimer = Timer(delay, () {
      _reconnectTimer = null;
      if (_listeners.isNotEmpty) unawaited(connect());
    });
  }

  void _send(String payload) {
    try {
      _socket?.sink.add(payload);
    } catch (error) {
      debugPrint('Realtime send failed: $error');
    }
  }

  Future<void> _subscribe(String channel) async {
    final socketId = _socketId;
    if (socketId == null || _socket == null) return;

    try {
      final auth = await _authorize(channel, socketId);
      // The app may have navigated away, or the socket dropped, during the auth
      // round trip. Subscribing now would leak a subscription nobody reads, on a
      // signature that no longer matches the connection.
      if (_socketId != socketId || !_listeners.containsKey(channel)) return;
      _send(PusherProtocol.subscribe(channel: channel, auth: auth));
    } catch (error) {
      // A refused subscription is not fatal: that screen falls back to polling,
      // which is why polling still exists.
      debugPrint('Realtime subscribe to $channel failed: $error');
    }
  }

  /// Listens to a PRIVATE channel by its server-side name.
  ///
  /// Every channel this app uses is private, and the `private-` prefix is added
  /// here rather than at the call sites: subscribing to the unprefixed name
  /// succeeds, asks for no authorization, and delivers nothing at all, which is
  /// indistinguishable from a quiet inbox.
  void Function() subscribePrivate(
    String name,
    void Function(RealtimeEvent event) onEvent,
  ) => subscribe(PusherProtocol.privateChannel(name), onEvent);

  /// Listens to [channel] by its exact wire name, returning a function that
  /// stops listening. Prefer [subscribePrivate] unless you have the wire name
  /// already.
  ///
  /// The channel is subscribed on the first listener and dropped after the last
  /// one leaves, so an inbox screen and an open thread can share a channel
  /// without either tearing down the other's subscription.
  void Function() subscribe(
    String channel,
    void Function(RealtimeEvent event) onEvent,
  ) {
    if (!_config.isEnabled) return () {};

    final isFirst = !_listeners.containsKey(channel);
    _listeners.putIfAbsent(channel, () => {}).add(onEvent);

    if (isFirst) {
      unawaited(
        connect().then((_) {
          if (_listeners.containsKey(channel)) return _subscribe(channel);
          return null;
        }),
      );
    }

    return () {
      final listeners = _listeners[channel];
      if (listeners == null) return;
      listeners.remove(onEvent);
      if (listeners.isNotEmpty) return;

      _listeners.remove(channel);
      _subscribed.remove(channel);
      _send(PusherProtocol.unsubscribe(channel));
    };
  }

  /// Drops the connection and every subscription.
  ///
  /// Called on logout: the socket was authorized with the previous session's
  /// token and its channels belong to that tenant, so it must not survive into
  /// the next sign-in.
  Future<void> disconnect() async {
    _closedDeliberately = true;
    _stopWatchdog();
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _reconnectBackoff = _initialBackoff;
    _listeners.clear();
    _subscribed.clear();

    final socket = _socket;
    _socket = null;
    _socketId = null;
    await _frames?.cancel();
    _frames = null;
    _status.value = _config.isEnabled
        ? RealtimeStatus.disconnected
        : RealtimeStatus.disabled;

    try {
      await socket?.sink.close();
    } catch (_) {
      // Nothing useful to do if teardown fails.
    }
  }
}

final realtimeConfigProvider = Provider<RealtimeConfig>(
  (ref) => RealtimeConfig.fromEnv(),
);

final realtimeClientProvider = Provider<RealtimeClient>((ref) {
  final client = RealtimeClient(
    config: ref.watch(realtimeConfigProvider),
    // Signs through the app's own Dio, so the token, base URL and interceptors
    // are the ones every other request uses — including a token the refresh
    // interceptor has just rotated.
    authorizer: (channel, socketId) async {
      final response = await ref
          .read(dioProvider)
          .post<Map<String, dynamic>>(
            '${AppConfig.apiPrefix}/broadcasting/auth',
            data: {'socket_id': socketId, 'channel_name': channel},
          );
      final auth = response.data?['auth'];
      if (auth is! String || auth.isEmpty) {
        throw StateError('Broadcast auth returned no signature.');
      }
      return auth;
    },
  );
  ref.onDispose(() => unawaited(client.disconnect()));
  return client;
});

/// Connection state as a provider, so a screen can decide how hard to poll: a
/// heartbeat while the socket is up, the old tight interval when it is not.
final realtimeStatusProvider = StreamProvider<RealtimeStatus>((ref) {
  final client = ref.watch(realtimeClientProvider);
  final controller = StreamController<RealtimeStatus>();
  void emit() => controller.add(client.status.value);
  client.status.addListener(emit);
  emit();
  ref.onDispose(() {
    client.status.removeListener(emit);
    unawaited(controller.close());
  });
  return controller.stream;
});
