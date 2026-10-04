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
import 'package:omni_app/modules/inbox/domain/inbox_filter.dart';
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
/// Đồng hồ GIẢ (testWidgets/FakeAsync, `tester.pump`): Timer gộp nhịp 400ms
/// chạy đúng theo mốc kiểm. Bản đồng hồ thật chỉ dư 300ms và từng đỏ khi máy
/// bận chạy việc khác song song.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('5 sự kiện trong 100ms → danh sách tải lại MỘT lần sau 400ms', (
    tester,
  ) async {
    final h = _Harness();
    h.container.listen(inboxListProvider, (_, _) {});
    await h.container.read(inboxListProvider.future);
    expect(h.api.listCalls, 1);

    await h.handshakeFake(tester);
    expect(h.subscribedChannels, contains('private-tenant.tenant-1.inbox'));

    for (var i = 0; i < 5; i++) {
      h.emit(
        channel: 'private-tenant.tenant-1.inbox',
        event: 'message.created',
        data: {'conversation_id': 'c$i', 'message_id': 'm$i'},
      );
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(
      h.api.listCalls,
      1,
      reason: 'Chưa qua cửa sổ gộp thì chưa được hỏi lại API.',
    );

    // ~170ms sau sự kiện cuối: vẫn trong cửa sổ 400ms.
    await tester.pump(const Duration(milliseconds: 150));
    expect(h.api.listCalls, 1);

    // Qua cửa sổ kể từ sự kiện CUỐI: đúng một lượt tải lại cho cả loạt.
    await tester.pump(const Duration(milliseconds: 600));
    await h.container.read(inboxListProvider.future);
    expect(h.api.listCalls, 2);

    await tester.pump(const Duration(milliseconds: 500));
    expect(h.api.listCalls, 2, reason: 'Không có lượt tải lại nào rơi rớt.');
  });

  // Đợt 6 P1 (INB-I7): admin giao hội thoại cho sale mà không có tin mới thì
  // API chỉ phát `conversation.updated` (chỉ id) — danh sách của sale phải tự
  // hỏi lại, không chờ nhịp poll 2 phút.
  testWidgets('conversation.updated → danh sách tải lại', (tester) async {
    final h = _Harness();
    h.container.listen(inboxListProvider, (_, _) {});
    await h.container.read(inboxListProvider.future);
    expect(h.api.listCalls, 1);

    await h.handshakeFake(tester);
    h.emit(
      channel: 'private-tenant.tenant-1.inbox',
      event: 'conversation.updated',
      data: {
        'conversation_id': 'c1',
        'conversation_ids': ['c1'],
        'reason': 'assigned',
      },
    );

    await tester.pump(const Duration(milliseconds: 700));
    await h.container.read(inboxListProvider.future);
    expect(h.api.listCalls, 2);
  });

  // Fix vòng 1 (I2): `read`/`sent` tới mọi máy trong tenant. Tải lại trang 1
  // cho mỗi sự kiện vừa tốn vừa làm danh sách đang cuộn co về 20 dòng.
  // Đồng hồ GIẢ (testWidgets/FakeAsync): Timer gộp nhịp 400ms chạy theo
  // `tester.pump`, không phụ thuộc máy bận. Bản đồng hồ thật chỉ dư 300ms và
  // từng đỏ khi máy chạy song song việc khác.
  group('conversation.updated vá theo id', () {
    Future<_Harness> loaded(WidgetTester tester, {int pagesLoaded = 1}) async {
      final h = _Harness();
      h.api.pages = (page) => _page(page);
      h.api.onGet = (id) => _conv(id, last: 'mới');
      h.container.listen(inboxListProvider, (_, _) {});
      await h.container.read(inboxListProvider.future);
      for (var i = 1; i < pagesLoaded; i++) {
        await h.container.read(inboxListProvider.notifier).loadMore();
      }
      await h.handshakeFake(tester);
      return h;
    }

    ConversationListState list(_Harness h) =>
        h.container.read(inboxListProvider).requireValue;

    testWidgets('dòng đang hiện: hỏi đúng hội thoại đó, vá tại chỗ', (
      tester,
    ) async {
      final h = await loaded(tester);
      h.emit(
        channel: 'private-tenant.tenant-1.inbox',
        event: 'conversation.updated',
        data: {
          'conversation_id': 'p1-3',
          'conversation_ids': ['p1-3'],
          'reason': 'labels',
        },
      );
      await tester.pump(const Duration(milliseconds: 700));

      expect(h.api.listCalls, 1, reason: 'Không tải lại trang.');
      expect(h.api.getCalls, ['p1-3']);
      expect(list(h).items[3].id, 'p1-3');
      expect(list(h).items[3].lastMessage, 'mới');
    });

    testWidgets(
      'hội thoại mới được giao khi đã cuộn tới trang 2: gộp, không co '
      'danh sách',
      (tester) async {
        final h = await loaded(tester, pagesLoaded: 2);
        expect(list(h).items, hasLength(40));
        // GET theo id: hội thoại khớp bộ lọc và mới nhất — chèn lên đầu, không
        // phải hỏi lại trang 1.
        h.api.onGet = (id) => _conv(id, at: DateTime.utc(2026, 1, 2));

        h.emit(
          channel: 'private-tenant.tenant-1.inbox',
          event: 'conversation.updated',
          data: {
            'conversation_id': 'moi',
            'conversation_ids': ['moi'],
            'reason': 'assigned',
          },
        );
        await tester.pump(const Duration(milliseconds: 700));

        expect(h.api.listCalls, 2, reason: 'Không tải lại trang 1.');
        expect(list(h).items.first.id, 'moi');
        expect(list(h).items, hasLength(41));
        expect(list(h).pagination.currentPage, 2, reason: 'Giữ trang đã tải.');
      },
    );

    // Fix vòng 2 (RI8): dòng vá xong phải được xét lại theo bộ lọc đang chọn.
    testWidgets('tab "Chưa gán": hội thoại vừa được giao rời danh sách ngay', (
      tester,
    ) async {
      final h = _Harness();
      h.api.pages = (page) => _page(page);
      h.api.onGet = (id) => _conv(id, assignee: 'u-9');
      h.container.listen(inboxListProvider, (_, _) {});
      h.container
          .read(inboxFilterProvider.notifier)
          .setQuick(InboxQuickFilter.unassigned);
      await h.container.read(inboxListProvider.future);
      await h.handshakeFake(tester);

      h.emit(
        channel: 'private-tenant.tenant-1.inbox',
        event: 'conversation.updated',
        data: {
          'conversation_id': 'p1-3',
          'conversation_ids': ['p1-3'],
          'reason': 'assigned',
        },
      );
      await tester.pump(const Duration(milliseconds: 700));

      expect(list(h).items.map((c) => c.id), isNot(contains('p1-3')));
      expect(list(h).items, hasLength(19));
    });

    testWidgets('tab "Tất cả": hội thoại vừa đóng rời danh sách', (
      tester,
    ) async {
      final h = await loaded(tester);
      h.api.onGet = (id) => _conv(id, status: 'closed');

      h.emit(
        channel: 'private-tenant.tenant-1.inbox',
        event: 'conversation.updated',
        data: {
          'conversation_id': 'p1-0',
          'conversation_ids': ['p1-0'],
          'reason': 'updated',
        },
      );
      await tester.pump(const Duration(milliseconds: 700));

      expect(list(h).items.map((c) => c.id), isNot(contains('p1-0')));
    });

    testWidgets('đang tìm kiếm (không tự xét được): vá rồi hỏi lại trang 1', (
      tester,
    ) async {
      final h = _Harness();
      h.api.pages = (page) => _page(page);
      h.api.onGet = (id) => _conv(id, last: 'mới');
      h.container.listen(inboxListProvider, (_, _) {});
      h.container.read(inboxFilterProvider.notifier).setSearch('nguyen');
      await h.container.read(inboxListProvider.future);
      await h.handshakeFake(tester);
      final before = h.api.listCalls;

      h.emit(
        channel: 'private-tenant.tenant-1.inbox',
        event: 'conversation.updated',
        data: {
          'conversation_id': 'p1-3',
          'conversation_ids': ['p1-3'],
          'reason': 'labels',
        },
      );
      await tester.pump(const Duration(milliseconds: 700));

      expect(h.api.listCalls, before + 1);
    });

    testWidgets('read của hội thoại không có trên màn: không hỏi gì', (
      tester,
    ) async {
      final h = await loaded(tester);
      h.emit(
        channel: 'private-tenant.tenant-1.inbox',
        event: 'conversation.updated',
        data: {
          'conversation_id': 'khac',
          'conversation_ids': ['khac'],
          'reason': 'read',
        },
      );
      await tester.pump(const Duration(milliseconds: 700));

      expect(h.api.listCalls, 1);
      expect(h.api.getCalls, isEmpty);
    });
  });

  testWidgets('sự kiện dồn liên tục: vẫn tải lại sau tối đa ~2 giây', (
    tester,
  ) async {
    final h = _Harness();
    h.container.listen(inboxListProvider, (_, _) {});
    await h.container.read(inboxListProvider.future);
    await h.handshakeFake(tester);

    // Cách nhau 150ms suốt 2,7 giây: debounce 400ms thuần không bao giờ bắn.
    for (var i = 0; i < 18; i++) {
      h.emit(
        channel: 'private-tenant.tenant-1.inbox',
        event: 'message.created',
        data: {'conversation_id': 'c$i', 'message_id': 'm$i'},
      );
      await tester.pump(const Duration(milliseconds: 150));
    }

    expect(h.api.listCalls, greaterThanOrEqualTo(2));
    // Đồng hồ giả: cho Timer gộp nhịp còn dở chạy hết trước khi test kết thúc.
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('sự kiện của hội thoại A không đụng tín hiệu của hội thoại B', (
    tester,
  ) async {
    final h = _Harness();
    var bumpsA = 0;
    var bumpsB = 0;
    h.container.listen(threadSignalProvider('A'), (_, _) => bumpsA++);
    h.container.listen(threadSignalProvider('B'), (_, _) => bumpsB++);

    await h.handshakeFake(tester);
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
    await tester.pump(const Duration(milliseconds: 700));

    expect(bumpsA, 1);
    expect(
      bumpsB,
      0,
      reason: 'Hội thoại B không việc gì phải tải lại vì A có tin mới.',
    );
  });

  testWidgets('message.status vá trạng thái tại chỗ, không hỏi lại API', (
    tester,
  ) async {
    final h = _Harness();
    h.api.history = [_serverMessage('m1', 'Dạ em gửi ạ', status: 'sent')];
    var bumps = 0;
    h.container.listen(threadProvider('A'), (_, _) {});
    h.container.listen(threadSignalProvider('A'), (_, _) => bumps++);
    await h.container.read(threadProvider('A').future);
    expect(h.api.messagesCalls, 1);

    await h.handshakeFake(tester);
    h.emit(
      channel: 'private-conversation.A',
      event: 'message.status',
      data: {'conversation_id': 'A', 'message_id': 'm1', 'status': 'read'},
    );
    await tester.pump(const Duration(milliseconds: 700));

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

  testWidgets(
    'message.status của tin CHƯA có trên màn thì tải lại như thường',
    (tester) async {
      final h = _Harness();
      h.api.history = [_serverMessage('m1', 'a', status: 'sent')];
      h.container.listen(threadProvider('A'), (_, _) {});
      var bumps = 0;
      h.container.listen(threadSignalProvider('A'), (_, _) => bumps++);
      await h.container.read(threadProvider('A').future);

      await h.handshakeFake(tester);
      h.emit(
        channel: 'private-conversation.A',
        event: 'message.status',
        data: {'conversation_id': 'A', 'message_id': 'm-la', 'status': 'read'},
      );
      await tester.pump(const Duration(milliseconds: 700));

      expect(bumps, 1, reason: 'Không vá được thì không được im lặng.');
    },
  );

  testWidgets('tín hiệu FCM vẫn tới cả danh sách lẫn màn chat, cũng gộp nhịp', (
    tester,
  ) async {
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
    await tester.pump(const Duration(milliseconds: 700));
    await h.container.read(inboxListProvider.future);

    expect(h.api.listCalls, 2);
    expect(threadBumps, 1);
  });
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

  /// Như [handshake] nhưng trong testWidgets (đồng hồ giả): Timer 0ms chỉ
  /// chạy khi `pump`.
  Future<void> handshakeFake(WidgetTester tester) async {
    await tester.pump();
    socket.emit({
      'event': 'pusher:connection_established',
      'data': jsonEncode({'socket_id': '1.1'}),
    });
    await tester.pump();
    await tester.pump();
  }

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

  /// Trang server trả theo số trang; null = danh sách rỗng như cũ.
  Paged<Conversation> Function(int page)? pages;
  final List<String> getCalls = [];
  Conversation Function(String id)? onGet;

  @override
  Future<Paged<Conversation>> list({
    required Map<String, dynamic> query,
    int page = 1,
    int perPage = AppConfig.defaultPerPage,
  }) async {
    listCalls++;
    return pages?.call(page) ?? const Paged.empty();
  }

  @override
  Future<Conversation> get(String id) async {
    getCalls.add(id);
    return onGet!(id);
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

Conversation _conv(
  String id, {
  String last = '',
  DateTime? at,
  String? assignee,
  String status = 'open',
}) => Conversation.fromJson({
  'id': id,
  'channel': 'zalo',
  'last_message': last,
  'status': status,
  if (at != null) 'last_message_at': at.toIso8601String(),
  'assignee': ?assignee,
});

Paged<Conversation> _page(int page) => Paged(
  items: [
    for (var i = 0; i < 20; i++)
      _conv(
        'p$page-$i',
        at: DateTime.utc(2026).subtract(Duration(minutes: page * 100 + i)),
      ),
  ],
  pagination: ApiPagination(
    currentPage: page,
    lastPage: 3,
    perPage: 20,
    total: 60,
  ),
);
