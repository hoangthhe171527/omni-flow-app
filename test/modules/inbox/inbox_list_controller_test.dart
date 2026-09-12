import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/core/config/app_config.dart';
import 'package:omni_app/core/domain/channel.dart';
import 'package:omni_app/core/error/app_exception.dart';
import 'package:omni_app/core/network/api_client.dart';
import 'package:omni_app/core/network/api_envelope.dart';
import 'package:omni_app/core/realtime/realtime_client.dart';
import 'package:omni_app/modules/inbox/application/inbox_providers.dart';
import 'package:omni_app/modules/inbox/data/inbox_api.dart';
import 'package:omni_app/modules/inbox/domain/conversation.dart';
import 'package:omni_app/modules/inbox/domain/inbox_filter.dart';
import 'package:omni_app/security/session/session.dart';
import 'package:omni_app/security/session/session_controller.dart';

/// Danh sách hộp thư: phân trang, vá tại chỗ, đổi bộ lọc.
///
/// Controller này chưa từng có test; mọi hành vi dưới đây đều đã chạy thật
/// trên máy rep và chỉ được kiểm bằng mắt.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeInboxApi api;
  late ProviderContainer container;

  setUp(() {
    api = _FakeInboxApi();
    container = ProviderContainer(
      overrides: [
        inboxApiProvider.overrideWithValue(api),
        // Không realtime: tín hiệu danh sách vẫn dựng được mà không mở socket.
        realtimeClientProvider.overrideWithValue(
          RealtimeClient(
            config: const RealtimeConfig.disabled(),
            authorizer: (_, _) async => '',
          ),
        ),
        sessionProvider.overrideWithValue(
          const Session(
            status: SessionStatus.authenticated,
            user: SessionUser(id: 'u1', fullName: 'Kiệt', email: 'k@x.vn'),
            tenant: SessionTenant(id: 't1', name: 'Xưởng đàn'),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
  });

  /// AutoDispose: không có người nghe thì provider bị dọn giữa hai lần đọc.
  Future<ConversationListState> open() {
    container.listen(inboxListProvider, (_, _) {});
    return container.read(inboxListProvider.future);
  }

  InboxListController controller() =>
      container.read(inboxListProvider.notifier);

  ConversationListState read() =>
      container.read(inboxListProvider).requireValue;

  Iterable<String> ids() => read().items.map((c) => c.id);

  test(
    'trang 2 lỗi → giữ nguyên trang 1, hết loadingMore, còn hasMore',
    () async {
      api.pages = {
        1: ['c1', 'c2'],
        2: ['c3'],
      };
      await open();
      expect(ids(), ['c1', 'c2']);
      expect(read().hasMore, isTrue);

      api.failNextList = true;
      await controller().loadMore();

      expect(ids(), [
        'c1',
        'c2',
      ], reason: 'Trang đang xem không được biến mất.');
      expect(read().loadingMore, isFalse);
      expect(read().hasMore, isTrue, reason: 'Footer còn chỗ để thử lại.');

      // Thử lại thì nối tiếp.
      await controller().loadMore();
      expect(ids(), ['c1', 'c2', 'c3']);
      expect(read().hasMore, isFalse);
    },
  );

  test('loadMore đang bay thì lượt gọi thứ hai không xếp chồng', () async {
    api.pages = {
      1: ['c1'],
      2: ['c2'],
    };
    await open();

    final first = controller().loadMore();
    final second = controller().loadMore();
    await Future.wait([first, second]);

    expect(ids(), ['c1', 'c2'], reason: 'Không có trang 2 lặp đôi.');
    expect(api.calls.where((c) => c.page == 2), hasLength(1));
  });

  test('patch thay đúng một hội thoại theo id, giữ thứ tự', () async {
    api.pages = {
      1: ['c1', 'c2'],
    };
    await open();

    controller().patch(_conversation('c2', unread: 0));

    expect(ids(), ['c1', 'c2']);
    expect(read().items.map((c) => c.unread), [3, 0]);
  });

  test('đổi bộ lọc → tải lại từ trang 1 với query mới', () async {
    api.pages = {
      1: ['c1', 'c2'],
      2: ['c3'],
    };
    await open();
    await controller().loadMore();
    expect(ids(), ['c1', 'c2', 'c3']);

    container
        .read(inboxFilterProvider.notifier)
        .setQuick(InboxQuickFilter.unread);
    await container.read(inboxListProvider.future);

    final last = api.calls.last;
    expect(last.page, 1);
    expect(last.query['unread'], 1);
    expect(ids(), ['c1', 'c2'], reason: 'Cửa sổ trang cũ không được giữ lại.');
    expect(read().hasMore, isTrue);
  });

  test('refresh giữ dữ liệu cũ trên màn trong lúc chờ', () async {
    api.pages = {
      1: ['c1'],
    };
    await open();

    api.pages = {
      1: ['c1', 'c9'],
    };
    final refreshing = controller().refresh();
    expect(
      container.read(inboxListProvider).valueOrNull?.items.map((c) => c.id),
      ['c1'],
      reason: 'Không nháy skeleton giữa hai lần tải.',
    );
    await refreshing;

    expect(ids(), ['c1', 'c9']);
  });
}

Conversation _conversation(String id, {int unread = 3}) => Conversation(
  id: id,
  channel: Channel.zalo,
  status: ConversationStatus.open,
  customerName: 'Khách $id',
  lastMessage: 'Tin của $id',
  unread: unread,
);

typedef _ListCall = ({Map<String, dynamic> query, int page});

/// Stands in for the HTTP layer. Subclasses the real client because the app
/// wires a concrete [InboxApi]; the [ApiClient] handed to `super` is never used.
class _FakeInboxApi extends InboxApi {
  _FakeInboxApi() : super(ApiClient(Dio()));

  Map<int, List<String>> pages = const {};
  bool failNextList = false;
  final calls = <_ListCall>[];

  @override
  Future<Paged<Conversation>> list({
    required Map<String, dynamic> query,
    int page = 1,
    int perPage = AppConfig.defaultPerPage,
  }) async {
    calls.add((query: query, page: page));
    if (failNextList) {
      failNextList = false;
      throw const NetworkException('Không có kết nối mạng.');
    }
    return Paged(
      items: (pages[page] ?? const []).map(_conversation).toList(),
      pagination: ApiPagination(
        currentPage: page,
        lastPage: pages.isEmpty
            ? 1
            : pages.keys.reduce((a, b) => a > b ? a : b),
        perPage: perPage,
        total: pages.values.fold(0, (sum, items) => sum + items.length),
      ),
    );
  }
}
