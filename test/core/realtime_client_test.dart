import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/core/realtime/realtime_client.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// The realtime client against a socket we control.
///
/// Realtime is the kind of thing that appears to work in a manual test and then
/// fails in the field: a subscription made before the handshake lands, a
/// reconnect that forgets what it was watching, a socket that outlives the
/// session that authorized it. Those are the cases here.
void main() {
  const config = RealtimeConfig(
    key: 'test-key',
    host: 'ws.test',
    port: 443,
    useTls: true,
  );

  late _FakeSocket socket;
  late List<_FakeSocket> opened;
  late RealtimeClient client;

  setUp(() {
    socket = _FakeSocket();
    opened = [socket];
    client = RealtimeClient(
      config: config,
      // Hands out a fresh socket per connect after the first, so a reconnect
      // can be driven the way the real one happens.
      socketFactory: (_) {
        if (opened.length == 1) return opened.first;
        return opened.last;
      },
      authorizer: (channel, socketId) async => 'key:sig-for-$channel',
    );
  });

  tearDown(() async {
    await client.disconnect();
  });

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  Future<void> handshake() async {
    socket.emit({
      'event': 'pusher:connection_established',
      'data': jsonEncode({'socket_id': '1.1'}),
    });
    await settle();
    await settle();
  }

  test('answers the ping that keeps the connection alive', () async {
    client.subscribe('private-x', (_) {});
    await settle();
    await handshake();
    socket.sent.clear();

    socket.emit({'event': 'pusher:ping', 'data': <String, dynamic>{}});
    await settle();

    expect(
      socket.sent.map((raw) => jsonDecode(raw)['event']),
      contains('pusher:pong'),
      reason: 'Reverb closes a connection that stops answering',
    );
  });

  test('subscribes only after the handshake supplies a socket id', () async {
    // A private subscription is signed against the socket id, so asking before
    // the handshake would produce a signature the server rejects.
    client.subscribe('private-conversation.c1', (_) {});
    await settle();
    expect(socket.sent, isEmpty);

    await handshake();

    final subscribes = socket.sent
        .map((raw) => jsonDecode(raw) as Map<String, dynamic>)
        .where((frame) => frame['event'] == 'pusher:subscribe')
        .toList();
    expect(subscribes, hasLength(1));
    expect(subscribes.first['data']['channel'], 'private-conversation.c1');
    expect(
      subscribes.first['data']['auth'],
      'key:sig-for-private-conversation.c1',
    );
  });

  test('delivers an event to its channel listeners, name normalised', () async {
    final received = <RealtimeEvent>[];
    client.subscribe('private-conversation.c1', received.add);
    await settle();
    await handshake();

    socket.emit({
      'event': '.message.created',
      'channel': 'private-conversation.c1',
      'data': jsonEncode({'conversation_id': 'c1'}),
    });
    await settle();

    expect(received, hasLength(1));
    expect(received.single.event, 'message.created');
    expect(received.single.data['conversation_id'], 'c1');
  });

  test('does not deliver another channel’s events', () async {
    final received = <RealtimeEvent>[];
    client.subscribe('private-conversation.c1', received.add);
    await settle();
    await handshake();

    socket.emit({
      'event': '.message.created',
      'channel': 'private-conversation.c2',
      'data': jsonEncode({'conversation_id': 'c2'}),
    });
    await settle();

    expect(received, isEmpty);
  });

  test(
    'two listeners share one subscription, and the last one out ends it',
    () async {
      // The inbox and an open thread can want the same channel. Subscribing twice
      // would double every event; unsubscribing on the first leave would silence
      // the other.
      final first = <RealtimeEvent>[];
      final second = <RealtimeEvent>[];
      final leaveFirst = client.subscribe('private-x', first.add);
      final leaveSecond = client.subscribe('private-x', second.add);
      await settle();
      await handshake();

      expect(
        socket.sent
            .map((raw) => jsonDecode(raw) as Map<String, dynamic>)
            .where((frame) => frame['event'] == 'pusher:subscribe'),
        hasLength(1),
      );

      leaveFirst();
      socket.sent.clear();
      socket.emit({
        'event': '.thing',
        'channel': 'private-x',
        'data': jsonEncode(<String, dynamic>{}),
      });
      await settle();

      expect(first, isEmpty, reason: 'the one that left hears nothing');
      expect(second, hasLength(1), reason: 'the one still listening does');
      expect(
        socket.sent.map((raw) => jsonDecode(raw)['event']),
        isNot(contains('pusher:unsubscribe')),
      );

      leaveSecond();
      expect(
        socket.sent.map((raw) => jsonDecode(raw)['event']),
        contains('pusher:unsubscribe'),
      );
    },
  );

  test('a malformed frame does not take the connection down', () async {
    final received = <RealtimeEvent>[];
    client.subscribe('private-x', received.add);
    await settle();
    await handshake();

    socket.emitRaw('}{ not json');
    socket.emit({
      'event': '.thing',
      'channel': 'private-x',
      'data': jsonEncode(<String, dynamic>{}),
    });
    await settle();

    expect(received, hasLength(1));
    expect(client.isConnected, isTrue);
  });

  test(
    'subscribePrivate asks for the private channel, not a public one',
    () async {
      // The bug this exists for: Laravel's PrivateChannel broadcasts to
      // `private-conversation.c1`, but subscribing to `conversation.c1` is a
      // legal request for a PUBLIC channel of that name. It succeeds, needs no
      // authorization, and then delivers nothing — forever, and silently, which
      // is indistinguishable from a quiet inbox. Earlier tests here passed
      // literal 'private-x' names and so could never have caught it.
      final received = <RealtimeEvent>[];
      client.subscribePrivate('conversation.c1', received.add);
      await settle();
      await handshake();

      final subscribes = socket.sent
          .map((raw) => jsonDecode(raw) as Map<String, dynamic>)
          .where((frame) => frame['event'] == 'pusher:subscribe')
          .toList();
      expect(subscribes.single['data']['channel'], 'private-conversation.c1');

      // And the events the server actually sends arrive on that name.
      socket.emit({
        'event': '.message.created',
        'channel': 'private-conversation.c1',
        'data': jsonEncode({'conversation_id': 'c1'}),
      });
      await settle();

      expect(received, hasLength(1));
    },
  );

  test('subscribePrivate does not double the prefix', () async {
    client.subscribePrivate('private-already', (_) {});
    await settle();
    await handshake();

    final subscribes = socket.sent
        .map((raw) => jsonDecode(raw) as Map<String, dynamic>)
        .where((frame) => frame['event'] == 'pusher:subscribe')
        .toList();
    expect(subscribes.single['data']['channel'], 'private-already');
  });

  test('a reconnect re-subscribes instead of coming back silent', () async {
    // The failure this guards is invisible: the socket returns, the status says
    // connected, and no message ever arrives again because the server has no
    // record of the subscription. A dropped connection loses its subscriptions,
    // so the client has to reclaim them on the next handshake.
    final received = <RealtimeEvent>[];
    client.subscribe('private-conversation.c1', received.add);
    await settle();
    await handshake();
    expect(client.isConnected, isTrue);

    // The carrier drops the connection.
    await socket.close();
    await settle();
    expect(client.isConnected, isFalse);

    // What the backoff timer eventually does.
    final reconnected = _FakeSocket();
    opened.add(reconnected);
    await client.connect();
    await settle();
    reconnected.emit({
      'event': 'pusher:connection_established',
      'data': jsonEncode({'socket_id': '2.2'}),
    });
    await settle();
    await settle();

    final subscribes = reconnected.sent
        .map((raw) => jsonDecode(raw) as Map<String, dynamic>)
        .where((frame) => frame['event'] == 'pusher:subscribe')
        .toList();
    expect(subscribes, hasLength(1), reason: 'the channel is claimed again');
    expect(subscribes.first['data']['channel'], 'private-conversation.c1');
    // Signed against the NEW socket id: a signature from the dead connection
    // would be rejected.
    expect(
      subscribes.first['data']['auth'],
      'key:sig-for-private-conversation.c1',
    );

    reconnected.emit({
      'event': '.message.created',
      'channel': 'private-conversation.c1',
      'data': jsonEncode({'conversation_id': 'c1'}),
    });
    await settle();
    expect(received, hasLength(1), reason: 'events flow again after reconnect');
  });

  test('a deliberate disconnect does not reconnect', () async {
    // Logout must stay logged out. Reconnecting would reopen a socket
    // authorized by the session that just ended.
    client.subscribe('private-x', (_) {});
    await settle();
    await handshake();

    await client.disconnect();
    await settle();

    expect(client.isConnected, isFalse);
    // Nothing left to reclaim, so a later connect has no channels to restore.
    expect(client.subscribedChannels, isEmpty);
  });

  test('logout drops the socket and everything it was watching', () async {
    // The connection was authorized with the previous session's token and its
    // channels belong to that tenant; it must not survive into the next login.
    client.subscribe('private-x', (_) {});
    await settle();
    await handshake();

    // A channel counts as subscribed only once the server confirms it — asking
    // is not the same as being on it.
    socket.emit({
      'event': 'pusher_internal:subscription_succeeded',
      'channel': 'private-x',
      'data': jsonEncode(<String, dynamic>{}),
    });
    await settle();
    expect(client.subscribedChannels, contains('private-x'));

    await client.disconnect();

    expect(socket.closed, isTrue);
    expect(client.isConnected, isFalse);
    expect(client.subscribedChannels, isEmpty);
  });
}

/// A socket whose frames the test writes, and whose sends the test reads.
class _FakeSocket implements WebSocketChannel {
  final _incoming = StreamController<dynamic>.broadcast();
  final _sink = _FakeSink();

  List<String> get sent => _sink.sent;
  bool get closed => _sink.closed;

  void emit(Map<String, dynamic> frame) => _incoming.add(jsonEncode(frame));

  void emitRaw(String frame) => _incoming.add(frame);

  /// The connection dying on its own — what a proxy idle-timeout or a carrier
  /// dropping a long-lived socket looks like to the client.
  Future<void> close() => _incoming.close();

  @override
  Stream<dynamic> get stream => _incoming.stream;

  @override
  WebSocketSink get sink => _sink;

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSink implements WebSocketSink {
  final List<String> sent = [];
  bool closed = false;

  @override
  void add(dynamic data) => sent.add(data as String);

  @override
  Future<void> close([int? closeCode, String? closeReason]) async {
    closed = true;
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
