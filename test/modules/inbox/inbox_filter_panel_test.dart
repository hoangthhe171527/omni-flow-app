import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:omni_app/core/config/app_config.dart';
import 'package:omni_app/core/domain/channel.dart';
import 'package:omni_app/core/network/api_client.dart';
import 'package:omni_app/core/network/api_envelope.dart';
import 'package:omni_app/core/realtime/realtime_client.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/design/tokens/tokens.dart';
import 'package:omni_app/modules/inbox/application/inbox_providers.dart';
import 'package:omni_app/modules/inbox/data/inbox_api.dart';
import 'package:omni_app/modules/inbox/presentation/widgets/inbox_filter_bar.dart';
import 'package:omni_app/modules/inbox/domain/conversation.dart';
import 'package:omni_app/modules/inbox/domain/inbox_filter.dart';
import 'package:omni_app/modules/inbox/presentation/inbox_page.dart';
import 'package:omni_app/security/permissions/access_policy.dart';
import 'package:omni_app/security/session/session.dart';
import 'package:omni_app/security/session/session_controller.dart';

/// Bộ lọc gom trong nút: đóng sẵn, bấm nút thì trượt xuống, số trên nút đếm
/// số bộ lọc đang bật, và quyền `inbox.read.own` không thấy mục theo người gán.
void main() {
  setUpAll(() => initializeDateFormatting('vi_VN'));

  late _FakeInboxApi api;

  setUp(() => api = _FakeInboxApi());

  Widget host({
    Set<String> permissions = const {'inbox.read', 'inbox.write'},
    bool reduceMotion = false,
    bool dark = false,
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
      theme: dark
          ? OmniTheme.dark(TargetPlatform.android)
          : OmniTheme.light(TargetPlatform.android),
      builder: reduceMotion
          ? (c, child) => MediaQuery(
              data: MediaQuery.of(c).copyWith(disableAnimations: true),
              child: child!,
            )
          : null,
      home: const InboxPage(),
    ),
  );

  /// Gỡ trang TRƯỚC khi bài kiểm kết thúc: poll dự phòng là Timer.
  Future<void> closePage(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  }

  testWidgets('bộ lọc đóng sẵn; bấm nút → hiện 4 đoạn; chọn Chưa đọc → số 1', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(host());
    await tester.pump();
    await tester.pump();

    expect(find.text('Của tôi'), findsNothing);
    expect(find.byKey(const Key('inbox-filter-count')), findsNothing);
    expect(find.textContaining('hội thoại · Mới nhất'), findsNothing);

    await tester.tap(find.bySemanticsLabel('Bộ lọc'));
    await tester.pumpAndSettle(const Duration(milliseconds: 50));
    expect(find.text('Của tôi'), findsOneWidget);
    expect(find.text('Chưa gán'), findsOneWidget);

    await tester.tap(find.textContaining('Chưa đọc'));
    await tester.pump();
    final badge = find.byKey(const Key('inbox-filter-count'));
    expect(
      find.descendant(of: badge, matching: find.text('1')),
      findsOneWidget,
    );
    expect(api.lastListQuery['unread'], 1);

    await closePage(tester);
    semantics.dispose();
  });

  testWidgets('chỉ inbox.read.own: không có Của tôi / Chưa gán', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(host(permissions: const {'inbox.read.own'}));
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Bộ lọc'));
    await tester.pumpAndSettle(const Duration(milliseconds: 50));
    expect(find.text('Của tôi'), findsNothing);
    expect(find.text('Chưa gán'), findsNothing);
    await closePage(tester);
    semantics.dispose();
  });
  testWidgets('giảm chuyển động: panel mở xong ngay sau một pump', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(host(reduceMotion: true));
    await tester.pump();
    await tester.pump(); // danh sách tải xong, vòng chờ không còn quay
    await tester.tap(find.bySemanticsLabel('Bộ lọc'));
    await tester.pump();
    expect(tester.hasRunningAnimations, isFalse);
    expect(find.text('Chưa gán'), findsOneWidget);
    await closePage(tester);
    semantics.dispose();
  });

  ProviderContainer containerOf(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(InboxPage)));

  // Số trên nút đếm cả tài khoản kênh và nhãn; panel phải xoá được mọi thứ
  // nó đếm, không thì huy hiệu kẹt mãi một con số không gỡ được.
  testWidgets('Xoá bộ lọc trong panel đưa mọi mục được đếm về mặc định', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(host(reduceMotion: true));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Bộ lọc'));
    await tester.pump();
    final clear = find.byKey(const Key('inbox-filter-clear'));
    expect(clear, findsNothing, reason: 'chưa bật bộ lọc nào');

    final container = containerOf(tester);
    container.read(inboxFilterProvider.notifier)
      ..setQuick(InboxQuickFilter.urgent)
      ..setChannel(Channel.zalo)
      ..setConnection('conn-1')
      ..setLabel('vip')
      ..setSearch('lan');
    await tester.pump();
    expect(container.read(inboxFilterProvider).activeCount, 4);

    await tester.tap(clear);
    await tester.pump();
    final filter = container.read(inboxFilterProvider);
    expect(filter.activeCount, 0);
    expect(filter, const InboxFilter(search: 'lan'), reason: 'giữ ô tìm');
    expect(find.byKey(const Key('inbox-filter-count')), findsNothing);
    expect(clear, findsNothing);

    await closePage(tester);
    semantics.dispose();
  });

  // Gõ rồi bấm "Xoá bộ lọc" (đặt lại từ ngoài) trước khi hết 300ms: hẹn giờ
  // cũ không được đặt lại chữ vừa bị xoá.
  testWidgets('đặt lại từ ngoài huỷ lượt tìm đang chờ', (tester) async {
    await tester.pumpWidget(host(reduceMotion: true));
    await tester.pump();
    await tester.pump();

    final field = find.descendant(
      of: find.byType(InboxSearchRow),
      matching: find.byType(TextField),
    );
    await tester.enterText(field, 'lan');
    await tester.pump(const Duration(milliseconds: 100));
    containerOf(tester).read(inboxFilterProvider.notifier).reset();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(containerOf(tester).read(inboxFilterProvider).search, '');
    expect(tester.widget<TextField>(field).controller!.text, '');

    await closePage(tester);
  });

  /// Hàng tìm + panel mở dựng trần, không qua InboxPage: chỉ soi màu của
  /// chính thanh lọc.
  Widget barHost(ThemeData theme) => ProviderScope(
    overrides: [
      inboxApiProvider.overrideWithValue(api),
      sessionProvider.overrideWithValue(
        Session(
          status: SessionStatus.authenticated,
          user: const SessionUser(id: 'u1', fullName: 'Kiệt', email: 'k@x.vn'),
          tenant: const SessionTenant(id: 't1', name: 'Xưởng đàn'),
          policy: AccessPolicy(const {'inbox.read', 'inbox.write'}),
        ),
      ),
    ],
    child: MaterialApp(
      theme: theme,
      home: Scaffold(
        body: Column(
          children: [
            InboxSearchRow(filtersOpen: false, onToggleFilters: () {}),
            const InboxFilterPanel(open: true),
          ],
        ),
      ),
    ),
  );

  /// Mọi màu nền / viền / bóng mà thanh lọc tự vẽ.
  List<Color> surfaceColors(WidgetTester tester, {Finder? within}) {
    final roots =
        within ??
        find.byWidgetPredicate(
          (w) => w is InboxSearchRow || w is InboxFilterPanel,
        );
    final colors = <Color>[];
    void decoration(Decoration? d) {
      if (d is! BoxDecoration) return;
      if (d.color != null) colors.add(d.color!);
      for (final shadow in d.boxShadow ?? const <BoxShadow>[]) {
        colors.add(shadow.color);
      }
      final border = d.border;
      if (border is Border) {
        for (final side in [
          border.top,
          border.right,
          border.bottom,
          border.left,
        ]) {
          if (side.style != BorderStyle.none) colors.add(side.color);
        }
      }
    }

    for (final w in tester.widgetList<Container>(
      find.descendant(of: roots, matching: find.byType(Container)),
    )) {
      decoration(w.decoration);
    }
    for (final w in tester.widgetList<DecoratedBox>(
      find.descendant(of: roots, matching: find.byType(DecoratedBox)),
    )) {
      decoration(w.decoration);
    }
    for (final m in tester.widgetList<Material>(
      find.descendant(of: roots, matching: find.byType(Material)),
    )) {
      if (m.color != null) colors.add(m.color!);
      final shape = m.shape;
      if (shape is RoundedRectangleBorder) colors.add(shape.side.color);
    }
    return colors;
  }

  testWidgets('giao diện tối: hàng tìm và panel mở không có nền trắng', (
    tester,
  ) async {
    await tester.pumpWidget(barHost(OmniTheme.dark(TargetPlatform.android)));
    await tester.pumpAndSettle();
    // Bật một bộ lọc để huy hiệu đếm (viền) và chip được chọn cùng hiện.
    ProviderScope.containerOf(
      tester.element(find.byType(InboxSearchRow)),
    ).read(inboxFilterProvider.notifier).setQuick(InboxQuickFilter.urgent);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('inbox-filter-count')), findsOneWidget);

    final colors = surfaceColors(tester);
    expect(colors, isNotEmpty);
    expect(
      colors.where((c) => c.toARGB32() == 0xFFFFFFFF),
      isEmpty,
      reason: 'nền/viền trắng tinh lọt vào giao diện tối',
    );
    expect(colors, isNot(contains(OmniColors.border)));
    expect(colors, isNot(contains(OmniColors.muted)));
    expect(colors, isNot(contains(OmniColors.accent)));
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.style!.color, OmniColors.darkForeground);
  });

  testWidgets('giao diện tối: thẻ danh sách của InboxPage không trắng', (
    tester,
  ) async {
    await tester.pumpWidget(host(dark: true, reduceMotion: true));
    await tester.pump();
    await tester.pump();
    final colors = surfaceColors(tester, within: find.byType(InboxPage));
    expect(colors, isNotEmpty);
    expect(
      colors.where((c) => c.toARGB32() == 0xFFFFFFFF),
      isEmpty,
      reason: 'nền trắng tinh lọt vào giao diện tối',
    );
    expect(colors, isNot(contains(OmniColors.border)));
    expect(colors, contains(OmniColors.darkCard));
    expect(colors, contains(OmniColors.darkBorder));
    await closePage(tester);
  });

  testWidgets('giao diện sáng giữ nguyên màu cũ', (tester) async {
    await tester.pumpWidget(barHost(OmniTheme.light(TargetPlatform.android)));
    await tester.pumpAndSettle();
    ProviderScope.containerOf(
      tester.element(find.byType(InboxSearchRow)),
    ).read(inboxFilterProvider.notifier).setQuick(InboxQuickFilter.urgent);
    await tester.pumpAndSettle();
    final colors = surfaceColors(tester);
    expect(colors, contains(Colors.white));
    expect(colors, contains(OmniColors.border));
    expect(colors, contains(OmniColors.muted));
    expect(colors, contains(OmniColors.accent));
    expect(colors, contains(OmniColors.primary));
    expect(colors, contains(OmniColors.destructive));
    expect(colors, contains(const Color(0x1F0B1A33)));
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.style!.color, OmniColors.ink);
  });
}

class _FakeInboxApi extends InboxApi {
  _FakeInboxApi() : super(ApiClient(Dio()));

  Map<String, dynamic> lastListQuery = const {};

  @override
  Future<CursorPaged<Conversation>> list({
    required Map<String, dynamic> query,
    String? before,
    int perPage = AppConfig.defaultPerPage,
    bool? pinned,
  }) async {
    lastListQuery = query;
    return const CursorPaged(items: []);
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
