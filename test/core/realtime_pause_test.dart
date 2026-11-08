import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/core/realtime/realtime_client.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Tạm ngắt socket khi app ở nền lâu (pin + data), và nhiễu ±20% khi nối lại.
void main() {
  const config = RealtimeConfig(
    key: 'test-key',
    host: 'ws.test',
    port: 443,
    useTls: true,
  );

  late List<_FakeSocket> sockets;

  RealtimeClient make({Random? random}) => RealtimeClient(
    config: config,
    socketFactory: (_) {
      final s = _FakeSocket();
      sockets.add(s);
      return s;
    },
    authorizer: (channel, socketId) async => 'key:sig-for-$channel',
    enableWatchdog: false,
    random: random,
  );

  setUp(() => sockets = []);

  Future<void> settle() async {
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
  }

  Future<void> handshake(_FakeSocket socket) async {
    socket.emit({
      'event': 'pusher:connection_established',
      'data': jsonEncode({'socket_id': '1.1'}),
    });
    await settle();
  }

  test(
    'pause đóng socket, giữ listener, không nối lại; resume khôi phục',
    () async {
      final client = make();
      addTearDown(client.disconnect);
      final received = <RealtimeEvent>[];
      client.subscribe('private-x', received.add);
      await settle();
      await handshake(sockets.first);
      expect(client.isConnected, isTrue);

      await client.pause();

      expect(sockets.first.closed, isTrue);
      expect(client.status.value, RealtimeStatus.disconnected);
      expect(client.isPaused, isTrue);

      // Vòng nối lại gốc là 2s: qua mốc đó mà vẫn chỉ có đúng một socket.
      await Future<void>.delayed(const Duration(milliseconds: 2300));
      expect(sockets, hasLength(1), reason: 'ở nền thì không nối lại');

      // Listener mới trong lúc tạm ngắt cũng không được kéo socket dậy.
      client.subscribe('private-y', (_) {});
      await settle();
      expect(sockets, hasLength(1));

      await client.resume();
      await settle();
      expect(sockets, hasLength(2));
      await handshake(sockets.last);

      expect(client.isConnected, isTrue);
      expect(client.isPaused, isFalse);
      final subscribes = sockets.last.sent
          .where((f) => f.contains('pusher:subscribe'))
          .join();
      expect(subscribes, contains('private-x'));
      expect(subscribes, contains('private-y'));

      // Listener cũ vẫn nhận sự kiện sau khi khôi phục.
      sockets.last.emit({
        'event': 'x.event',
        'channel': 'private-x',
        'data': jsonEncode({'a': 1}),
      });
      await settle();
      expect(received, hasLength(1));
    },
  );

  test('nối lại có nhiễu ±20%: random=0 thì sớm hơn nhịp gốc 2s', () async {
    final client = make(random: _FixedRandom(0));
    addTearDown(client.disconnect);
    client.subscribe('private-x', (_) {});
    await settle();
    await handshake(sockets.first);

    // Rớt kết nối.
    await sockets.first.sink.close();
    await settle();
    expect(client.status.value, RealtimeStatus.disconnected);

    // 2s * 0,8 = 1,6s. Không nhiễu thì phải tới 2s mới nối.
    await Future<void>.delayed(const Duration(milliseconds: 1800));
    expect(sockets, hasLength(2));
  });
}

class _FixedRandom implements Random {
  _FixedRandom(this.value);
  final double value;

  @override
  double nextDouble() => value;

  @override
  bool nextBool() => false;

  @override
  int nextInt(int max) => 0;
}

class _FakeSocket implements WebSocketChannel {
  final _incoming = StreamController<dynamic>.broadcast();
  late final _sink = _FakeSink(_incoming);

  List<String> get sent => _sink.sent;
  bool get closed => _sink.closed;

  void emit(Map<String, dynamic> frame) {
    if (!_incoming.isClosed) _incoming.add(jsonEncode(frame));
  }

  @override
  Stream<dynamic> get stream => _incoming.stream;

  @override
  WebSocketSink get sink => _sink;

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSink implements WebSocketSink {
  _FakeSink(this._incoming);

  final StreamController<dynamic> _incoming;
  final List<String> sent = [];
  bool closed = false;

  @override
  void add(dynamic data) => sent.add(data as String);

  @override
  Future<void> close([int? closeCode, String? closeReason]) async {
    closed = true;
    if (!_incoming.isClosed) await _incoming.close();
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
