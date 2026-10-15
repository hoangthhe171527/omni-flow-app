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
import 'package:omni_app/modules/inbox/data/inbox_api.dart';
import 'package:omni_app/modules/inbox/domain/conversation.dart';
import 'package:omni_app/modules/inbox/domain/inbox_filter.dart';
import 'package:omni_app/modules/inbox/presentation/inbox_page.dart';
import 'package:omni_app/security/permissions/access_policy.dart';
import 'package:omni_app/security/session/session.dart';
import 'package:omni_app/security/session/session_controller.dart';

/// Hộp thư ưu tiên một hàng tìm kiếm thoáng: kết nối kênh và chọn nhiều không
/// còn chen cạnh ô tìm. Các thao tác hội thoại nằm trong menu nhấn giữ.
void main() {
  setUpAll(() => initializeDateFormatting('vi_VN'));

  late _FakeInboxApi api;

  setUp(() => api = _FakeInboxApi());

  Widget host() => ProviderScope(
    overrides: [
      inboxApiProvider.overrideWithValue(api),
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
          policy: AccessPolicy({'inbox.read', 'inbox.write'}),
        ),
      ),
    ],
    child: MaterialApp(
      theme: OmniTheme.light(TargetPlatform.android),
      home: const InboxPage(),
    ),
  );

  /// Gỡ trang TRƯỚC khi bài kiểm kết thúc: poll dự phòng là Timer.periodic.
  Future<void> closePage(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  }

  testWidgets('hàng tìm kiếm không còn kết nối kênh và chọn nhiều', (
    tester,
  ) async {
    api.conversations = [
      _conversation('c1', 'Thuý Phạm'),
      _conversation('c2', 'Minh Trần'),
      _conversation('c3', 'Lan Anh'),
    ];

    await tester.pumpWidget(host());
    await tester.pump();
    await tester.pump();
    expect(find.text('Thuý Phạm'), findsOneWidget);
    expect(find.byTooltip('Kết nối kênh'), findsNothing);
    expect(find.byTooltip('Chọn nhiều'), findsNothing);
    expect(find.bySemanticsLabel('Bộ lọc'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);

    await closePage(tester);
  });

  testWidgets('danh sách hội thoại dùng trọn chiều ngang, không bọc card', (
    tester,
  ) async {
    api.conversations = [
      _conversation('c1', 'Thuý Phạm'),
      _conversation('c2', 'Minh Trần'),
    ];
    await tester.pumpWidget(host());
    await tester.pump();
    await tester.pump();

    final list = find.byKey(const Key('inbox-conversation-list'));
    final rect = tester.getRect(list);
    expect(rect.left, 0);
    expect(
      rect.right,
      tester.view.physicalSize.width / tester.view.devicePixelRatio,
    );

    await closePage(tester);
  });
}

Conversation _conversation(String id, String name) => Conversation(
  id: id,
  channel: Channel.zalo,
  status: ConversationStatus.open,
  customerName: name,
  lastMessage: 'Tin của $name',
  unread: 1,
);

typedef _LabelCall = ({List<String> ids, List<String> labels});

class _FakeInboxApi extends InboxApi {
  _FakeInboxApi() : super(ApiClient(Dio()));

  List<Conversation> conversations = const [];
  int listCalls = 0;
  final labelCalls = <_LabelCall>[];

  @override
  Future<CursorPaged<Conversation>> list({
    required Map<String, dynamic> query,
    String? before,
    int perPage = AppConfig.defaultPerPage,
    bool? pinned,
  }) async {
    // Đếm danh sách CHÍNH; mục "Đã ghim" (pinned=1) tải theo nhịp riêng.
    if (pinned != true) listCalls++;
    return CursorPaged(items: conversations);
  }

  @override
  Future<InboxFacets> facets(Map<String, dynamic> query) async =>
      const InboxFacets();

  @override
  Future<List<String>> labels() async => const [];

  @override
  Future<InboxChanges> changes(String? after, {String? conversationId}) async =>
      const InboxChanges(cursor: 'cur', count: 0);

  @override
  Future<int> setLabels(
    List<String> conversationIds,
    List<String> labels, {
    String mode = 'add',
  }) async {
    labelCalls.add((ids: List.of(conversationIds), labels: List.of(labels)));
    return conversationIds.length;
  }
}
