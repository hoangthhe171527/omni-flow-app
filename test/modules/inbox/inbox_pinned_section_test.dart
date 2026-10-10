import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:omni_app/core/config/app_config.dart';
import 'package:omni_app/core/domain/channel.dart';
import 'package:omni_app/core/error/app_exception.dart';
import 'package:omni_app/core/network/api_client.dart';
import 'package:omni_app/core/network/api_envelope.dart';
import 'package:omni_app/core/realtime/realtime_client.dart';
import 'package:omni_app/design/components/components.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/modules/inbox/application/inbox_providers.dart';
import 'package:omni_app/modules/inbox/data/inbox_api.dart';
import 'package:omni_app/modules/inbox/domain/conversation.dart';
import 'package:omni_app/modules/inbox/domain/inbox_filter.dart';
import 'package:omni_app/modules/inbox/presentation/inbox_page.dart';
import 'package:omni_app/security/permissions/access_policy.dart';
import 'package:omni_app/security/session/session.dart';
import 'package:omni_app/security/session/session_controller.dart';

/// Mục "Đã ghim" ở đầu Hộp thư (Hộp thư mobile Task 2): một trang
/// `pinned=1&per_page=50` riêng, danh sách chính `pinned=0`.
void main() {
  setUpAll(() => initializeDateFormatting('vi_VN'));

  late _FakeInboxApi api;

  setUp(() => api = _FakeInboxApi());

  Widget host({
    Set<String> permissions = const {'inbox.read', 'inbox.write'},
  }) => ProviderScope(
    overrides: [
      inboxApiProvider.overrideWithValue(api),
      realtimeClientProvider.overrideWithValue(
        RealtimeClient(
          config: const RealtimeConfig.disabled(),
          authorizer: (_, _) async => '',
        ),
      ),
      sessionProvider.overrideWithValue(
        Session(
          status: SessionStatus.authenticated,
          user: const SessionUser(id: 'u1', fullName: 'Kiệt', email: 'k@x.vn'),
          tenant: const SessionTenant(id: 't1', name: 'Xưởng đàn'),
          policy: AccessPolicy(permissions),
        ),
      ),
    ],
    child: MaterialApp(
      theme: OmniTheme.light(TargetPlatform.android),
      home: const InboxPage(),
    ),
  );

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(host());
    await tester.pump();
    await tester.pump();
  }

  /// Trang có poll (Timer): gỡ trước khi bài kết thúc.
  Future<void> closePage(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  }

  testWidgets(
    'có ghim: "Đã ghim" + dòng ghim ở trên, rồi "Hội thoại" + dòng thường',
    (tester) async {
      api.main = [_c('c1', 'Minh Trần')];
      api.pinned = [_c('p1', 'Lan Anh', pinned: true)];
      await open(tester);

      expect(find.text('Đã ghim'), findsOneWidget);
      expect(find.text('Hội thoại'), findsOneWidget);
      final y = tester.getTopLeft;
      expect(y(find.text('Đã ghim')).dy, lessThan(y(find.text('Lan Anh')).dy));
      expect(
        y(find.text('Lan Anh')).dy,
        lessThan(y(find.text('Hội thoại')).dy),
      );
      expect(
        y(find.text('Hội thoại')).dy,
        lessThan(y(find.text('Minh Trần')).dy),
      );

      final main = api.calls.where((c) => c.pinned != true).toList();
      final pinned = api.calls.where((c) => c.pinned == true).toList();
      expect(main, isNotEmpty);
      expect(main.every((c) => c.pinned == false), isTrue);
      expect(pinned, isNotEmpty);
      expect(pinned.first.perPage, 50);
      expect(pinned.first.query['status'], 'open');
      await closePage(tester);
    },
  );

  testWidgets('7 dòng ghim → 5 + "Xem thêm 2"; bấm → đủ 7 và "Thu gọn"', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    api.main = [_c('c1', 'Minh Trần')];
    api.pinned = [
      for (var i = 1; i <= 7; i++) _c('p$i', 'Ghim số $i', pinned: true),
    ];
    await open(tester);

    expect(find.textContaining(RegExp(r'^Ghim số \d$')), findsNWidgets(5));
    expect(find.text('Xem thêm 2'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('inbox-pinned-more'))).height,
      greaterThanOrEqualTo(44),
    );

    await tester.tap(find.text('Xem thêm 2'));
    await tester.pump();
    expect(find.textContaining(RegExp(r'^Ghim số \d$')), findsNWidgets(7));
    expect(find.text('Thu gọn'), findsOneWidget);

    await tester.tap(find.text('Thu gọn'));
    await tester.pump();
    expect(find.textContaining(RegExp(r'^Ghim số \d$')), findsNWidgets(5));
    await closePage(tester);
  });

  testWidgets('không có ghim → không có hai tiêu đề', (tester) async {
    api.main = [_c('c1', 'Minh Trần')];
    await open(tester);
    expect(find.text('Minh Trần'), findsOneWidget);
    expect(find.text('Đã ghim'), findsNothing);
    expect(find.text('Hội thoại'), findsNothing);
    await closePage(tester);
  });

  testWidgets('mục ghim lỗi → danh sách chính vẫn hiện, không lỗi toàn màn', (
    tester,
  ) async {
    api.main = [_c('c1', 'Minh Trần')];
    api.failPinned = true;
    await open(tester);
    expect(find.text('Minh Trần'), findsOneWidget);
    expect(find.text('Đã ghim'), findsNothing);
    expect(find.byType(OmniErrorView), findsNothing);
    await closePage(tester);
  });

  testWidgets('cả hai rỗng → "Hộp thư trống"; chỉ chính rỗng → không', (
    tester,
  ) async {
    await open(tester);
    expect(find.text('Hộp thư trống'), findsOneWidget);
    await closePage(tester);

    api.pinned = [_c('p1', 'Lan Anh', pinned: true)];
    await open(tester);
    expect(find.text('Hộp thư trống'), findsNothing);
    expect(find.byType(OmniEmptyState), findsNothing);
    expect(find.text('Lan Anh'), findsOneWidget);
    await closePage(tester);
  });

  testWidgets('API cũ bỏ qua pinned (trả cả danh sách) → không nhân đôi dòng', (
    tester,
  ) async {
    // Server cũ không hiểu `pinned`: hai lượt trả cùng danh sách, không có
    // `is_pinned`. Mục ghim phải rỗng, không phải bản sao danh sách chính.
    api.main = [_c('c1', 'Minh Trần')];
    api.ignorePinned = true;
    await open(tester);
    expect(find.text('Minh Trần'), findsOneWidget);
    expect(find.text('Đã ghim'), findsNothing);
    await closePage(tester);
  });

  testWidgets('tab "Đã chặn" → không gọi pinned=1', (tester) async {
    api.pinned = [_c('p1', 'Lan Anh', pinned: true)];
    await open(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(InboxPage)),
    );
    container
        .read(inboxFilterProvider.notifier)
        .setQuick(InboxQuickFilter.blocked);
    api.calls.clear();
    await tester.pump();
    await tester.pump();
    expect(api.calls, isNotEmpty);
    expect(api.calls.where((c) => c.pinned == true), isEmpty);
    expect(find.text('Đã ghim'), findsNothing);
    await closePage(tester);
  });

  testWidgets('360 rộng: tiêu đề không tràn', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    api.main = [_c('c1', 'Minh Trần')];
    api.pinned = [
      for (var i = 1; i <= 6; i++) _c('p$i', 'Ghim số $i', pinned: true),
    ];
    await open(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('Đã ghim'), findsOneWidget);
    await closePage(tester);
  });

  testWidgets('chọn nhiều → "Chọn tất cả" gồm cả mục ghim', (tester) async {
    api.main = [_c('c1', 'Minh Trần')];
    api.pinned = [_c('p1', 'Lan Anh', pinned: true)];
    await open(tester);
    await tester.tap(find.byTooltip('Chọn nhiều'));
    await tester.pump();
    await tester.tap(find.text('Lan Anh'));
    await tester.pump();
    await tester.tap(find.text('Minh Trần'));
    await tester.pump();
    expect(find.text('Đã chọn 2'), findsOneWidget);
    await closePage(tester);
  });
}

