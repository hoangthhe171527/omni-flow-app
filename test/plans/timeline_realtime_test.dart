import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/core/realtime/realtime_client.dart';
import 'package:omni_app/modules/plans/application/plans_providers.dart';
import 'package:omni_app/modules/plans/data/plans_api.dart';
import 'package:omni_app/modules/plans/domain/feed_entry.dart';
import 'package:omni_app/security/session/session.dart';
import 'package:omni_app/security/session/session_controller.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Dòng việc phải tự đổi khi người thợ tick xong một công đoạn ở chỗ khác.
///
/// Vì sao bài này tồn tại: `tasksRealtimeSubscriptionProvider` — cái DUY NHẤT
/// mở kênh WebSocket — chỉ được theo dõi ở đúng một nơi, `MyTasksController`.
/// Bốn provider khác theo dõi tín hiệu mà không nơi nào mở kênh cho: bảng dự
/// án, thẻ KPI, dòng việc, và tải việc của một người.
///
/// `MyTasksController` là autoDispose, nên realtime của bốn màn kia sống chết
/// theo việc màn "Việc của tôi" có tình cờ còn trong bộ nhớ hay không. Kiểu
/// hỏng tệ nhất: CÓ LÚC CHẠY.
///
/// Bài này cố ý KHÔNG đọc `myTasksProvider` và KHÔNG tự tăng tín hiệu. Nó chỉ
/// mở dòng việc, thả một khung tin y như Reverb gửi, rồi đòi dòng việc phải tự
/// hỏi lại API.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  ({ProviderContainer container, _FakeSocket socket, _CountingPlansApi api})
  harness() {
    final socket = _FakeSocket();
    final api = _CountingPlansApi();
    final client = RealtimeClient(
      config: const RealtimeConfig(
        key: 'test-key',
        host: 'ws.test',
        port: 443,
        useTls: true,
      ),
      socketFactory: (_) => socket,
      authorizer: (channel, socketId) async => 'key:sig-for-$channel',
    );

    final container = ProviderContainer(
      overrides: [
        plansApiProvider.overrideWithValue(api),
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

    return (container: container, socket: socket, api: api);
  }

  Future<void> handshake(_FakeSocket socket) async {
    // Chỉ sau bắt tay client mới có socket id để ký đăng ký kênh riêng.
    await settle();
    socket.emit({
      'event': 'pusher:connection_established',
      'data': jsonEncode({'socket_id': '1.1'}),
    });
    await settle();
    await settle();
  }

  test('mở dòng việc là đủ để kênh được xin', () async {
    final h = harness();

    // KHÔNG đọc myTasksProvider, KHÔNG đọc một provider đăng ký nào khác.
    h.container.listen(workshopFeedProvider, (_, _) {});
    await h.container.read(workshopFeedProvider.future);
    await handshake(h.socket);

    expect(
      h.socket.sent
          .map((raw) => jsonDecode(raw) as Map<String, dynamic>)
          .where((frame) => frame['event'] == 'pusher:subscribe')
          .map((frame) => (frame['data'] as Map)['channel']),
      contains('private-tenant.tenant-1.entities'),
      reason:
          'Không xin kênh này thì không tin nào tới, và cái im lặng đó đọc '
          'giống hệt một xưởng chưa ai tick xong việc nào.',
    );
  });

  test('thợ tick xong một việc con thì dòng việc tự tải lại', () async {
    final h = harness();

    h.container.listen(workshopFeedProvider, (_, _) {});
    await h.container.read(workshopFeedProvider.future);
    expect(h.api.feedCalls, 1);

    await handshake(h.socket);

    h.socket.emit({
      'event': 'entity.changed',
      'channel': 'private-tenant.tenant-1.entities',
      'data': jsonEncode({'type': 'task', 'id': 't1', 'action': 'updated'}),
    });

    // Gộp nhịp: tín hiệu chỉ tăng sau khi lặng một quãng.
    await Future<void>.delayed(const Duration(milliseconds: 600));
    await h.container.read(workshopFeedProvider.future);

    expect(
      h.api.feedCalls,
      2,
      reason:
          'Phải hỏi lại API chứ không vẽ theo payload: payload broadcast chưa '
          'qua bộ lọc quyền của người xem.',
    );
  });

  test('ba lần tick dồn dập chỉ tốn MỘT lượt tải lại', () async {
    // Một cây đàn có ~10 công đoạn và thợ tick liên tiếp. Ba sự kiện trong hai
    // giây mà ba lượt tải lại toàn bộ dòng việc là ba lần quét nhật ký cả
    // xưởng để vẽ ra cùng một màn hình.
    final h = harness();

    h.container.listen(workshopFeedProvider, (_, _) {});
    await h.container.read(workshopFeedProvider.future);
    await handshake(h.socket);

    for (var i = 0; i < 3; i++) {
      h.socket.emit({
        'event': 'entity.changed',
        'channel': 'private-tenant.tenant-1.entities',
        'data': jsonEncode({'type': 'task', 'id': 't$i', 'action': 'updated'}),
      });
      await settle();
    }

    await Future<void>.delayed(const Duration(milliseconds: 600));
    await h.container.read(workshopFeedProvider.future);

    expect(h.api.feedCalls, 2);
  });

  test('thực thể khác task không đánh thức dòng việc', () async {
    final h = harness();

    h.container.listen(workshopFeedProvider, (_, _) {});
    await h.container.read(workshopFeedProvider.future);
    await handshake(h.socket);

    // Kênh này chở MỌI loại thực thể của tenant. Một khách hàng ai đó sửa
    // không việc gì phải kéo theo một lượt quét nhật ký cả xưởng.
    h.socket.emit({
      'event': 'entity.changed',
      'channel': 'private-tenant.tenant-1.entities',
      'data': jsonEncode({'type': 'customer', 'id': 'c1'}),
    });

    await Future<void>.delayed(const Duration(milliseconds: 600));

    expect(h.api.feedCalls, 1);
  });
}

/// Đếm số lần dòng việc hỏi lại server. Phần còn lại của PlansApi để
/// noSuchMethod lo, đúng kiểu `_CountingTasksApi` trong my_tasks_realtime_test.
class _CountingPlansApi implements PlansApi {
  int feedCalls = 0;

  @override
  Future<WorkshopFeed> feed({
    List<String> types = const [],
    int days = 7,
    int limit = 30,
  }) async {
    feedCalls++;

    return (entries: const <FeedEntry>[], truncated: false);
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

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
