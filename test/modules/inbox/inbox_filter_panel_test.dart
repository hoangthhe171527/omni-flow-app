import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:omni_app/core/config/app_config.dart';
import 'package:omni_app/core/network/api_client.dart';
import 'package:omni_app/core/network/api_envelope.dart';
import 'package:omni_app/core/realtime/realtime_client.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/modules/inbox/data/inbox_api.dart';
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
}

class _FakeInboxApi extends InboxApi {
  _FakeInboxApi() : super(ApiClient(Dio()));

  Map<String, dynamic> lastListQuery = const {};

  @override
  Future<CursorPaged<Conversation>> list({
    required Map<String, dynamic> query,
    String? before,
    int perPage = AppConfig.defaultPerPage,
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
