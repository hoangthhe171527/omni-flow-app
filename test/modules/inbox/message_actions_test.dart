import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:omni_app/modules/inbox/data/inbox_api.dart';
import 'package:omni_app/modules/inbox/domain/conversation.dart';
import 'package:omni_app/modules/inbox/domain/inbox_filter.dart';
import 'package:omni_app/modules/inbox/domain/message.dart';
import 'package:omni_app/modules/inbox/presentation/thread_page.dart';
import 'package:omni_app/modules/inbox/presentation/widgets/message_bubble.dart';
import 'package:omni_app/modules/opportunities/domain/opportunity_permissions.dart';
import 'package:omni_app/modules/tasks/domain/task_permissions.dart';
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
const _allPermissions = {
  'inbox.read',
  'inbox.write',
  TaskPermissions.write,
  OpportunityPermissions.create,
};

void main() {
  // Bong bóng in giờ gửi qua intl; không nạp dữ liệu locale là ném lúc dựng.
  setUpAll(() => initializeDateFormatting('vi_VN'));

  late _FakeInboxApi api;

  setUp(() => api = _FakeInboxApi());

  Widget host({
    Set<String> permissions = _allPermissions,
    Map<String, bool> features = const {},
  }) => ProviderScope(
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
        Session(
          status: SessionStatus.authenticated,
          user: const SessionUser(id: 'u1', fullName: 'Kiệt', email: 'k@x.vn'),
          tenant: const SessionTenant(id: 't1', name: 'Xưởng đàn'),
          policy: AccessPolicy(permissions),
          features: features,
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
  Future<void> openThread(
    WidgetTester tester, {
    Set<String> permissions = _allPermissions,
    Map<String, bool> features = const {},
  }) async {
    await tester.pumpWidget(host(permissions: permissions, features: features));
    await tester.pump();
    await tester.pump();
  }

  /// Gỡ trang TRƯỚC khi bài kiểm kết thúc: poll dự phòng là Timer.periodic và
  /// binding không cho timer nào sống sót qua bài kiểm.
  Future<void> closeThread(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  }

  Finder inBubble(String text) => find.descendant(
    of: find.byType(MessageBubble),
    matching: find.text(text),
  );

  Future<void> holdBubble(WidgetTester tester, String text) async {
    final g = await tester.startGesture(tester.getCenter(inBubble(text)));
    await tester.pump(const Duration(milliseconds: 430));
    await g.up();
    await tester.pumpAndSettle(const Duration(milliseconds: 50));
  }

  testWidgets('giữ tin → menu đủ mục, không có thanh cảm xúc', (tester) async {
    api.history = [_serverMessage('m1', 'Chào shop')];
    await openThread(tester);
    await holdBubble(tester, 'Chào shop');
    for (final l in [
      'Trả lời',
      'Sao chép',
      'Ghim tin',
      'Tạo việc từ tin này',
    ]) {
      expect(find.text(l), findsOneWidget);
    }
    expect(find.text('❤️'), findsNothing);
    await closeThread(tester);
  });

  testWidgets('Sao chép → clipboard có nội dung tin', (tester) async {
    final calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        calls.add(call);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    api.history = [_serverMessage('m1', 'Chào shop')];
    await openThread(tester);
    await holdBubble(tester, 'Chào shop');
    await tester.tap(find.text('Sao chép'));
    await tester.pumpAndSettle(const Duration(milliseconds: 50));
    expect(
      calls
          .where((c) => c.method == 'Clipboard.setData')
          .single
          .arguments['text'],
      'Chào shop',
    );
    expect(find.text('Đã sao chép.'), findsOneWidget);
    await closeThread(tester);
  });

  testWidgets('cơ hội tắt → không có Tạo cơ hội', (tester) async {
    api.history = [_serverMessage('m1', 'Chào shop')];
    await openThread(tester, features: const {'opportunities': false});
    await holdBubble(tester, 'Chào shop');
    expect(find.text('Tạo cơ hội'), findsNothing);
    await closeThread(tester);
  });

  testWidgets('cơ hội bật + đủ quyền → có Tạo cơ hội', (tester) async {
    api.history = [_serverMessage('m1', 'Chào shop')];
    await openThread(tester);
    await holdBubble(tester, 'Chào shop');
    expect(find.text('Tạo cơ hội'), findsOneWidget);
    await closeThread(tester);
  });

  testWidgets('thiếu quyền tạo việc/cơ hội → menu không có hai mục đó', (
    tester,
  ) async {
    api.history = [_serverMessage('m1', 'Chào shop')];
    await openThread(tester, permissions: const {'inbox.read', 'inbox.write'});
    await holdBubble(tester, 'Chào shop');
    expect(find.text('Tạo việc từ tin này'), findsNothing);
    expect(find.text('Tạo cơ hội'), findsNothing);
    expect(find.text('Trả lời'), findsOneWidget);
    await closeThread(tester);
  });

  testWidgets('mục menu cao ≥44 và menu vừa màn 360 rộng', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    api.history = [_serverMessage('m1', 'Chào shop')];
    await openThread(tester);
    await holdBubble(tester, 'Chào shop');
    final row = find.ancestor(
      of: find.text('Sao chép'),
      matching: find.byType(InkWell),
    );
    expect(tester.getSize(row.first).height, greaterThanOrEqualTo(44));
    expect(tester.takeException(), isNull);
    await closeThread(tester);
  });

  testWidgets('bấm vùng trống quanh menu → đóng menu', (tester) async {
    api.history = [_serverMessage('m1', 'Chào shop')];
    await openThread(tester);
    await holdBubble(tester, 'Chào shop');
    expect(find.text('Sao chép'), findsOneWidget);
    await tester.tapAt(const Offset(790, 590));
    await tester.pumpAndSettle(const Duration(milliseconds: 50));
    expect(find.text('Sao chép'), findsNothing);
    await closeThread(tester);
  });

  testWidgets('nút Back → đóng menu, vẫn ở trang chat', (tester) async {
    api.history = [_serverMessage('m1', 'Chào shop')];
    await openThread(tester);
    await holdBubble(tester, 'Chào shop');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle(const Duration(milliseconds: 50));
    expect(find.text('Sao chép'), findsNothing);
    expect(find.byType(ThreadPage), findsOneWidget);
    await closeThread(tester);
  });

  testWidgets('vuốt ngang tin vẫn trả lời (không mở menu)', (tester) async {
    api.history = [_serverMessage('m1', 'Chào shop')];
    await openThread(tester);
    await tester.drag(inBubble('Chào shop'), const Offset(200, 0));
    await tester.pumpAndSettle(const Duration(milliseconds: 50));
    expect(find.text('Sao chép'), findsNothing);
    // Bong bóng + khung trả lời trên thanh nhập.
    expect(find.text('Chào shop'), findsNWidgets(2));
    await closeThread(tester);
  });

  testWidgets('bấm ảnh vẫn mở trình xem ảnh', (tester) async {
    api.history = [
      _serverMessage('m1', 'Ảnh đàn', images: ['a.jpg']),
    ];
    await openThread(tester);
    await tester.tap(find.byType(CachedNetworkImage));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byTooltip('Đóng'), findsOneWidget);
    await closeThread(tester);
  });

  testWidgets('tin đã thu hồi → không có Sao chép', (tester) async {
    api.history = [_serverMessage('m1', 'Chào shop', recalled: true)];
    await openThread(tester);
    await tester.longPress(find.byType(MessageBubble));
    await tester.pumpAndSettle(const Duration(milliseconds: 50));
    expect(find.text('Trả lời'), findsOneWidget);
    expect(find.text('Sao chép'), findsNothing);
    await closeThread(tester);
  });

  testWidgets('tin đã ghim → mục "Bỏ ghim"', (tester) async {
    api.history = [_serverMessage('m1', 'Chào shop', pinned: true)];
    await openThread(tester);
    await holdBubble(tester, 'Chào shop');
    expect(find.text('Bỏ ghim'), findsOneWidget);
    expect(find.text('Ghim tin'), findsNothing);
    await closeThread(tester);
  });

  testWidgets('ghim lỗi → báo lỗi', (tester) async {
    api.history = [_serverMessage('m1', 'Chào shop')];
    api.failPin = true;
    await openThread(tester);
    await holdBubble(tester, 'Chào shop');
    await tester.tap(find.text('Ghim tin'));
    await tester.pumpAndSettle(const Duration(milliseconds: 50));
    expect(find.text('Không có kết nối mạng.'), findsOneWidget);
    await closeThread(tester);
  });

  testWidgets('chép vào clipboard lỗi → báo lỗi, không ném', (tester) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          throw PlatformException(code: 'denied');
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    api.history = [_serverMessage('m1', 'Chào shop')];
    await openThread(tester);
    await holdBubble(tester, 'Chào shop');
    await tester.tap(find.text('Sao chép'));
    await tester.pumpAndSettle(const Duration(milliseconds: 50));
    expect(find.text('Không sao chép được. Vui lòng thử lại.'), findsOneWidget);
    await closeThread(tester);
  });

  testWidgets('bấm đúp tin không làm gì (chưa có API cảm xúc)', (tester) async {
    api.history = [_serverMessage('m1', 'Chào shop')];
    await openThread(tester);
    await tester.tap(inBubble('Chào shop'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(inBubble('Chào shop'));
    await tester.pumpAndSettle(const Duration(milliseconds: 50));
    expect(find.text('❤️'), findsNothing);
    expect(find.text('Sao chép'), findsNothing);
    await closeThread(tester);
  });

  testWidgets('kéo dọc danh sách không mở menu', (tester) async {
    api.history = [_serverMessage('m1', 'Chào shop')];
    await openThread(tester);
    final g = await tester.startGesture(
      tester.getCenter(inBubble('Chào shop')),
    );
    await g.moveBy(const Offset(0, -60));
    await tester.pump(const Duration(milliseconds: 600));
    await g.up();
    await tester.pumpAndSettle(const Duration(milliseconds: 50));
    expect(find.text('Sao chép'), findsNothing);
    await closeThread(tester);
  });
}

typedef _ReplyTo = ({String id, String text, String author});

Message _serverMessage(
  String id,
  String text, {
  String from = 'customer',
  _ReplyTo? replyTo,
  List<String> images = const [],
  String sig = 'v1',
  bool recalled = false,
  bool pinned = false,
}) {
  final minute = int.parse(id.replaceAll(RegExp(r'\D'), ''));
  return Message.fromJson({
    'id': id,
    'from': from,
    'text': text,
    if (recalled) 'recalled': true,
    if (pinned) 'pinned': true,
    'status': from == 'agent' ? 'sent' : null,
    'sent_at': DateTime.utc(2026, 1, 1, 8, minute).toIso8601String(),
    if (images.isNotEmpty)
      'attachments': [
        for (final name in images)
          {
            'url':
                'https://api.khac.vn/api/v1/inbox/media/t1/$name?expires=1&signature=$sig',
            'type': 'image/jpeg',
          },
      ],
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
  bool failPin = false;

  /// Holds the next send open so a test can look at the optimistic bubble.
  Completer<void>? holdSend;

  final markReadCalls = <String>[];
  int messagesCalls = 0;

  /// Lượt gọi `messages` kế tiếp ném lỗi mạng.
  bool failNextMessages = false;

  /// `quickReplies` ném (mất mạng) khi đặt; ngược lại trả `quickReplyList`.
  bool failQuickReplies = false;
  List<QuickReply>? quickReplyList;
  final sendCalls = <_SendCall>[];
  int _sent = 0;

  @override
  Future<MessagePage> messages(
    String id, {
    String? before,
    int perPage = AppConfig.messagePageSize,
  }) async {
    messagesCalls++;
    if (failNextMessages) {
      failNextMessages = false;
      throw const NetworkException('offline');
    }
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
  Future<bool> togglePin(String conversationId, String messageId) async {
    if (failPin) throw const NetworkException('Không có kết nối mạng.');
    return true;
  }

  @override
  Future<void> markRead(String id) async => markReadCalls.add(id);

  @override
  Future<List<QuickReply>?> quickReplies() async {
    if (failQuickReplies) throw const NetworkException('offline');
    return quickReplyList;
  }

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
