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
import 'package:omni_app/modules/inbox/application/thread_controller.dart';
import 'package:omni_app/modules/inbox/data/inbox_api.dart';
import 'package:omni_app/modules/inbox/domain/conversation.dart';
import 'package:omni_app/modules/inbox/domain/inbox_filter.dart';
import 'package:omni_app/modules/inbox/domain/message.dart';
import 'package:omni_app/modules/inbox/presentation/thread_page.dart';
import 'package:omni_app/modules/inbox/presentation/widgets/message_bubble.dart';
import 'package:omni_app/modules/settings/application/appearance_providers.dart';
import 'package:omni_app/security/permissions/access_policy.dart';
import 'package:omni_app/security/session/session.dart';
import 'package:omni_app/security/session/session_controller.dart';

import '../../support/fixed_background.dart';

/// Màn chat, dựng thật với API giả.
///
/// ThreadPage là màn quan trọng nhất của app và chưa từng có widget test: mọi
/// lượt sửa (nền cả app, tín hiệu realtime, composer) đều chỉ được kiểm bằng
/// mắt trên máy thật. Ba đường đi một rep đi mỗi ngày — đọc, gửi, gửi hỏng rồi
/// gửi lại — phải chạy được ở đây trước.
void main() {
  // Bong bóng in giờ gửi qua intl; không nạp dữ liệu locale là ném lúc dựng.
  setUpAll(() => initializeDateFormatting('vi_VN'));

  late _FakeInboxApi api;

  setUp(() => api = _FakeInboxApi());

  Widget host() => ProviderScope(
    overrides: [
      inboxApiProvider.overrideWithValue(api),
      // Không realtime: tín hiệu của hội thoại vẫn dựng được mà không mở socket.
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
      // SurfaceBackdrop đọc provider nền; provider thật cần SharedPreferences.
      backgroundProvider.overrideWith(FixedBackground.new),
    ],
    child: MaterialApp(
      theme: OmniTheme.light(TargetPlatform.android),
      home: const ThreadPage(conversationId: 'c1'),
    ),
  );

  /// Dựng trang và để lịch sử về. Không pumpAndSettle: nút gửi quay vòng và
  /// biên nhận chuyển cảnh, còn poll dự phòng là Timer.periodic.
  Future<void> openThread(WidgetTester tester) async {
    await tester.pumpWidget(host());
    await tester.pump();
    await tester.pump();
  }

  /// Gỡ trang TRƯỚC khi bài kiểm kết thúc: poll dự phòng là Timer.periodic và
  /// binding không cho timer nào sống sót qua bài kiểm.
  Future<void> closeThread(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  }

  ThreadState state(WidgetTester tester) => ProviderScope.containerOf(
    tester.element(find.byType(ThreadPage)),
  ).read(threadProvider('c1')).requireValue;

  Finder inBubble(String text) => find.descendant(
    of: find.byType(MessageBubble),
    matching: find.text(text),
  );

  Future<void> typeAndSend(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField), text);
    await tester.pump();
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pump();
  }

  testWidgets('dựng 3 tin theo thứ tự thời gian; mở là đánh dấu đã đọc', (
    tester,
  ) async {
    api.history = [
      _serverMessage('m1', 'Chào shop'),
      _serverMessage('m2', 'Dạ em nghe ạ', from: 'agent'),
      _serverMessage('m3', 'Còn đàn không'),
    ];

    await openThread(tester);

    expect(find.byType(MessageBubble), findsNWidgets(3));
    // Danh sách vẽ ngược: tin mới nhất nằm dưới cùng.
    expect(
      tester.getCenter(inBubble('Chào shop')).dy,
      lessThan(tester.getCenter(inBubble('Còn đàn không')).dy),
    );
    expect(api.markReadCalls, ['c1'], reason: 'Mở là đọc.');
    expect(
      find.text('Thuý Phạm'),
      findsOneWidget,
      reason: 'Tên khách trên bar.',
    );

    await closeThread(tester);
  });

  testWidgets('gửi → bong bóng "đang gửi" hiện ngay, thành "đã gửi" khi về', (
    tester,
  ) async {
    api.history = [_serverMessage('m1', 'Chào shop')];
    await openThread(tester);

    final gate = Completer<void>();
    api.holdSend = gate;
    await typeAndSend(tester, 'Dạ em gửi ạ');

    expect(inBubble('Dạ em gửi ạ'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('delivery-receipt-queued')),
      findsOneWidget,
      reason: 'Lạc quan: bong bóng lên trước khi server trả lời.',
    );
    expect(state(tester).pending, hasLength(1));

    gate.complete();
    await tester.pump();
    await tester.pump();
    // Biên nhận chuyển cảnh qua AnimatedSwitcher.
    await tester.pump(const Duration(seconds: 1));

    expect(find.byKey(const ValueKey('delivery-receipt-sent')), findsOneWidget);
    expect(find.byKey(const ValueKey('delivery-receipt-queued')), findsNothing);
    expect(state(tester).pending, isEmpty);
    expect(state(tester).messages.last.text, 'Dạ em gửi ạ');
    expect(
      find.descendant(
        of: find.byType(TextField),
        matching: find.text('Dạ em gửi ạ'),
      ),
      findsNothing,
      reason: 'Gửi xong thì ô nhập trống.',
    );

    await closeThread(tester);
  });

  testWidgets('gửi hỏng → "Gửi lại"; bấm → cùng lần gửi đó thành công', (
    tester,
  ) async {
    api.history = [_serverMessage('m1', 'Chào shop')];
    await openThread(tester);

    api.failNextSend = true;
    await typeAndSend(tester, 'Dạ em gửi ạ');
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Gửi lại'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('delivery-receipt-failed')),
      findsOneWidget,
    );
    expect(state(tester).pending.single.status, DeliveryStatus.failed);
    expect(
      inBubble('Dạ em gửi ạ'),
      findsOneWidget,
      reason: 'Tin hỏng phải còn trên màn để rep còn thấy mà gửi lại.',
    );

    await tester.tap(find.text('Gửi lại'));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Gửi lại'), findsNothing);
    expect(state(tester).pending, isEmpty);
    expect(state(tester).messages.last.text, 'Dạ em gửi ạ');
    expect(
      find.byType(MessageBubble),
      findsNWidgets(2),
      reason: 'Không nhân đôi.',
    );
    expect(api.sendCalls, hasLength(2));
    expect(
      api.sendCalls[1].clientMessageId,
      api.sendCalls[0].clientMessageId,
      reason:
          'Gửi lại là CÙNG một lần gửi (idempotency key giữ nguyên): lần đầu '
          'có thể đã tới server mà chỉ mất phản hồi.',
    );

    await closeThread(tester);
  });

  testWidgets('tin trả lời hiện trích dẫn tin gốc', (tester) async {
    api.history = [
      _serverMessage('m1', 'Còn đàn không'),
      _serverMessage(
        'm2',
        'Dạ còn ạ',
        from: 'agent',
        replyTo: (id: 'm1', text: 'Còn đàn không', author: 'Thuý Phạm'),
      ),
    ];

    await openThread(tester);

    expect(inBubble('Dạ còn ạ'), findsOneWidget);
    // Bong bóng trả lời mang khối trích dẫn: tên người và câu được trả lời.
    final replyBubble = find.ancestor(
      of: inBubble('Dạ còn ạ'),
      matching: find.byType(MessageBubble),
    );
    expect(
      find.descendant(
        of: replyBubble,
        matching: find.textContaining('Còn đàn không'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: replyBubble,
        matching: find.textContaining('Thuý Phạm'),
      ),
      findsOneWidget,
    );

    await closeThread(tester);
  });
}

