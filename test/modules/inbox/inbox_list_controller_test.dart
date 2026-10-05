import 'dart:async';

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
import 'package:omni_app/modules/inbox/application/inbox_realtime.dart';
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
        inboxListSignalProvider.overrideWith(_ManualSignal.new),
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

  test(
    'trang 2 về sau khi danh sách đã làm mới → bỏ, không nối vào bản cũ',
    () async {
      api.pages = {
        1: ['c1', 'c2'],
        2: ['c3'],
      };
      await open();
      final gate = api.holds[2] = Completer<void>();
      final more = controller().loadMore();
      await Future<void>.delayed(Duration.zero);

      // c1 đã được xử lý ở chỗ khác; danh sách làm mới còn c2, c9 (một trang).
      api.pages = {
        1: ['c2', 'c9'],
      };
      await controller().refresh();
      expect(ids(), ['c2', 'c9']);

      gate.complete();
      await more;

      expect(ids(), ['c2', 'c9'], reason: 'c1 không được hiện lại.');
      expect(read().hasMore, isFalse);
      expect(read().loadingMore, isFalse);
    },
  );

  test('patch trong lúc trang 2 đang tải không bị trang 2 xoá mất', () async {
    api.pages = {
      1: ['c1', 'c2'],
      2: ['c3'],
    };
    await open();
    final gate = api.holds[2] = Completer<void>();
    final more = controller().loadMore();
    await Future<void>.delayed(Duration.zero);

    controller().patch(_conversation('c2', unread: 0));
    expect(read().loadingMore, isTrue, reason: 'Không mở cửa cho lượt trùng.');

    gate.complete();
    await more;

    expect(ids(), ['c1', 'c2', 'c3']);
    expect(read().items.map((c) => c.unread), [3, 0, 3]);
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

  // Đợt 7 P4 (APP-I3): phân trang theo con trỏ như web; tin mới chỉ gộp trang
  // 1, không dựng lại danh sách về 30 dòng đầu khi đang cuộn.
  group('con trỏ và tin mới', () {
    List<String> rows(String prefix, int n) => [
      for (var i = 0; i < n; i++) '$prefix$i',
    ];

    test(
      'lượt đầu không con trỏ; loadMore gửi next_before của trang 1',
      () async {
        api.pages = {1: rows('a', 30), 2: rows('b', 30), 3: rows('c', 30)};
        await open();
        await controller().loadMore();

        expect(api.calls.map((c) => c.before), [null, 'p2']);
        expect(read().hasMore, isTrue);
        expect(read().loadedBeyondFirstPage, isTrue);
      },
    );

    test(
      'đã cuộn tới trang 2, có tin mới → gộp trang 1, giữ các dòng đã tải',
      () async {
        api.pages = {1: rows('a', 30), 2: rows('b', 30), 3: rows('c', 30)};
        await open();
        await controller().loadMore();
        expect(read().items, hasLength(60));
        final before = api.calls.length;

        // `message.created`: hội thoại `moi` nhảy lên đầu trang 1.
        api.pages = {
          1: ['moi', ...rows('a', 29)],
          2: ['a29', ...rows('b', 29)],
          3: rows('c', 30),
        };
        (container.read(inboxListSignalProvider.notifier) as _ManualSignal)
            .bump();
        await pumpEventQueue();

        expect(api.calls.length, before + 1, reason: 'Một lượt, chỉ trang 1.');
        expect(api.calls.last.before, isNull);
        expect(read().items.length, greaterThanOrEqualTo(60));
        expect(read().items.first.id, 'moi');
        expect(
          ids().toSet().length,
          read().items.length,
          reason: 'Không trùng.',
        );
        expect(read().cursor.nextBefore, 'p3', reason: 'Giữ con trỏ đã cuộn.');
      },
    );

    test('chỉ có trang 1 trên màn → tin mới thay trang 1', () async {
      api.pages = {1: rows('a', 3)};
      await open();

      api.pages = {
        1: ['moi', 'a0', 'a1'],
      };
      (container.read(inboxListSignalProvider.notifier) as _ManualSignal)
          .bump();
      await pumpEventQueue();

      expect(ids(), ['moi', 'a0', 'a1']);
    });
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

typedef _ListCall = ({Map<String, dynamic> query, String? before, int page});

/// Stands in for the HTTP layer. Subclasses the real client because the app
/// wires a concrete [InboxApi]; the [ApiClient] handed to `super` is never used.
///
/// Phân trang theo con trỏ như API (Đợt 7 P4): trang N trả `next_before`
/// = `p{N+1}` khi còn trang sau.
class _FakeInboxApi extends InboxApi {
  _FakeInboxApi() : super(ApiClient(Dio()));

  Map<int, List<String>> pages = const {};
  bool failNextList = false;
  final calls = <_ListCall>[];

  /// Trang nào đang bị giữ lại (mạng chậm) cho tới khi completer xong.
  final holds = <int, Completer<void>>{};

  @override
  Future<CursorPaged<Conversation>> list({
    required Map<String, dynamic> query,
    String? before,
    int perPage = AppConfig.defaultPerPage,
  }) async {
    final page = before == null ? 1 : int.parse(before.substring(1));
    calls.add((query: query, before: before, page: page));
    // Trả dữ liệu của LÚC HỎI — trang về muộn mang dữ liệu cũ.
    final pages = this.pages;
    await holds[page]?.future;
    if (failNextList) {
      failNextList = false;
      throw const NetworkException('Không có kết nối mạng.');
    }
    final last = pages.isEmpty ? 1 : pages.keys.reduce((a, b) => a > b ? a : b);
    return CursorPaged(
      items: (pages[page] ?? const []).map(_conversation).toList(),
      cursor: CursorPage(
        perPage: perPage,
        hasMore: page < last,
        nextBefore: page < last ? 'p${page + 1}' : null,
      ),
    );
  }
}

/// Tín hiệu danh sách mà bài kiểm tự bấm (thay `message.created` qua socket).
class _ManualSignal extends InboxListSignal {
  @override
  int build() => 0;

  void bump() => state = state + 1;
}
