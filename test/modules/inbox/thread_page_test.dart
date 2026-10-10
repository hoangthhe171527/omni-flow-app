import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:omni_app/core/config/app_config.dart';
import 'package:omni_app/core/domain/channel.dart';
import 'package:omni_app/core/error/app_exception.dart';
import 'package:omni_app/core/network/api_client.dart';
import 'package:omni_app/core/network/api_envelope.dart';
import 'package:omni_app/core/realtime/realtime_client.dart';
import 'package:omni_app/core/utils/formatters.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/modules/inbox/application/thread_controller.dart';
import 'package:omni_app/modules/inbox/application/voice_recorder.dart';
import 'package:omni_app/modules/inbox/data/inbox_api.dart';
import 'package:omni_app/modules/inbox/domain/conversation.dart';
import 'package:omni_app/modules/inbox/domain/inbox_filter.dart';
import 'package:omni_app/modules/inbox/domain/message.dart';
import 'package:omni_app/modules/inbox/domain/outbound_capabilities.dart';
import 'package:omni_app/modules/inbox/inbox_routes.dart';
import 'package:omni_app/modules/inbox/presentation/thread_page.dart';
import 'package:omni_app/modules/inbox/presentation/thread_info_page.dart';
import 'package:omni_app/modules/inbox/presentation/widgets/message_bubble.dart';
import 'package:omni_app/modules/inbox/presentation/widgets/message_composer.dart';
import 'package:omni_app/modules/inbox/presentation/widgets/thread_header.dart';
import 'package:omni_app/modules/settings/application/appearance_providers.dart';
import 'package:omni_app/security/permissions/access_policy.dart';
import 'package:omni_app/security/session/session.dart';
import 'package:omni_app/security/session/session_controller.dart';

