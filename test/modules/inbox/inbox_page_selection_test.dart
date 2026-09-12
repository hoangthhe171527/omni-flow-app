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

/// Chế độ chọn nhiều của hộp thư: chọn hai hội thoại, gắn nhãn → API nhận
/// đúng hai id đó, một lượt.
///
/// Kế hoạch gốc nói "đánh dấu đã đọc", nhưng thanh thao tác hàng loạt chỉ có
/// Gán và Gắn nhãn; ý đồ — thao tác hàng loạt gửi đúng id đã chọn — kiểm qua
/// gắn nhãn.
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

  testWidgets('chọn 2 hội thoại, gắn nhãn → API nhận đúng 2 id', (
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
    expect(find.text('Đã chọn 1'), findsNothing);

    // Giữ một hàng là vào chế độ chọn với hàng đó đã chọn.
    await tester.longPress(find.text('Thuý Phạm'));
    await tester.pump();
    expect(find.text('Đã chọn 1'), findsOneWidget);

    // Đang chọn thì chạm là chọn thêm, không mở hội thoại.
    await tester.tap(find.text('Minh Trần'));
    await tester.pump();
    expect(find.text('Đã chọn 2'), findsOneWidget);

    await tester.tap(find.text('Gắn nhãn'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      'VIP',
    );
    await tester.tap(find.text('Áp dụng'));
    await tester.pumpAndSettle();

    expect(api.labelCalls, hasLength(1));
    expect(api.labelCalls.single.ids, ['c1', 'c2']);
    expect(api.labelCalls.single.labels, ['VIP']);
    expect(find.text('Đã gắn nhãn cho 2 hội thoại.'), findsOneWidget);
    expect(
      find.text('Đã chọn 2'),
      findsNothing,
      reason: 'Xong việc thì thoát chế độ chọn.',
    );
    expect(
      api.listCalls,
      2,
      reason: 'Tải lại danh sách sau khi gắn nhãn để nhãn hiện lên hàng.',
    );

    await closePage(tester);
  });

  testWidgets('bỏ chọn một hàng đã chọn thì số đếm giảm', (tester) async {
    api.conversations = [
      _conversation('c1', 'Thuý Phạm'),
      _conversation('c2', 'Minh Trần'),
    ];
    await tester.pumpWidget(host());
    await tester.pump();
    await tester.pump();

    await tester.longPress(find.text('Thuý Phạm'));
    await tester.pump();
    await tester.tap(find.text('Minh Trần'));
    await tester.pump();
    expect(find.text('Đã chọn 2'), findsOneWidget);

    await tester.tap(find.text('Thuý Phạm'));
    await tester.pump();
    expect(find.text('Đã chọn 1'), findsOneWidget);

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
  Future<Paged<Conversation>> list({
    required Map<String, dynamic> query,
    int page = 1,
    int perPage = AppConfig.defaultPerPage,
  }) async {
    listCalls++;
    return Paged(items: conversations, pagination: const ApiPagination.empty());
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
