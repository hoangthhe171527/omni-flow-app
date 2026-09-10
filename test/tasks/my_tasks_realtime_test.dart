import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/core/config/app_config.dart';
import 'package:omni_app/core/network/api_envelope.dart';
import 'package:omni_app/core/realtime/realtime_client.dart';
import 'package:omni_app/modules/tasks/application/tasks_providers.dart';
import 'package:omni_app/modules/tasks/data/tasks_api.dart';
import 'package:omni_app/modules/tasks/domain/task.dart';
import 'package:omni_app/security/session/session.dart';
import 'package:omni_app/security/session/session_controller.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Danh sách "Việc của tôi" phải tự đổi khi quản đốc đổi việc ở chỗ khác.
///
/// Vì sao bài này tồn tại: `taskRealtimeSignalProvider` đã được khai và đã được
/// bốn provider theo dõi, nhưng không chỗ nào tăng nó. Bài kiểm sẵn có của
/// chuông ("a realtime signal reloads the list") tự tay tăng tín hiệu rồi kiểm
/// nửa sau — nên đúng nửa bị đứt, mảnh nối socket với tín hiệu, không ai kiểm.
/// Bài này cố ý KHÔNG chạm vào tín hiệu: nó chỉ thả một khung tin y như Reverb
/// gửi, rồi đòi danh sách phải tự hỏi lại API.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('quản đốc đổi việc trên web thì danh sách trong app tự tải lại', () async {
    final socket = _FakeSocket();
    final api = _CountingTasksApi();
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
        tasksApiProvider.overrideWithValue(api),
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

    Future<void> settle() => Future<void>.delayed(Duration.zero);

    // Màn hình mở ra. AutoDispose: không có người nghe thì provider bị dọn ngay
    // giữa hai lần đọc.
    container.listen(myTasksProvider, (_, _) {});
    await container.read(myTasksProvider.future);
    expect(api.mineCalls, 1);

    // Chỉ sau bắt tay client mới có socket id để ký đăng ký kênh riêng.
    await settle();
    socket.emit({
      'event': 'pusher:connection_established',
      'data': jsonEncode({'socket_id': '1.1'}),
    });
    await settle();
    await settle();

    expect(
      socket.sent
          .map((raw) => jsonDecode(raw) as Map<String, dynamic>)
          .where((frame) => frame['event'] == 'pusher:subscribe')
          .map((frame) => (frame['data'] as Map)['channel']),
      contains('private-tenant.tenant-1.entities'),
      reason:
          'Không xin kênh này thì không tin nào tới, và cái im lặng đó đọc '
          'giống hệt một xưởng không có gì thay đổi.',
    );

    // Quản đốc kéo một cây đàn sang công đoạn khác trên web. Tên sự kiện trên
    // dây là đúng thứ Laravel gửi: broadcastAs() trả 'entity.changed', không có
    // dấu chấm đầu (client vẫn cắt dấu chấm nếu có).
    socket.emit({
      'event': 'entity.changed',
      'channel': 'private-tenant.tenant-1.entities',
      'data': jsonEncode({'type': 'task', 'id': 't1', 'action': 'updated'}),
    });
    await settle();
    await container.read(myTasksProvider.future);

    expect(
      api.mineCalls,
      2,
      reason:
          'Phải hỏi lại API chứ không vẽ theo payload: payload broadcast chưa '
          'qua bộ lọc quyền của người xem.',
    );
  });
}

/// Đếm số lần danh sách hỏi lại server. Chỉ cần `mine`; phần còn lại của
/// TasksApi để noSuchMethod lo, đúng kiểu _FakeSocket trong realtime_client_test.
class _CountingTasksApi implements TasksApi {
  int mineCalls = 0;

  @override
  Future<Paged<Task>> mine({
    required TaskBucket bucket,
    int page = 1,
    int perPage = AppConfig.defaultPerPage,
  }) async {
    mineCalls++;

    return Paged(
      items: [
        Task.fromJson({'id': 't1', 'title': 'Đàn Yamaha U1'}),
      ],
      pagination: const ApiPagination.empty(),
    );
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
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
