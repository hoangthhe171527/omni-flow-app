import 'dart:async';

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
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/design/tokens/tokens.dart';
import 'package:omni_app/modules/inbox/data/inbox_api.dart';
import 'package:omni_app/modules/inbox/domain/conversation.dart';
import 'package:omni_app/modules/inbox/domain/inbox_filter.dart';
import 'package:omni_app/modules/inbox/domain/inbox_permissions.dart';
import 'package:omni_app/modules/inbox/domain/message.dart';
import 'package:omni_app/modules/inbox/presentation/inbox_page.dart';
import 'package:omni_app/modules/inbox/presentation/widgets/conversation_actions.dart';
import 'package:omni_app/modules/inbox/presentation/widgets/conversation_peek.dart';
import 'package:omni_app/modules/inbox/presentation/widgets/conversation_row.dart';
import 'package:omni_app/security/permissions/access_policy.dart';
import 'package:omni_app/security/session/session.dart';
import 'package:omni_app/security/session/session_controller.dart';

/// Bấm giữ một dòng → xem trước 4 tin gần nhất + menu thao tác theo quyền.
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

  Future<void> open(
    WidgetTester tester, {
    Set<String> permissions = const {'inbox.read', 'inbox.write'},
    bool reduceMotion = false,
    bool dark = false,
  }) async {
    await tester.pumpWidget(
      host(permissions: permissions, reduceMotion: reduceMotion, dark: dark),
    );
    await tester.pump();
    await tester.pump();
  }

  /// Gỡ trang TRƯỚC khi bài kiểm kết thúc: poll dự phòng là Timer.
  Future<void> closePage(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  }

  Future<void> holdRow(WidgetTester tester, String name) async {
    final g = await tester.startGesture(tester.getCenter(find.text(name)));
    await tester.pump(
      ConversationRow.peekDelay + const Duration(milliseconds: 10),
    );
    await g.up();
    await tester.pumpAndSettle(const Duration(milliseconds: 50));
  }

  testWidgets('giữ dòng → xem trước tin gần nhất + menu đủ quyền', (
    tester,
  ) async {
    api.conversations = [_conversation('c1', 'Lan Anh', unread: 2)];
    await open(tester);
    await holdRow(tester, 'Lan Anh');

    expect(find.text('Dạ em chào chị'), findsOneWidget);
    expect(find.text('Đánh dấu đã đọc'), findsOneWidget);
    expect(find.text('Gán cho…'), findsOneWidget);
    expect(find.text('Thêm nhãn'), findsOneWidget);
    expect(find.text('Lưu trữ'), findsOneWidget);
    expect(find.text('Tắt thông báo'), findsNothing, reason: 'API chưa có');
    expect(find.text('Đánh dấu chưa đọc'), findsNothing, reason: 'API chưa có');
    await closePage(tester);
  });

  Color labelColor(WidgetTester tester, String label) =>
      tester.widget<Text>(find.text(label)).style!.color!;

  testWidgets('mục huỷ (Lưu trữ): đỏ đậm khi sáng, dangerTextDark khi tối', (
    tester,
  ) async {
    api.conversations = [_conversation('c1', 'Lan Anh', unread: 2)];
    await open(tester);
    await holdRow(tester, 'Lan Anh');
    expect(labelColor(tester, 'Lưu trữ'), const Color(0xFFB42318));
    await closePage(tester);

    await open(tester, dark: true);
    await holdRow(tester, 'Lan Anh');
    expect(labelColor(tester, 'Lưu trữ'), OmniColors.dangerTextDark);
    await closePage(tester);
  });

  testWidgets('chỉ inbox.read: xem trước có, menu không có mục ghi', (
    tester,
  ) async {
    api.conversations = [_conversation('c1', 'Lan Anh', unread: 2)];
    await open(tester, permissions: const {'inbox.read'});
    await holdRow(tester, 'Lan Anh');
    expect(find.text('Dạ em chào chị'), findsOneWidget);
    for (final l in ['Đánh dấu đã đọc', 'Gán cho…', 'Thêm nhãn', 'Lưu trữ']) {
      expect(find.text(l), findsNothing);
    }
    await closePage(tester);
  });

  testWidgets('Lưu trữ → PUT closed, dòng rời tab Tất cả ngay', (tester) async {
    api.conversations = [
      _conversation('c1', 'Lan Anh'),
      _conversation('c2', 'Minh Tú'),
    ];
    await open(tester);
    await holdRow(tester, 'Lan Anh');
    await tester.tap(find.text('Lưu trữ'));
    await tester.pumpAndSettle(const Duration(milliseconds: 50));

    expect(api.statusCalls, [('c1', ConversationStatus.closed)]);
    expect(find.text('Lan Anh'), findsNothing);
    expect(find.text('Minh Tú'), findsOneWidget);
    expect(find.text('Đã lưu trữ hội thoại.'), findsOneWidget);
    await closePage(tester);
  });

  testWidgets('Lưu trữ lỗi → dòng giữ nguyên, báo lỗi', (tester) async {
    api.conversations = [_conversation('c1', 'Lan Anh')];
    api.failNextStatus = true;
    await open(tester);
    await holdRow(tester, 'Lan Anh');
    await tester.tap(find.text('Lưu trữ'));
    await tester.pumpAndSettle(const Duration(milliseconds: 50));
    expect(find.text('Lan Anh'), findsOneWidget);
    expect(find.text('Máy chủ bận'), findsOneWidget);
    await closePage(tester);
  });

  testWidgets('Đánh dấu đã đọc → POST read, số chưa đọc biến mất', (
    tester,
  ) async {
    api.conversations = [_conversation('c1', 'Lan Anh', unread: 2)];
    await open(tester);
    await holdRow(tester, 'Lan Anh');
    await tester.tap(find.text('Đánh dấu đã đọc'));
    await tester.pumpAndSettle(const Duration(milliseconds: 50));
    expect(api.markReadCalls, ['c1']);
    expect(find.text('2'), findsNothing);
    await closePage(tester);
  });

  testWidgets('giảm chuyển động: xem trước hiện ngay sau một pump', (
    tester,
  ) async {
    api.conversations = [_conversation('c1', 'Lan Anh')];
    await open(tester, reduceMotion: true);
    final g = await tester.startGesture(tester.getCenter(find.text('Lan Anh')));
    await tester.pump(
      ConversationRow.peekDelay + const Duration(milliseconds: 10),
    );
    await g.up();
    await tester.pump();
    expect(find.text('Lưu trữ'), findsOneWidget);
    await closePage(tester);
  });

  testWidgets('bấm ra ngoài (nền mờ) đóng xem trước', (tester) async {
    api.conversations = [_conversation('c1', 'Lan Anh')];
    await open(tester);
    await holdRow(tester, 'Lan Anh');
    expect(find.text('Lưu trữ'), findsOneWidget);
    await tester.tapAt(const Offset(200, 580));
    await tester.pumpAndSettle(const Duration(milliseconds: 50));
    expect(find.text('Lưu trữ'), findsNothing);
    expect(api.statusCalls, isEmpty);
    await closePage(tester);
  });

  testWidgets('bấm khung xem trước → đóng và gọi onOpen', (tester) async {
    final opened = <String>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          inboxApiProvider.overrideWithValue(api),
          sessionProvider.overrideWithValue(
            const Session(
              status: SessionStatus.authenticated,
              user: SessionUser(id: 'u1', fullName: 'K', email: 'k@x.vn'),
              tenant: SessionTenant(id: 't1', name: 'X'),
              policy: AccessPolicy({'inbox.read', 'inbox.write'}),
            ),
          ),
        ],
        child: MaterialApp(
          theme: OmniTheme.light(TargetPlatform.android),
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => showConversationPeek(
                context: context,
                conversation: _conversation('c1', 'Lan Anh'),
                onOpen: () => opened.add('c1'),
                onAction: (_) {},
              ),
              child: const Text('mở'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('mở'));
    await tester.pumpAndSettle(const Duration(milliseconds: 50));
    await tester.tap(find.text('Dạ em chào chị'));
    await tester.pumpAndSettle(const Duration(milliseconds: 50));
    expect(opened, ['c1']);
    expect(find.text('Dạ em chào chị'), findsNothing);
  });

  testWidgets('tải tin lỗi → "Không tải được tin." mà menu vẫn dùng được', (
    tester,
  ) async {
    api.conversations = [_conversation('c1', 'Lan Anh')];
    api.failMessages = true;
    await open(tester);
    await holdRow(tester, 'Lan Anh');
    expect(find.text('Không tải được tin.'), findsOneWidget);
    await tester.tap(find.text('Lưu trữ'));
    await tester.pumpAndSettle(const Duration(milliseconds: 50));
    expect(api.statusCalls, [('c1', ConversationStatus.closed)]);
    await closePage(tester);
  });

  testWidgets('tải tin lỗi → Thử lại tải lại tin, không mở hội thoại', (
    tester,
  ) async {
    api.conversations = [_conversation('c1', 'Lan Anh')];
    api.failMessages = true;
    await open(tester);
    await holdRow(tester, 'Lan Anh');
    expect(find.text('Không tải được tin.'), findsOneWidget);

    api.failMessages = false;
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle(const Duration(milliseconds: 50));
    expect(find.text('Không tải được tin.'), findsNothing);
    expect(find.text('Dạ em chào chị'), findsOneWidget);
    await closePage(tester);
  });

  testWidgets('Mở lại trên hội thoại đã đóng → setStatus(open)', (
    tester,
  ) async {
    api.conversations = [
      _conversation('c1', 'Lan Anh', status: ConversationStatus.closed),
    ];
    await open(tester);
    await holdRow(tester, 'Lan Anh');
    expect(find.text('Lưu trữ'), findsNothing);
    await tester.tap(find.text('Mở lại'));
    await tester.pumpAndSettle(const Duration(milliseconds: 50));
    expect(api.statusCalls, [('c1', ConversationStatus.open)]);
    expect(find.text('Đã mở lại hội thoại.'), findsOneWidget);
    await closePage(tester);
  });

  testWidgets('thao tác xong SAU khi trang đã gỡ → không ném lỗi', (
    tester,
  ) async {
    api.conversations = [_conversation('c1', 'Lan Anh', unread: 2)];
    api.markReadGate = Completer<void>();
    await open(tester);
    await holdRow(tester, 'Lan Anh');
    await tester.tap(find.text('Đánh dấu đã đọc'));
    await tester.pump();
    await closePage(tester); // trang + ProviderScope bị gỡ khi API còn chờ
    api.markReadGate!.complete();
    await tester.pump(const Duration(milliseconds: 50));
    expect(tester.takeException(), isNull);
    expect(api.markReadCalls, ['c1']);
  });

  group('peekMenuFor', () {
    final full = InboxAccess.of(
      const AccessPolicy({'inbox.read', 'inbox.write'}),
    );

    test('hội thoại đã đóng → Mở lại thay vì Lưu trữ', () {
      final c = _conversation('c1', 'A', status: ConversationStatus.closed);
      final actions = peekMenuFor(c, full).map((i) => i.action).toList();
      expect(actions, contains(PeekAction.reopen));
      expect(actions, isNot(contains(PeekAction.archive)));
      expect(actions, isNot(contains(PeekAction.markRead)));
    });

    test('chỉ Lưu trữ mới là mục đỏ', () {
      final c = _conversation('c1', 'A', unread: 1);
      final items = peekMenuFor(c, full);
      expect(items.where((i) => i.destructive).map((i) => i.action), [
        PeekAction.archive,
      ]);
    });
  });
}

