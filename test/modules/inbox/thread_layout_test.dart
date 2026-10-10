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
import 'package:omni_app/modules/customers/application/customers_providers.dart';
import 'package:omni_app/modules/customers/domain/customer.dart';
import 'package:omni_app/modules/inbox/data/inbox_api.dart';
import 'package:omni_app/modules/inbox/domain/conversation.dart';
import 'package:omni_app/modules/inbox/domain/inbox_filter.dart';
import 'package:omni_app/modules/inbox/domain/message.dart';
import 'package:omni_app/modules/inbox/presentation/thread_page.dart';
import 'package:omni_app/modules/inbox/presentation/widgets/message_bubble.dart';
import 'package:omni_app/modules/inbox/presentation/widgets/thread_intro.dart';
import 'package:omni_app/modules/settings/application/appearance_providers.dart';
import 'package:omni_app/security/permissions/access_policy.dart';
import 'package:omni_app/security/session/session.dart';
import 'package:omni_app/security/session/session_controller.dart';

import '../../support/fixed_background.dart';

/// Bố cục hội thoại GĐ3: header gọn, khối giới thiệu, mốc giờ, ẩn ghi chú.
void main() {
  setUpAll(() => initializeDateFormatting('vi_VN'));

  late _FakeInboxApi api;

  setUp(() => api = _FakeInboxApi());

  Widget host({
    List<Override> overrides = const [],
    Set<String> extra = const {'tasks.write'},
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
          policy: AccessPolicy({
            'inbox.read',
            'inbox.write',
            'inbox.convert',
            ...extra,
          }),
        ),
      ),
      backgroundProvider.overrideWith(FixedBackground.new),
      ...overrides,
    ],
    child: MaterialApp(
      theme: OmniTheme.light(TargetPlatform.android),
      home: const ThreadPage(conversationId: 'c1'),
    ),
  );

  Future<void> openThread(
    WidgetTester tester, {
    List<Override> overrides = const [],
    Set<String> extra = const {'tasks.write'},
  }) async {
    await tester.pumpWidget(host(overrides: overrides, extra: extra));
    await tester.pump();
    await tester.pump();
  }

  Future<void> closeThread(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  }

  testWidgets('header gọn: tên + "OA Trung Nguyên" + nút Thông tin khách', (
    tester,
  ) async {
    api.history = [_serverMessage('m1', 'Chào shop')];
    await openThread(tester);
    expect(find.text('Thuý Phạm'), findsWidgets);
    expect(find.text('OA Trung Nguyên'), findsOneWidget);
    expect(find.byTooltip('Thông tin khách'), findsOneWidget);
    await closeThread(tester);
  });

  testWidgets('khối giới thiệu: chưa gắn khách → Chuyển KH, không "Khách từ"', (
    tester,
  ) async {
    api.history = [_serverMessage('m1', 'Chào shop')];
    await openThread(tester);
    expect(find.byType(ThreadIntro), findsOneWidget);
    expect(find.text('Chuyển KH'), findsOneWidget);
    expect(find.textContaining('Khách từ'), findsNothing);
    expect(find.text('Việc'), findsOneWidget);
    await closeThread(tester);
  });

  testWidgets('đã gắn khách: Hồ sơ + "Khách từ dd/MM · 3,6 tr"', (
    tester,
  ) async {
    api.customerId = 'cu1';
    api.history = [_serverMessage('m1', 'Chào shop')];
    await openThread(
      tester,
      extra: const {'tasks.write', 'crm.customers.read'},
      overrides: [
        customerProvider('cu1').overrideWith(
          (ref) async => Customer(
            id: 'cu1',
            name: 'Thuý Phạm',
            lifetimeValue: 3600000,
            createdAt: DateTime.utc(2026, 3, 14, 5),
          ),
        ),
      ],
    );
    expect(find.text('Hồ sơ'), findsOneWidget);
    expect(find.text('Chuyển KH'), findsNothing);
    expect(find.text('Khách từ 14/03 · 3,6 tr'), findsOneWidget);
    await closeThread(tester);
  });

  testWidgets('không có quyền tạo việc: không có nút Việc', (tester) async {
    api.history = [_serverMessage('m1', 'Chào shop')];
    await openThread(tester, extra: const {});
    expect(find.byType(ThreadIntro), findsOneWidget);
    expect(find.text('Việc'), findsNothing);
    await closeThread(tester);
  });

  testWidgets('đã gắn khách nhưng không có quyền xem khách: không có Hồ sơ', (
    tester,
  ) async {
    api.customerId = 'cu1';
    api.history = [_serverMessage('m1', 'Chào shop')];
    await openThread(tester, overrides: [_customerOverride]);
    expect(find.text('Hồ sơ'), findsNothing);
    expect(find.text('Chuyển KH'), findsNothing);
    await closeThread(tester);
  });

  testWidgets('có quyền xem khách: có Hồ sơ', (tester) async {
    api.customerId = 'cu1';
    api.history = [_serverMessage('m1', 'Chào shop')];
    await openThread(
      tester,
      overrides: [_customerOverride],
      extra: const {'tasks.write', 'crm.customers.read'},
    );
    expect(find.text('Hồ sơ'), findsOneWidget);
    await closeThread(tester);
  });

  testWidgets('quyền tạo cơ hội quyết định nút Cơ hội', (tester) async {
    api.history = [_serverMessage('m1', 'Chào shop')];
    await openThread(tester);
    expect(find.text('Cơ hội'), findsNothing);
    await closeThread(tester);
    await openThread(
      tester,
      extra: const {'tasks.write', 'crm.sales_opportunities.create'},
    );
    expect(find.text('Cơ hội'), findsOneWidget);
    await closeThread(tester);
  });

  testWidgets('nhóm chat: không có khối giới thiệu', (tester) async {
    api.isGroup = true;
    api.history = [_serverMessage('m1', 'Chào cả nhà')];
    await openThread(tester);
    expect(find.byType(ThreadIntro), findsNothing);
    expect(find.text('Chuyển KH'), findsNothing);
    expect(find.text('Hồ sơ'), findsNothing);
    await closeThread(tester);
  });

  testWidgets('ghi chú nội bộ không hiện; hai tin quanh nó vẫn liền nhau', (
    tester,
  ) async {
    api.history = [
      _serverMessage('m1', 'Một'),
      _serverNote('n2', 'Khách VIP'),
      _serverMessage('m3', 'Hai'),
    ];
    await openThread(tester);
    expect(find.text('Khách VIP'), findsNothing);
    final second = tester.widget<MessageBubble>(
      find.ancestor(of: find.text('Hai'), matching: find.byType(MessageBubble)),
    );
    expect(second.groupedWithPrevious, isTrue);
    await closeThread(tester);
  });

  testWidgets('mốc giờ kiểu 09:40, HÔM NAY', (tester) async {
    api.history = [_serverMessage('m1', 'Chào shop', sentAt: DateTime.now())];
    await openThread(tester);
    expect(find.textContaining(', HÔM NAY'), findsOneWidget);
    await closeThread(tester);
  });

  testWidgets('không còn nút gạt ghi chú và hàng trả lời nhanh', (
    tester,
  ) async {
    api.history = [_serverMessage('m1', 'Chào shop')];
    await openThread(tester);
    expect(find.text('Ghi chú nội bộ'), findsNothing);
    expect(find.byType(ActionChip), findsNothing);
    await closeThread(tester);
  });

  testWidgets('bong bóng 18/4: đầu, giữa và cuối nhóm tin ra', (tester) async {
    api.history = [
      _serverMessage('m1', 'AAA', from: 'agent'),
      _serverMessage('m2', 'BBB', from: 'agent'),
      _serverMessage('m3', 'CCC', from: 'agent'),
    ];
    await openThread(tester);

    BorderRadius radius(String text) {
      final box = tester.widget<DecoratedBox>(
        find
            .ancestor(of: find.text(text), matching: find.byType(DecoratedBox))
            .first,
      );
      return (box.decoration as BoxDecoration).borderRadius! as BorderRadius;
    }

    // Danh sách vẽ ngược nhưng nhóm tính theo thời gian: m1 đầu nhóm.
    expect(radius('AAA').topRight.x, 18);
    expect(radius('AAA').bottomRight.x, 4);
    expect(radius('BBB').topRight.x, 4);
    expect(radius('BBB').bottomRight.x, 4);
    expect(radius('CCC').topRight.x, 4);
    expect(radius('CCC').bottomRight.x, 18);
    expect(radius('CCC').topLeft.x, 18);
    await closeThread(tester);
  });
}

