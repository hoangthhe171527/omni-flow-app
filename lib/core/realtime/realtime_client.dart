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
  }) : _config = config,
       _authorize = authorizer,
       _openSocket = socketFactory ?? WebSocketChannel.connect,
       _status = ValueNotifier<RealtimeStatus>(
         config.isEnabled
             ? RealtimeStatus.disconnected
             : RealtimeStatus.disabled,
       );

  final RealtimeConfig _config;
  final RealtimeAuthorizer _authorize;
  final RealtimeSocketFactory _openSocket;
  final ValueNotifier<RealtimeStatus> _status;

  WebSocketChannel? _socket;
  StreamSubscription<dynamic>? _frames;
  String? _socketId;
  Future<void>? _connecting;
  Timer? _reconnectTimer;
  Duration _reconnectBackoff = _initialBackoff;
  bool _closedDeliberately = false;

  /// Reconnect delay: 2s doubling to 60s. A server restart brings every client
  /// back at once, so the ceiling matters as much as the growth.
  static const _initialBackoff = Duration(seconds: 2);
  static const _maxBackoff = Duration(seconds: 60);

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

  void _onClosed(Object? error) {
    if (error != null) debugPrint('Realtime socket closed: $error');

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

  /// Listens to [channel], returning a function that stops listening.
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
      final response = await ref.read(dioProvider).post<Map<String, dynamic>>(
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
