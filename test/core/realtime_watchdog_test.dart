import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/core/realtime/realtime_client.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Socket "xác sống": nối vẫn `connected` nhưng không còn frame nào tới (C2).
///
/// Một kết nối bị NAT/proxy/cổng wifi khách sạn bỏ giữa đường KHÔNG sinh
/// `onDone` hay `onError`, nên `_status` nằm mãi ở `connected`. Trước Đợt 8 thì
/// lưới poll 2 phút/lượt che được; sau P1 thì `pollInterval` trả `null` khi
/// `connected`, nên không còn lượt gọi nào: nhân viên ngồi nhìn hộp thư ngừng
/// cập nhật, tin khách mới không hiện, và không có thông báo gì. Hồi quy đó chỉ
/// chữa được ở đây — client phải tự phát hiện ra là mình đã chết.
///
/// Nhịp watchdog được tiêm ngắn lại (30ms/90ms, cùng tỉ lệ 1:3 như
/// 30s/90s thật) để bài kiểm chạy bằng đồng hồ thật mà không chờ 90 giây.
void main() {
  const config = RealtimeConfig(
    key: 'test-key',
    host: 'ws.test',
    port: 443,
    useTls: true,
  );
  const period = Duration(milliseconds: 30);
  const limit = Duration(milliseconds: 90);

  late _FakeSocket socket;
  late RealtimeClient client;

  setUp(() {
    socket = _FakeSocket();
    client = RealtimeClient(
      config: config,
      socketFactory: (_) => socket,
      authorizer: (channel, socketId) async => 'key:sig-for-$channel',
      watchdogPeriod: period,
      silenceLimit: limit,
    );
  });

  tearDown(() async {
    await client.disconnect();
  });

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  Future<void> handshake() async {
    client.subscribe('private-x', (_) {});
    await settle();
    socket.emit({
      'event': 'pusher:connection_established',
      'data': jsonEncode({'socket_id': '1.1'}),
    });
    await settle();
    await settle();
    expect(
      client.isConnected,
      isTrue,
      reason: 'bắt tay xong phải là connected',
    );
  }

  test('socket im quá hạn thì bị đóng để nhịp poll quay lại', () async {
    await handshake();

    // Không frame nào — kể cả ping của server. Reverb ping khoảng 60 giây một
    // lượt, nên im hết hạn 90 giây là đã chết.
    await Future<void>.delayed(limit * 2);
    await settle();

    expect(
      socket.closed,
      isTrue,
      reason: 'phải đóng socket chết, không đợi một frame không bao giờ tới',
    );
    expect(
      client.isConnected,
      isFalse,
      reason: 'rời connected mới là thứ bật lại nhịp poll ở hai màn hình',
    );
  });

  test('frame nào cũng là dấu hiệu sống, kể cả ping', () async {
    await handshake();

    // Nhịp ping của server trên một kết nối còn tốt mà không có sự kiện nghiệp
    // vụ nào: cứ dưới hạn im lặng lại có một frame.
    for (var i = 0; i < 6; i++) {
      await Future<void>.delayed(limit ~/ 2);
      socket.emit({'event': 'pusher:ping', 'data': {}});
      await settle();
    }
    await settle();

    expect(
      socket.closed,
      isFalse,
      reason: 'ping đã trả lời nghĩa là kết nối còn sống: không được đóng',
    );
    expect(client.isConnected, isTrue);
    // Và client vẫn phải trả lời từng cái: đóng bởi server mới là kiểu hỏng kia.
    expect(socket.sent.where((f) => f.contains('pusher:pong')).length, 6);
  });

  test('ngắt chủ động thì watchdog dừng theo, không đóng vòng vo', () async {
    await handshake();
    await client.disconnect();
    socket.sent.clear();

    // Một `Timer.periodic` sống sót sau `disconnect` là một vòng lặp đóng socket
    // trên máy thật, và một bài kiểm đỏ ở chỗ khác ("A Timer is still pending").
    await Future<void>.delayed(limit * 2);

    expect(client.status.value, RealtimeStatus.disconnected);
  });
}

/// Socket mà bài kiểm viết frame vào và đọc lệnh gửi ra.
///
/// `sink.close()` đóng luôn đầu đọc, như socket thật: đóng đầu ghi thì đầu đọc
/// báo `onDone`, và chính `onDone` mới là thứ đưa client về `disconnected`.
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