Message _serverMessage(
  String id,
  String text, {
  String from = 'customer',
  DateTime? sentAt,
}) {
  final minute = int.parse(id.replaceAll(RegExp(r'\D'), ''));
  return Message.fromJson({
    'id': id,
    'from': from,
    'text': text,
    'status': from == 'agent' ? 'sent' : null,
    'sent_at': (sentAt ?? DateTime.utc(2026, 1, 1, 8, minute))
        .toUtc()
        .toIso8601String(),
  });
}

Message _serverNote(String id, String text) {
  final minute = int.parse(id.replaceAll(RegExp(r'\D'), ''));
  return Message.fromJson({
    'id': id,
    'from': 'note',
    'text': text,
    'sent_at': DateTime.utc(2026, 1, 1, 8, minute).toIso8601String(),
  });
}

class _FakeInboxApi extends InboxApi {
  _FakeInboxApi() : super(ApiClient(Dio()));

  List<Message> history = const [];
  bool isGroup = false;
  String? customerId;

  @override
  Future<MessagePage> messages(
    String id, {
    String? before,
    int perPage = AppConfig.messagePageSize,
  }) async => MessagePage(
    messages: history.reversed.toList(),
    cursor: const CursorPage.empty(),
  );

  @override
  Future<Conversation> get(String id) async => Conversation(
    id: id,
    channel: Channel.zalo,
    status: ConversationStatus.open,
    customerId: customerId,
    customerName: 'Thuý Phạm',
    sourceName: 'Zalo OA · Trung Nguyên',
    isGroup: isGroup,
    groupName: isGroup ? 'Nhóm thợ' : null,
    lastMessage: 'Còn đàn không',
    unread: 0,
  );

  @override
  Future<void> markRead(String id) async {}

  @override
  Future<InboxChanges> changes(String? after, {String? conversationId}) async =>
      const InboxChanges(cursor: 'cur', count: 0);

  @override
  Future<InboxFacets> facets(Map<String, dynamic> query) async =>
      const InboxFacets();

  @override
  Future<CursorPaged<Conversation>> list({
    required Map<String, dynamic> query,
    String? before,
    int perPage = AppConfig.defaultPerPage,
    bool? pinned,
  }) async => const CursorPaged.empty();
}

final _customerOverride = customerProvider(
  'cu1',
).overrideWith((ref) async => Customer(id: 'cu1', name: 'Thuý Phạm'));