Conversation _conversation(
  String id,
  String name, {
  int unread = 0,
  ConversationStatus status = ConversationStatus.open,
}) => Conversation(
  id: id,
  channel: Channel.zalo,
  status: status,
  customerName: name,
  lastMessage: 'Tin của $name',
  unread: unread,
);

class _FakeInboxApi extends InboxApi {
  _FakeInboxApi() : super(ApiClient(Dio()));

  List<Conversation> conversations = const [];
  final markReadCalls = <String>[];
  final statusCalls = <(String, ConversationStatus)>[];
  bool failNextStatus = false;
  bool failMessages = false;
  Completer<void>? markReadGate;

  @override
  Future<CursorPaged<Conversation>> list({
    required Map<String, dynamic> query,
    String? before,
    int perPage = AppConfig.defaultPerPage,
  }) async => CursorPaged(items: conversations);

  @override
  Future<InboxFacets> facets(Map<String, dynamic> query) async =>
      const InboxFacets();

  @override
  Future<List<String>> labels() async => const [];

  @override
  Future<InboxChanges> changes(String? after, {String? conversationId}) async =>
      const InboxChanges(cursor: 'cur', count: 0);

  @override
  Future<MessagePage> messages(
    String id, {
    String? before,
    int perPage = AppConfig.messagePageSize,
  }) async {
    if (failMessages) throw const NetworkException('Mất mạng');
    return _page;
  }

  final _page = MessagePage(
    messages: [
      Message(
        id: 'm2',
        author: MessageAuthor.agent,
        text: 'Dạ em chào chị',
        sentAt: DateTime(2026, 10, 9, 9, 1),
      ),
      Message(
        id: 'm1',
        author: MessageAuthor.customer,
        text: 'Chào em',
        sentAt: DateTime(2026, 10, 9, 9, 0),
      ),
    ],
    cursor: const CursorPage.empty(),
  );

  @override
  Future<void> markRead(String id) async {
    await markReadGate?.future;
    markReadCalls.add(id);
  }

  @override
  Future<Conversation> setStatus(String id, ConversationStatus status) async {
    if (failNextStatus) {
      failNextStatus = false;
      throw const ServerException('Máy chủ bận');
    }
    statusCalls.add((id, status));
    return conversations.firstWhere((c) => c.id == id).copyWith(status: status);
  }
}
