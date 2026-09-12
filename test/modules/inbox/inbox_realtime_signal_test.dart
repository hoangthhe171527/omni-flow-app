import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/core/config/app_config.dart';
import 'package:omni_app/core/network/api_client.dart';
import 'package:omni_app/core/network/api_envelope.dart';
import 'package:omni_app/core/realtime/realtime_client.dart';
import 'package:omni_app/modules/inbox/application/inbox_providers.dart';
import 'package:omni_app/modules/inbox/application/inbox_realtime.dart';
import 'package:omni_app/modules/inbox/application/thread_controller.dart';
import 'package:omni_app/modules/inbox/data/inbox_api.dart';
import 'package:omni_app/modules/inbox/domain/conversation.dart';
import 'package:omni_app/modules/inbox/domain/message.dart';
import 'package:omni_app/security/session/session.dart';
import 'package:omni_app/security/session/session_controller.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Tín hiệu realtime của hộp thư: gộp nhịp, và tách theo hội thoại.
///
/// Trước đây MỌI sự kiện — tin mới của tenant, biên nhận "đã nhận"/"đã xem"
/// của bất kỳ hội thoại nào — đều đổ vào một `StateProvider<int>` duy nhất.
/// Hệ quả: một khách đọc tin ở hội thoại A làm màn chat B đang mở tải lại
/// toàn bộ lịch sử, và một loạt 5 webhook trong 100ms là 5 lượt gọi API để vẽ
/// ra cùng một màn hình.
///
/// Đồng hồ thật, như `my_tasks_realtime_test`: cửa sổ gộp là 400ms nên các
/// mốc kiểm ở đây cách nhau đủ xa để không phập phù khi máy bận.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> wait(int ms) => Future<void>.delayed(Duration(milliseconds: ms));

  test('5 sự kiện trong 100ms → danh sách tải lại MỘT lần sau 400ms', () async {
    final h = _Harness();
    h.container.listen(inboxListProvider, (_, _) {});
    await h.container.read(inboxListProvider.future);
    expect(h.api.listCalls, 1);

    await h.handshake();
    expect(h.subscribedChannels, contains('private-tenant.tenant-1.inbox'));

    for (var i = 0; i < 5; i++) {
      h.emit(
        channel: 'private-tenant.tenant-1.inbox',
        event: 'message.created',
        data: {'conversation_id': 'c$i', 'message_id': 'm$i'},
      );
      await wait(20);
    }
    expect(
      h.api.listCalls,
      1,
      reason: 'Chưa qua cửa sổ gộp thì chưa được hỏi lại API.',
    );

    // ~170ms sau sự kiện cuối: vẫn trong cửa sổ 400ms.
    await wait(150);
    expect(h.api.listCalls, 1);

    // Qua cửa sổ kể từ sự kiện CUỐI: đúng một lượt tải lại cho cả loạt.
    await wait(600);
    await h.container.read(inboxListProvider.future);
    expect(h.api.listCalls, 2);

    await wait(500);
    expect(h.api.listCalls, 2, reason: 'Không có lượt tải lại nào rơi rớt.');
  });

  test('sự kiện của hội thoại A không đụng tín hiệu của hội thoại B', () async {
    final h = _Harness();
    var bumpsA = 0;
    var bumpsB = 0;
    h.container.listen(threadSignalProvider('A'), (_, _) => bumpsA++);
    h.container.listen(threadSignalProvider('B'), (_, _) => bumpsB++);

    await h.handshake();
    expect(
      h.subscribedChannels,
      containsAll(['private-conversation.A', 'private-conversation.B']),
      reason: 'Mỗi màn chat tự xin kênh của hội thoại mình.',
    );

    h.emit(
      channel: 'private-conversation.A',
      event: 'message.created',
      data: {'conversation_id': 'A', 'message_id': 'm1'},
    );
    await wait(700);

    expect(bumpsA, 1);
    expect(
      bumpsB,
      0,
      reason: 'Hội thoại B không việc gì phải tải lại vì A có tin mới.',
    );
  });

  test('message.status vá trạng thái tại chỗ, không hỏi lại API', () async {
    final h = _Harness();
    h.api.history = [_serverMessage('m1', 'Dạ em gửi ạ', status: 'sent')];
    var bumps = 0;
    h.container.listen(threadProvider('A'), (_, _) {});
    h.container.listen(threadSignalProvider('A'), (_, _) => bumps++);
    await h.container.read(threadProvider('A').future);
    expect(h.api.messagesCalls, 1);

    await h.handshake();
    h.emit(
      channel: 'private-conversation.A',
      event: 'message.status',
      data: {'conversation_id': 'A', 'message_id': 'm1', 'status': 'read'},
    );
    await wait(700);

    final thread = h.container.read(threadProvider('A')).requireValue;
    expect(thread.messages.single.status, DeliveryStatus.read);
    expect(
      h.api.messagesCalls,
      1,
      reason:
          'Biên nhận chỉ đổi một trường của một tin đã có trên màn; kéo lại cả '
          'trang lịch sử cho việc đó là lãng phí đúng kiểu APP-02.',
    );
    expect(bumps, 0);
  });

  test(
    'message.status của tin CHƯA có trên màn thì tải lại như thường',
    () async {
      final h = _Harness();
      h.api.history = [_serverMessage('m1', 'a', status: 'sent')];
      h.container.listen(threadProvider('A'), (_, _) {});
      var bumps = 0;
      h.container.listen(threadSignalProvider('A'), (_, _) => bumps++);
      await h.container.read(threadProvider('A').future);

      await h.handshake();
      h.emit(
        channel: 'private-conversation.A',
        event: 'message.status',
        data: {'conversation_id': 'A', 'message_id': 'm-la', 'status': 'read'},
      );
      await wait(700);

      expect(bumps, 1, reason: 'Không vá được thì không được im lặng.');
    },
  );

  test(
    'tín hiệu FCM vẫn tới cả danh sách lẫn màn chat, cũng gộp nhịp',
    () async {
      // `inboxRealtimeSignalProvider` là thứ module notifications bấm khi có
      // thông báo đẩy ở nền trước. Nó phải còn nguyên chỗ, và phải chảy vào hai
      // tín hiệu mới — không thì FCM hiện banner mà màn hình đứng im.
      final h = _Harness();
      var threadBumps = 0;
      h.container.listen(inboxListProvider, (_, _) {});
      h.container.listen(threadSignalProvider('A'), (_, _) => threadBumps++);
      await h.container.read(inboxListProvider.future);
      expect(h.api.listCalls, 1);

      final fcm = h.container.read(inboxRealtimeSignalProvider.notifier);
      fcm.state = fcm.state + 1;
      fcm.state = fcm.state + 1;
      await wait(700);
      await h.container.read(inboxListProvider.future);

      expect(h.api.listCalls, 2);
      expect(threadBumps, 1);
    },
  );
}