typedef _ReplyTo = ({String id, String text, String author});

Message _serverMessage(
  String id,
  String text, {
  String from = 'customer',
  _ReplyTo? replyTo,
}) {
  final minute = int.parse(id.replaceAll(RegExp(r'\D'), ''));
  return Message.fromJson({
    'id': id,
    'from': from,
    'text': text,
    'status': from == 'agent' ? 'sent' : null,
    'sent_at': DateTime.utc(2026, 1, 1, 8, minute).toIso8601String(),
    if (replyTo != null) ...{
      'reply_to_message_id': replyTo.id,
      'reply_to_text': replyTo.text,
      'reply_to_author_name': replyTo.author,
    },
  });
}

typedef _SendCall = ({
  String? text,
  String? replyToMessageId,
  String? clientMessageId,
});

/// Stands in for the HTTP layer. Subclasses the real client because the app
/// wires a concrete [InboxApi]; the [ApiClient] handed to `super` is never used.
class _FakeInboxApi extends InboxApi {
  _FakeInboxApi() : super(ApiClient(Dio()));

  List<Message> history = const [];
  bool failNextSend = false;

  /// Holds the next send open so a test can look at the optimistic bubble.
  Completer<void>? holdSend;

  final markReadCalls = <String>[];
  final sendCalls = <_SendCall>[];
  int _sent = 0;

  @override
  Future<MessagePage> messages(
    String id, {
    String? before,
    int perPage = AppConfig.messagePageSize,
  }) async {
    return MessagePage(
      // The API answers newest-first; the controller reverses it.
      messages: history.reversed.toList(),
      cursor: const CursorPage.empty(),
    );
  }

  @override
  Future<Conversation> get(String id) async => Conversation(
    id: id,
    channel: Channel.zalo,
    status: ConversationStatus.open,
    customerName: 'Thuý Phạm',
    lastMessage: 'Còn đàn không',
    unread: 2,
  );

  @override
  Future<void> markRead(String id) async => markReadCalls.add(id);

  @override
  Future<InboxChanges> changes(String? after, {String? conversationId}) async =>
      const InboxChanges(cursor: 'cur', count: 0);

  @override
  Future<InboxFacets> facets(Map<String, dynamic> query) async =>
      const InboxFacets();

  @override
  Future<Paged<Conversation>> list({
    required Map<String, dynamic> query,
    int page = 1,
    int perPage = AppConfig.defaultPerPage,
  }) async => const Paged.empty();

  @override
  Future<Message> send(
    String id, {
    String? text,
    List<MessageAttachment> attachments = const [],
    String? replyToMessageId,
    String? clientMessageId,
  }) async {
    sendCalls.add((
      text: text,
      replyToMessageId: replyToMessageId,
      clientMessageId: clientMessageId,
    ));
    final gate = holdSend;
    if (gate != null) {
      holdSend = null;
      await gate.future;
    }
    if (failNextSend) {
      failNextSend = false;
      throw const NetworkException('Không có kết nối mạng.');
    }
    return Message.fromJson({
      'id': 'srv-${++_sent}',
      'client_message_id': clientMessageId,
      'from': 'agent',
      'text': text,
      'status': 'sent',
      'reply_to_message_id': replyToMessageId,
      'sent_at': DateTime.utc(2026, 1, 1, 9, _sent).toIso8601String(),
    });
  }
}