import '../../support/fake_voice_recorder.dart';
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

  late FakeVoiceRecorder recorder;
  setUp(() => recorder = FakeVoiceRecorder());

  Widget host({
    Set<String> permissions = const {'inbox.read', 'inbox.write'},
  }) => ProviderScope(
    overrides: [
      inboxApiProvider.overrideWithValue(api),
      voiceRecorderProvider.overrideWith((ref) => recorder),
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
    Set<String> permissions = const {'inbox.read', 'inbox.write'},
  }) async {
    await tester.pumpWidget(host(permissions: permissions));
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

  testWidgets('Mẫu trả lời: máy chủ lỗi → vẫn có bộ câu mặc định', (
    tester,
  ) async {
    api.failQuickReplies = true;
    await openThread(tester);

    await tester.tap(find.byTooltip('Thêm'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mẫu trả lời'));
    await tester.pumpAndSettle();

    expect(find.text('Em gửi báo giá ạ'), findsOneWidget);
    await closeThread(tester);
  });

  testWidgets('Mẫu trả lời: có mẫu của tenant thì dùng mẫu đó', (tester) async {
    api.quickReplyList = const [
      QuickReply(id: 'q1', title: 'Chào', body: 'Dạ em chào chị ạ'),
    ];
    await openThread(tester);

    await tester.tap(find.byTooltip('Thêm'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mẫu trả lời'));
    await tester.pumpAndSettle();

    expect(find.text('Dạ em chào chị ạ'), findsOneWidget);
    expect(find.text('Em gửi báo giá ạ'), findsNothing);
    await closeThread(tester);
  });

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
      findsWidgets,
      reason: 'Tên khách trên header (và khối giới thiệu).',
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

  testWidgets('tìm tin từ trang Thông tin: kết quả không gồm ghi chú nội bộ', (
    tester,
  ) async {
    api.searchResult = [
      Message(
        id: 'n1',
        author: MessageAuthor.note,
        text: 'ghi chú kín',
        sentAt: DateTime.utc(2026, 1, 1, 9),
      ),
      Message(
        id: 'm9',
        author: MessageAuthor.customer,
        text: 'đàn piano',
        sentAt: DateTime.utc(2026, 1, 1, 9, 5),
      ),
    ];
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const ThreadPage(conversationId: 'c1'),
        ),
        GoRoute(
          path: '/inbox/:id/info',
          name: InboxRoutes.threadInfo,
          builder: (context, _) => Builder(
            builder: (context) {
              WidgetsBinding.instance.addPostFrameCallback(
                (_) => Navigator.of(context).pop(ThreadInfoResult.search),
              );
              return const Scaffold();
            },
          ),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
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
              user: const SessionUser(
                id: 'u1',
                fullName: 'Kiệt',
                email: 'k@x.vn',
              ),
              tenant: const SessionTenant(id: 't1', name: 'Xưởng đàn'),
              policy: const AccessPolicy({'inbox.read', 'inbox.write'}),
            ),
          ),
          backgroundProvider.overrideWith(FixedBackground.new),
        ],
        child: MaterialApp.router(
          theme: OmniTheme.light(TargetPlatform.android),
          routerConfig: router,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.tap(find.text('Thuý Phạm').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    final field = find.descendant(
      of: find.byType(ThreadHeader),
      matching: find.byType(TextField),
    );
    await tester.enterText(field, 'đàn');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();

    final ids = state(tester).messages.map((m) => m.id);
    expect(ids, contains('m9'));
    expect(ids, isNot(contains('n1')));
    await closeThread(tester);
  });

  // Đợt 7 P2: dải ngày tách theo NGÀY VN, không theo ngày UTC. 23:30 và 00:30
  // giờ VN cùng một ngày UTC (16:30Z, 17:30Z) nhưng là hai ngày ở VN.
  testWidgets('tin 23:30 và 00:30 giờ VN nằm ở hai ngày khác nhau', (
    tester,
  ) async {
    Message at(String id, DateTime utc) => Message.fromJson({
      'id': id,
      'from': 'customer',
      'text': 'Tin $id',
      'sent_at': utc.toIso8601String(),
    });
    final late = at('m1', DateTime.utc(2026, 1, 1, 16, 30)); // 23:30 VN 1/1
    final early = at('m2', DateTime.utc(2026, 1, 1, 17, 30)); // 00:30 VN 2/1
    api.history = [late, early];

    await openThread(tester);

    final first = Formatters.threadStamp(late.sentAt!);
    final second = Formatters.threadStamp(early.sentAt!);
    expect(first, isNot(second));
    expect(find.text(first), findsOneWidget);
    expect(find.text(second), findsOneWidget);

    await closeThread(tester);
  });

  // Đợt 7 P2 (INB-I28): `/read` và `/pin` cần `inbox.write` (routes.php:47,49).
  // Người chỉ đọc mở hội thoại thì không gọi `/read` (403 bị nuốt), và menu
  // tin không mời ghim.
  group('quyền đọc/ghim', () {
    Future<void> openActions(WidgetTester tester) async {
      await tester.longPress(inBubble('Chào shop'));
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
    }

    testWidgets('chỉ inbox.read: không gọi /read, menu không có Ghim', (
      tester,
    ) async {
      api.history = [_serverMessage('m1', 'Chào shop')];
      await openThread(tester, permissions: const {'inbox.read'});

      expect(api.markReadCalls, isEmpty);

      await openActions(tester);
      expect(find.text('Ghim tin'), findsNothing);

      await closeThread(tester);
    });

    testWidgets('inbox.read + inbox.write: gọi /read, menu có Ghim', (
      tester,
    ) async {
      api.history = [_serverMessage('m1', 'Chào shop')];
      await openThread(tester);

      expect(api.markReadCalls, ['c1']);

      await openActions(tester);
      expect(find.text('Ghim tin'), findsOneWidget);

      await closeThread(tester);
    });
  });

  group('ảnh hết hạn (link ký 12 giờ, MS-I24)', () {
    late DateTime now;
    setUp(() {
      now = DateTime(2026, 10, 4, 8);
      mediaReloadClock = () => now;
    });
    tearDown(() => mediaReloadClock = DateTime.now);

    List<Message> history(String sig) => [
      _serverMessage('m1', 'Ảnh đàn', images: ['a.jpg'], sig: sig),
      _serverMessage('m2', 'Thêm ảnh', images: ['b.jpg'], sig: sig),
    ];

    // Môi trường test không tải ảnh thật: gọi thẳng errorListener của ảnh
    // đang dựng, như khi server trả 403 cho link đã quá hạn.
    void fail(WidgetTester tester, {int? only}) {
      final images = tester
          .widgetList<CachedNetworkImage>(find.byType(CachedNetworkImage))
          .toList();
      for (var i = 0; i < images.length; i++) {
        if (only == null || only == i) {
          images[i].errorListener!(Exception('HTTP 403'));
        }
      }
    }

    /// Màn cao để mọi ảnh cùng được dựng (danh sách chỉ dựng phần đang thấy).
    Future<void> openTall(WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await openThread(tester);
      expect(find.byType(CachedNetworkImage), findsNWidgets(2));
    }

    Future<void> settle(WidgetTester tester) async {
      await tester.pump();
      await tester.pump();
      await tester.pump();
    }

    testWidgets('cả loạt ảnh hỏng → tải lại tin ĐÚNG một lần; URL ký mới '
        'cũng hỏng trong 10 phút → không tải lại nữa; quá 10 phút thì có', (
      tester,
    ) async {
      api.history = history('v1');
      await openTall(tester);
      final before = api.messagesCalls;
      expect(find.byType(CachedNetworkImage), findsWidgets);

      // Lượt tải lại sẽ mang URL ký MỚI về — ảnh dựng lại với URL mới.
      api.history = history('v2');
      fail(tester);
      await settle(tester);
      expect(api.messagesCalls - before, 1);
      expect(
        tester
            .widgetList<CachedNetworkImage>(find.byType(CachedNetworkImage))
            .every((i) => i.imageUrl.contains('signature=v2')),
        isTrue,
        reason: 'Ảnh đã mang URL mới, được báo lỗi lại.',
      );

      // URL mới cũng hỏng (tệp đã xoá): trong thời gian nghỉ → không lặp.
      api.history = history('v3');
      fail(tester, only: 0);
      await settle(tester);
      expect(api.messagesCalls - before, 1);

      // Đối chứng: qua 10 phút, ảnh kia hỏng thì được tải lại lần nữa.
      now = now.add(const Duration(minutes: 11));
      fail(tester, only: 1);
      await settle(tester);
      expect(api.messagesCalls - before, 2);

      await closeThread(tester);
    });

    testWidgets('lượt tải lại hỏng (mất mạng) không tiêu thời gian nghỉ', (
      tester,
    ) async {
      api.history = history('v1');
      await openTall(tester);
      final before = api.messagesCalls;

      api.failNextMessages = true;
      fail(tester, only: 0);
      await settle(tester);
      expect(api.messagesCalls - before, 1);

      // Ảnh khác hỏng ngay sau đó (mạng đã về): vẫn được tải lại.
      fail(tester, only: 1);
      await settle(tester);
      expect(api.messagesCalls - before, 2);

      await closeThread(tester);
    });

    testWidgets(
      'bấm "Tải lại ảnh" → lấy URL ký mới (kể cả trong thời gian nghỉ)',
      (tester) async {
        api.history = history('v1');
        await openTall(tester);
        final before = api.messagesCalls;

        fail(tester);
        await settle(tester);
        expect(api.messagesCalls - before, 1);

        // Ảnh hiện nút tải lại (errorWidget của CachedNetworkImage); người dùng
        // bấm — trong thời gian nghỉ vẫn phải lấy URL ký mới.
        final finder = find.byType(CachedNetworkImage).first;
        final image = tester.widget<CachedNetworkImage>(finder);
        final errorBox =
            image.errorWidget!(tester.element(finder), image.imageUrl, Object())
                as ColoredBox;
        final button = (errorBox.child! as Center).child! as IconButton;
        expect(button.tooltip, 'Tải lại ảnh');
        button.onPressed!();
        await settle(tester);
        expect(api.messagesCalls - before, 2);

        await closeThread(tester);
      },
    );
  });

  group('Task 6: ghi âm', () {
    Map<String, dynamic> caps(String audio) => {
      'can_send': true,
      'text': 'native',
      'image': 'native',
      'file': 'native',
      'audio': audio,
      'video': audio,
    };

    // Khả năng gửi về sau lượt dựng đầu: cụm công cụ nở thêm nút mic (350ms).
    Future<void> open(WidgetTester tester) async {
      await openThread(tester);
      await tester.pump(const Duration(milliseconds: 400));
    }

    Future<void> record(WidgetTester tester, Duration length) async {
      await tester.tap(find.byTooltip('Ghi âm'));
      await tester.pump();
      await tester.pump();
      recorder.tick(length);
      await tester.pump();
    }

    testWidgets('ghi → Gửi: upload tệp .wav, gửi tin không chữ với type '
        'audio do server trả', (tester) async {
      api.capabilities = caps('native');
      await open(tester);
      await record(tester, const Duration(seconds: 4));

      await tester.tap(find.byTooltip('Gửi ghi âm'));
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(api.uploads, [
        (
          path: '/tmp/ghi-am-20261010-090507.wav',
          filename: 'ghi-am-20261010-090507.wav',
        ),
      ]);
      expect(api.sendCalls.single.text, '');
      final sent = api.sentAttachments.single.single;
      expect(sent.type, 'audio');
      expect(sent.name, 'ghi-am-20261010-090507.wav');
      expect(find.byType(TextField), findsOneWidget);
      await closeThread(tester);
    });

    testWidgets('Zalo OA (audio: link) → hỏi trước khi ghi', (tester) async {
      api.capabilities = caps('link');
      await open(tester);
      await tester.tap(find.byTooltip('Ghi âm'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.textContaining('gửi dưới dạng đường link'), findsOneWidget);
      await tester.tap(find.text('Huỷ'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(recorder.starts, isEmpty);
      await closeThread(tester);
    });

    testWidgets('API cũ thiếu khoá / audio none → không có mic', (
      tester,
    ) async {
      await openThread(tester);
      expect(find.byTooltip('Ghi âm'), findsNothing);
      await closeThread(tester);

      api.capabilities = caps('none');
      await openThread(tester);
      expect(find.byTooltip('Ghi âm'), findsNothing);
      await closeThread(tester);
    });

    testWidgets('rời trang khi đang ghi → huỷ bản ghi', (tester) async {
      api.capabilities = caps('native');
      await open(tester);
      await record(tester, const Duration(seconds: 2));
      await closeThread(tester);
      expect(recorder.cancels, 1);
    });

    testWidgets('snackbar của trang nổi phía trên composer', (tester) async {
      api.capabilities = caps('native');
      recorder.permission = false;
      await open(tester);
      await tester.tap(find.byTooltip('Ghi âm'));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      final snack = tester.getRect(
        find
            .descendant(
              of: find.byType(SnackBar),
              matching: find.byType(Material),
            )
            .first,
      );
      final bar = tester.getRect(find.byType(MessageComposer));
      expect(snack.bottom, lessThanOrEqualTo(bar.top));
      await closeThread(tester);
    });
  });

  group('Task 5: khả năng gửi của kênh, tin lỗi, gửi lại qua /resend', () {
    Message failedOnServer(String id, {String? code}) => Message.fromJson({
      'id': id,
      'from': 'agent',
      'direction': 'out',
      'text': 'Dạ em gửi ạ',
      'status': 'failed',
      'error': code == null ? 'Zalo từ chối' : 'Kênh này chưa hỗ trợ gửi.',
      'error_code': ?code,
      'sent_at': DateTime.utc(2026, 1, 1, 8, 2).toIso8601String(),
    });

    testWidgets('can_send:false (TikTok) → không composer, có dòng báo', (
      tester,
    ) async {
      api.capabilities = const {
        'can_send': false,
        'text': 'none',
        'image': 'none',
        'file': 'none',
        'audio': 'none',
        'video': 'none',
      };
      await openThread(tester);
      await tester.pump();
      expect(find.byType(MessageComposer), findsNothing);
      expect(
        find.textContaining('Kênh này chưa gửi tin được từ Hộp thư'),
        findsOneWidget,
      );
      await closeThread(tester);
    });

    testWidgets('API cũ (thiếu outbound_capabilities) → vẫn có composer', (
      tester,
    ) async {
      await openThread(tester);
      expect(find.byType(MessageComposer), findsOneWidget);
      await closeThread(tester);
    });

    testWidgets('422 channel_send_unsupported khi gửi → câu server trong '
        'composer, giữ nháp, không bong bóng lỗi', (tester) async {
      await openThread(tester);
      api.sendError = const ValidationException(
        'Kênh này chưa hỗ trợ gửi tin đi từ Hộp thư.',
        reason: 'channel_send_unsupported',
      );
      await typeAndSend(tester, 'Dạ em gửi ạ');
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(
        find.descendant(
          of: find.byType(MessageComposer),
          matching: find.text('Kênh này chưa hỗ trợ gửi tin đi từ Hộp thư.'),
        ),
        findsOneWidget,
      );
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Dạ em gửi ạ',
      );
      expect(state(tester).pending, isEmpty);
      expect(find.text('Gửi lại'), findsNothing);
      await closeThread(tester);
    });

    testWidgets('tin server failed + channel_send_unsupported → không "Gửi '
        'lại"', (tester) async {
      api.history = [
        _serverMessage('m1', 'Chào shop'),
        failedOnServer('m2', code: 'channel_send_unsupported'),
      ];
      await openThread(tester);
      expect(find.text('Kênh này chưa hỗ trợ gửi.'), findsOneWidget);
      expect(find.text('Gửi lại'), findsNothing);
      await closeThread(tester);
    });

    testWidgets('Gửi lại tin ĐÃ có id server → POST …/resend, không gửi tin '
        'mới', (tester) async {
      api.history = [_serverMessage('m1', 'Chào shop'), failedOnServer('m2')];
      await openThread(tester);
      expect(find.text('Gửi lại'), findsOneWidget);

      await tester.tap(find.text('Gửi lại'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(api.resendCalls, ['m2']);
      expect(api.sendCalls, isEmpty);
      expect(find.text('Gửi lại'), findsNothing);
      final m2 = state(tester).messages.firstWhere((m) => m.id == 'm2');
      expect(m2.status, DeliveryStatus.queued);
      expect(state(tester).pending, isEmpty);
      expect(find.byType(MessageBubble), findsNWidgets(2));
      await closeThread(tester);
    });

    const tooOld = ValidationException(
      'Tin này đã quá lâu để gửi lại — hãy gửi một tin mới.',
      reason: 'message_too_old_to_resend',
    );

    testWidgets('/resend 422 quá hạn → HỎI; đồng ý → gửi tin mới', (
      tester,
    ) async {
      api.history = [_serverMessage('m1', 'Chào shop'), failedOnServer('m2')];
      api.resendError = tooOld;
      await openThread(tester);
      await tester.tap(find.text('Gửi lại'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(api.resendCalls, ['m2']);
      expect(api.sendCalls, isEmpty, reason: 'chưa đồng ý thì chưa gửi');
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.textContaining('quá lâu để gửi lại'),
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Gửi tin mới'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(api.sendCalls.single.text, 'Dạ em gửi ạ');
      expect(find.text('Gửi lại'), findsNothing);
      expect(find.byType(MessageBubble), findsNWidgets(2), reason: 'thay chỗ');
      await closeThread(tester);
    });

    testWidgets('/resend 422 quá hạn → Huỷ: không gửi, vẫn failed', (
      tester,
    ) async {
      api.history = [_serverMessage('m1', 'Chào shop'), failedOnServer('m2')];
      api.resendError = tooOld;
      await openThread(tester);
      await tester.tap(find.text('Gửi lại'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Huỷ'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(api.sendCalls, isEmpty);
      final m2 = state(tester).messages.firstWhere((m) => m.id == 'm2');
      expect(m2.status, DeliveryStatus.failed);
      expect(
        find.text('Tin này đã quá lâu để gửi lại — hãy gửi một tin mới.'),
        findsOneWidget,
      );
      await closeThread(tester);
    });

    testWidgets('/resend 409 message_not_failed → tải lại, KHÔNG gửi tin mới', (
      tester,
    ) async {
      api.history = [_serverMessage('m1', 'Chào shop'), failedOnServer('m2')];
      // 409 không mang `data`: bong bóng về failed rồi tải lại.
      api.resendError = const MessageNotFailedException(
        'Tin này không ở trạng thái gửi lỗi nên không gửi lại được.',
      );
      await openThread(tester);
      final before = api.messagesCalls;
      // Server: tin đã đi (một lượt khác gửi lại xong).
      api.history = [
        _serverMessage('m1', 'Chào shop'),
        _serverMessage('m2', 'Dạ em gửi ạ', from: 'agent'),
      ];
      await tester.tap(find.text('Gửi lại'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(api.sendCalls, isEmpty);
      expect(api.messagesCalls, greaterThan(before));
      final m2 = state(tester).messages.firstWhere((m) => m.id == 'm2');
      expect(m2.status, DeliveryStatus.sent);
      expect(find.text('Gửi lại'), findsNothing);
      await closeThread(tester);
    });

    testWidgets('/resend 409 mang tin hiện tại → thay bong bóng bằng nó, '
        'không tải lại, không gửi', (tester) async {
      api.history = [_serverMessage('m1', 'Chào shop'), failedOnServer('m2')];
      api.resendError = MessageNotFailedException(
        'Tin này không ở trạng thái gửi lỗi nên không gửi lại được.',
        current: _serverMessage('m2', 'Dạ em gửi ạ', from: 'agent'),
      );
      await openThread(tester);
      final before = api.messagesCalls;
      await tester.tap(find.text('Gửi lại'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(api.sendCalls, isEmpty);
      expect(api.messagesCalls, before, reason: 'đã có tin từ 409');
      final m2 = state(tester).messages.firstWhere((m) => m.id == 'm2');
      expect(m2.status, DeliveryStatus.sent);
      expect(find.text('Gửi lại'), findsNothing);
      await closeThread(tester);
    });

    testWidgets('/resend 409 không data, tải lại lỗi → bong bóng về failed '
        '(không kẹt "đang gửi")', (tester) async {
      api.history = [_serverMessage('m1', 'Chào shop'), failedOnServer('m2')];
      api.resendError = const MessageNotFailedException('Không gửi lại được.');
      await openThread(tester);
      api.failNextMessages = true;
      await tester.tap(find.text('Gửi lại'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(api.sendCalls, isEmpty);
      final m2 = state(tester).messages.firstWhere((m) => m.id == 'm2');
      expect(m2.status, DeliveryStatus.failed);
      await closeThread(tester);
    });

    testWidgets('/resend ném lỗi lạ → bong bóng về failed, còn "Gửi lại"', (
      tester,
    ) async {
      api.history = [_serverMessage('m1', 'Chào shop'), failedOnServer('m2')];
      api.resendError = StateError('hỏng');
      await openThread(tester);
      await tester.tap(find.text('Gửi lại'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      final m2 = state(tester).messages.firstWhere((m) => m.id == 'm2');
      expect(m2.status, DeliveryStatus.failed);
      expect(find.text('Gửi lại'), findsOneWidget);
      await closeThread(tester);
    });

    testWidgets('/resend 404 không có route (API cũ) → gửi theo đường cũ', (
      tester,
    ) async {
      api.history = [_serverMessage('m1', 'Chào shop'), failedOnServer('m2')];
      api.resendError = const NotFoundException(
        'Không tìm thấy dữ liệu.',
        routeMissing: true,
      );
      await openThread(tester);
      await tester.tap(find.text('Gửi lại'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(api.resendCalls, ['m2']);
      expect(api.sendCalls.single.text, 'Dạ em gửi ạ');
      await closeThread(tester);
    });

    testWidgets('/resend 404 thật (tin không còn) → câu tiếng Việt, không '
        'gửi', (tester) async {
      api.history = [_serverMessage('m1', 'Chào shop'), failedOnServer('m2')];
      api.resendError = const NotFoundException('Message not found.');
      await openThread(tester);
      await tester.tap(find.text('Gửi lại'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(api.sendCalls, isEmpty);
      final m2 = state(tester).messages.firstWhere((m) => m.id == 'm2');
      expect(m2.status, DeliveryStatus.failed);
      expect(m2.error, kResendMessageGone);
      expect(find.text('Message not found.'), findsNothing);
      await closeThread(tester);
    });

    testWidgets('422 channel_send_unsupported khi gửi → nạp lại hội thoại '
        '(khả năng gửi mới)', (tester) async {
      await openThread(tester);
      final before = api.getCalls;
      api.sendError = const ValidationException(
        'Kênh này chưa hỗ trợ gửi tin đi từ Hộp thư.',
        reason: 'channel_send_unsupported',
      );
      await typeAndSend(tester, 'Dạ em gửi ạ');
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(api.getCalls, greaterThan(before));
      await closeThread(tester);
    });

    testWidgets('/resend 422 channel_send_unsupported → hiện lỗi, hết "Gửi '
        'lại"', (tester) async {
      api.history = [_serverMessage('m1', 'Chào shop'), failedOnServer('m2')];
      api.resendError = const ValidationException(
        'Kênh này chưa hỗ trợ gửi tin đi từ Hộp thư.',
        reason: 'channel_send_unsupported',
      );
      await openThread(tester);
      await tester.tap(find.text('Gửi lại'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(api.sendCalls, isEmpty);
      expect(find.byType(AlertDialog), findsNothing);
      expect(
        find.text('Kênh này chưa hỗ trợ gửi tin đi từ Hộp thư.'),
        findsOneWidget,
      );
      expect(find.text('Gửi lại'), findsNothing);
      await closeThread(tester);
    });

    testWidgets('/resend lỗi mạng → vẫn failed, còn "Gửi lại"', (tester) async {
      api.history = [_serverMessage('m1', 'Chào shop'), failedOnServer('m2')];
      api.resendError = const NetworkException('Không có kết nối mạng.');
      await openThread(tester);
      await tester.tap(find.text('Gửi lại'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(api.sendCalls, isEmpty);
      final m2 = state(tester).messages.firstWhere((m) => m.id == 'm2');
      expect(m2.status, DeliveryStatus.failed);
      expect(find.text('Gửi lại'), findsOneWidget);
      await closeThread(tester);
    });
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
}) {
  final minute = int.parse(id.replaceAll(RegExp(r'\D'), ''));
  return Message.fromJson({
    'id': id,
    'from': from,
    'text': text,
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
  List<Message> searchResult = const [];
  bool failNextSend = false;

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
  final sentAttachments = <List<MessageAttachment>>[];
  final uploads = <({String path, String? filename})>[];

  @override
  Future<MessageAttachment> uploadMedia(
    String filePath, {
    String? filename,
  }) async {
    uploads.add((path: filePath, filename: filename));
    final audio = (filename ?? filePath).endsWith('.wav');
    return MessageAttachment(
      url: 'https://x/api/v1/inbox/media/t1/${uploads.length}',
      type: audio ? 'audio' : 'file',
      name: filename ?? filePath,
    );
  }

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
  Future<List<Message>> searchMessages(String id, String query) async =>
      searchResult;

  /// `outbound_capabilities` của hội thoại; null = API cũ thiếu khoá.
  Map<String, dynamic>? capabilities;

  /// Lỗi của lượt `send` kế tiếp (vd 422 `channel_send_unsupported`).
  AppException? sendError;

  final resendCalls = <String>[];
  Object? resendError;

  @override
  Future<Conversation> get(String id) async {
    getCalls++;
    return Conversation(
      id: id,
      channel: Channel.zalo,
      status: ConversationStatus.open,
      customerName: 'Thuý Phạm',
      lastMessage: 'Còn đàn không',
      unread: 2,
      outboundCapabilities: OutboundCapabilities.fromJson(capabilities),
    );
  }

  int getCalls = 0;

  @override
  Future<Message> resend(String id, String messageId) async {
    resendCalls.add(messageId);
    final error = resendError;
    if (error != null) {
      resendError = null;
      throw error;
    }
    return Message.fromJson({
      'id': messageId,
      'from': 'agent',
      'direction': 'out',
      'text': 'Dạ em gửi ạ',
      'status': 'queued',
      'sent_at': DateTime.utc(2026, 1, 1, 8, 2).toIso8601String(),
    });
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
    sentAttachments.add(List.of(attachments));
    final gate = holdSend;
    if (gate != null) {
      holdSend = null;
      await gate.future;
    }
    if (failNextSend) {
      failNextSend = false;
      throw const NetworkException('Không có kết nối mạng.');
    }
    final error = sendError;
    if (error != null) {
      sendError = null;
      throw error;
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