class _Harness {
  _Harness() {
    client = RealtimeClient(
      config: const RealtimeConfig(
        key: 'test-key',
        host: 'ws.test',
        port: 443,
        useTls: true,
      ),
      socketFactory: (_) => socket,
      authorizer: (channel, socketId) async => 'key:sig-for-$channel',
    );
    container = ProviderContainer(
      overrides: [
        inboxApiProvider.overrideWithValue(api),
        realtimeClientProvider.overrideWithValue(client),
        sessionProvider.overrideWithValue(
          const Session(
            status: SessionStatus.authenticated,
            tenant: SessionTenant(id: 'tenant-1', name: 'Xưởng đàn'),
          ),
        ),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await client.disconnect();
    });
  }

  final socket = _FakeSocket();
  final api = _FakeInboxApi();
  late final RealtimeClient client;
  late final ProviderContainer container;

  static Future<void> _settle() => Future<void>.delayed(Duration.zero);

  /// Chỉ sau bắt tay client mới có socket id để ký đăng ký kênh riêng.
  Future<void> handshake() async {
    await _settle();
    socket.emit({
      'event': 'pusher:connection_established',
      'data': jsonEncode({'socket_id': '1.1'}),
    });
    await _settle();
    await _settle();
  }

  Iterable<String> get subscribedChannels => socket.sent
      .map((raw) => jsonDecode(raw) as Map<String, dynamic>)
      .where((frame) => frame['event'] == 'pusher:subscribe')
      .map((frame) => (frame['data'] as Map)['channel'] as String);

  /// Một khung tin y như Reverb gửi xuống.
  void emit({
    required String channel,
    required String event,
    required Map<String, dynamic> data,
  }) => socket.emit({
    'event': event,
    'channel': channel,
    'data': jsonEncode(data),
  });
}

Message _serverMessage(String id, String text, {String status = 'sent'}) {
  final minute = int.parse(id.replaceAll(RegExp(r'\D'), ''));
  return Message.fromJson({
    'id': id,
    'from': 'agent',
    'text': text,
    'status': status,
    'sent_at': DateTime.utc(2026, 1, 1, 8, minute).toIso8601String(),
  });
}

/// Đếm số lần màn hình hỏi lại server. Kế thừa client thật vì app nối một
/// [InboxApi] cụ thể chứ không phải interface; [ApiClient] đưa vào `super`
/// không bao giờ được dùng.
class _FakeInboxApi extends InboxApi {
  _FakeInboxApi() : super(ApiClient(Dio()));

  int listCalls = 0;
  int messagesCalls = 0;
  List<Message> history = const [];

  @override
  Future<Paged<Conversation>> list({
    required Map<String, dynamic> query,
    int page = 1,
    int perPage = AppConfig.defaultPerPage,
  }) async {
    listCalls++;
    return const Paged.empty();
  }

  @override
  Future<MessagePage> messages(
    String id, {
    String? before,
    int perPage = AppConfig.messagePageSize,
  }) async {
    messagesCalls++;
    return MessagePage(
      messages: history.reversed.toList(),
      cursor: const CursorPage.empty(),
    );
  }
}

/// Một socket mà bài kiểm tự viết khung vào và tự đọc khung gửi ra.
class _FakeSocket implements WebSocketChannel {
  final _incoming = StreamController<dynamic>.broadcast();
  final _sink = _FakeSink();

  List<String> get sent => _sink.sent;

  void emit(Map<String, dynamic> frame) => _incoming.add(jsonEncode(frame));

  @override
  Stream<dynamic> get stream => _incoming.stream;

  @override
  WebSocketSink get sink => _sink;

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSink implements WebSocketSink {
  final List<String> sent = [];

  @override
  void add(dynamic data) => sent.add(data as String);

  @override
  Future<void> close([int? closeCode, String? closeReason]) async {}

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