Conversation _c(String id, String name, {bool pinned = false}) => Conversation(
  id: id,
  channel: Channel.zalo,
  status: ConversationStatus.open,
  customerName: name,
  lastMessage: 'Tin của $name',
  isPinned: pinned,
);

typedef _Call = ({Map<String, dynamic> query, bool? pinned, int perPage});

class _FakeInboxApi extends InboxApi {
  _FakeInboxApi() : super(ApiClient(Dio()));

  List<Conversation> main = const [];
  List<Conversation> pinned = const [];
  bool failPinned = false;
  bool ignorePinned = false;
  final calls = <_Call>[];

  @override
  Future<CursorPaged<Conversation>> list({
    required Map<String, dynamic> query,
    String? before,
    int perPage = AppConfig.defaultPerPage,
    bool? pinned,
  }) async {
    calls.add((query: query, pinned: pinned, perPage: perPage));
    if (ignorePinned) return CursorPaged(items: main);
    if (pinned == true) {
      if (failPinned) throw const NetworkException('Không có kết nối mạng.');
      return CursorPaged(items: this.pinned);
    }
    return CursorPaged(items: main);
  }

  @override
  Future<InboxFacets> facets(Map<String, dynamic> query) async =>
      const InboxFacets();

  @override
  Future<List<String>> labels() async => const [];

  @override
  Future<InboxChanges> changes(String? after, {String? conversationId}) async =>
      const InboxChanges(cursor: 'cur', count: 0);
}
