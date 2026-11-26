import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:omni_app/design/tokens/omni_colors.dart';
import 'package:omni_app/modules/inbox/domain/pending_attachment.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/modules/inbox/domain/message.dart';
import 'package:omni_app/modules/inbox/presentation/widgets/message_composer.dart';
import 'package:omni_app/modules/inbox/application/voice_recorder.dart';
import 'package:omni_app/modules/inbox/domain/outbound_capabilities.dart';

class _NoopRecorder implements VoiceRecorder {
  @override
  Future<bool> ensurePermission() async => true;
  @override
  Future<String> newRecordingPath() async => '/tmp/a.wav';
  @override
  Future<void> start(String path) async {}
  @override
  Future<String?> stop() async => '/tmp/a.wav';
  @override
  Future<void> cancel() async {}
  @override
  Future<void> discard(String path) async {}
  @override
  Stream<Duration> get elapsed => const Stream.empty();
  @override
  Future<void> dispose() async {}
}

void main() {
  late List<String> sent;
  late int tasks;

  Widget host({bool reduceMotion = false}) => MaterialApp(
    theme: OmniTheme.light(TargetPlatform.android),
    builder: (c, child) => MediaQuery(
      data: MediaQuery.of(c).copyWith(disableAnimations: reduceMotion),
      child: child!,
    ),
    home: Scaffold(
      body: Column(
        children: [
          const Expanded(child: SizedBox()),
          MessageComposer(
            onSend:
                (
                  String text,
                  List<PendingAttachment> images,
                  Message? replyTo,
                ) async => sent.add(text),
            onPickImages: (_) async => const [],
            onTakePhoto: () async => null,
            onCreateTask: () => tasks++,
            loadTemplates: () async => const ['Dạ còn 15:00 và 16:30 ạ'],
          ),
        ],
      ),
    ),
  );

  setUp(() {
    sent = [];
    tasks = 0;
  });

  // Duyệt 26/11/2026: bỏ nút 👍, bỏ cụm 3 icon xanh và nút › bung công cụ.
  InkResponse sendInk(WidgetTester tester) => tester.widget<InkResponse>(
    find.descendant(
      of: find.byTooltip('Gửi'),
      matching: find.byType(InkResponse),
    ),
  );

  testWidgets('trống → không 👍, nút ↑ mờ; có chữ → ↑ bấm được và gửi', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    expect(find.byTooltip('Gửi like'), findsNothing);
    expect(find.text('👍'), findsNothing);
    expect(find.byTooltip('Ảnh'), findsNothing, reason: 'Ảnh nằm trong menu ⊕');
    expect(find.byTooltip('Hiện công cụ'), findsNothing);
    expect(sendInk(tester).onTap, isNull);

    await tester.enterText(find.byType(TextField), 'chào');
    await tester.pumpAndSettle();
    expect(sendInk(tester).onTap, isNotNull);
    expect(find.byIcon(LucideIcons.arrowUp), findsOneWidget);
    await tester.tap(find.byTooltip('Gửi'));
    await tester.pumpAndSettle();
    expect(sent, ['chào']);
  });

  testWidgets('nút ↑ nền xanh đặc primaryFillOf, icon trắng (sáng và tối)', (
    tester,
  ) async {
    for (final theme in [
      OmniTheme.light(TargetPlatform.android),
      OmniTheme.dark(TargetPlatform.android),
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: Column(
              children: [
                const Expanded(child: SizedBox()),
                MessageComposer(
                  onSend: (text, images, replyTo) async {},
                  onPickImages: (_) async => const [],
                ),
              ],
            ),
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), 'ok');
      // MaterialApp đổi theme có hiệu ứng chuyển màu: chờ xong mới đọc.
      await tester.pump(const Duration(seconds: 1));
      final circle = tester.widget<Container>(
        find
            .ancestor(
              of: find.byIcon(LucideIcons.arrowUp),
              matching: find.byType(Container),
            )
            .first,
      );
      final expected = theme.brightness == Brightness.dark
          ? OmniColors.darkPrimaryFill
          : OmniColors.primary;
      expect((circle.decoration! as BoxDecoration).color, expected);
      expect(
        tester.widget<Icon>(find.byIcon(LucideIcons.arrowUp)).color,
        Colors.white,
      );
    }
  });

  testWidgets('⊕ gộp Ảnh · Máy ảnh · Mẫu trả lời · Tạo việc', (tester) async {
    await tester.pumpWidget(host());
    await tester.tap(find.byTooltip('Thêm'));
    await tester.pumpAndSettle();
    for (final label in ['Ảnh', 'Máy ảnh', 'Mẫu trả lời', 'Tạo việc']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
  });

  testWidgets(
    '+ mở menu Tạo việc · Mẫu trả lời; API cũ thiếu khoá: không Báo giá/'
    'Tệp/Ghi âm',
    (tester) async {
      await tester.pumpWidget(host());
      await tester.tap(find.byTooltip('Thêm'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('composer-tools-menu')), findsOneWidget);
      expect(find.text('Tạo việc'), findsOneWidget);
      expect(find.text('Mẫu trả lời'), findsOneWidget);
      expect(find.text('Báo giá'), findsNothing);
      expect(find.text('Tệp'), findsNothing);
      expect(find.byTooltip('Ghi âm'), findsNothing);
      expect(find.text('Ghi âm'), findsNothing);

      await tester.tap(find.text('Mẫu trả lời'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dạ còn 15:00 và 16:30 ạ'));
      await tester.pumpAndSettle();
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, 'Dạ còn 15:00 và 16:30 ạ');
      expect(sent, isEmpty, reason: 'chèn vào ô, không gửi luôn');
    },
  );

  group('nút Ghi âm theo khả năng gửi của kênh', () {
    OutboundCapabilities caps(String audio) => OutboundCapabilities.fromJson({
      'can_send': true,
      'text': 'native',
      'image': 'native',
      'file': 'native',
      'audio': audio,
      'video': 'native',
    })!;

    Widget voiceHost(OutboundCapabilities? capabilities) => MaterialApp(
      theme: OmniTheme.light(TargetPlatform.android),
      home: Scaffold(
        body: Column(
          children: [
            const Expanded(child: SizedBox()),
            MessageComposer(
              capabilities: capabilities,
              onSend: (text, images, replyTo) async {},
              onPickImages: (_) async => const [],
              onTakePhoto: () async => null,
              voiceRecorder: _NoopRecorder(),
              onSendVoice: (_) async {},
            ),
          ],
        ),
      ),
    );

    testWidgets('audio native + onSendVoice → mic ở cuối hàng, sau ô nhập', (
      tester,
    ) async {
      await tester.pumpWidget(voiceHost(caps('native')));
      expect(find.byTooltip('Ghi âm'), findsOneWidget);
      expect(
        tester.getRect(find.byTooltip('Ghi âm')).left,
        greaterThanOrEqualTo(tester.getRect(find.byType(TextField)).right),
      );
      expect(find.byTooltip('Gửi'), findsNothing, reason: 'ô trống = mic');
    });

    testWidgets('audio link (Zalo OA) → vẫn có', (tester) async {
      await tester.pumpWidget(voiceHost(caps('link')));
      expect(find.byTooltip('Ghi âm'), findsOneWidget);
    });

    testWidgets('audio none → không có', (tester) async {
      await tester.pumpWidget(voiceHost(caps('none')));
      expect(find.byTooltip('Ghi âm'), findsNothing);
    });

    testWidgets('API cũ thiếu khoá (capabilities null) → không có', (
      tester,
    ) async {
      await tester.pumpWidget(voiceHost(null));
      expect(find.byTooltip('Ghi âm'), findsNothing);
    });
  });

  testWidgets('Tạo việc gọi onCreateTask', (tester) async {
    await tester.pumpWidget(host());
    await tester.tap(find.byTooltip('Thêm'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tạo việc'));
    await tester.pumpAndSettle();
    expect(tasks, 1);
  });

  testWidgets('giảm chuyển động: mở menu không có hoạt ảnh', (tester) async {
    await tester.pumpWidget(host(reduceMotion: true));
    await tester.tap(find.byTooltip('Thêm'));
    await tester.pump();
    expect(tester.hasRunningAnimations, isFalse);
    expect(find.text('Tạo việc'), findsOneWidget);
  });

  testWidgets('gõ 👍 (từ bảng cảm xúc) rồi bấm Gửi: gửi đúng chữ, xoá ô', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    await tester.enterText(find.byType(TextField), '👍');
    await tester.pump();
    await tester.tap(find.byTooltip('Gửi'));
    await tester.pumpAndSettle();

    expect(sent, ['👍']);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
  });

  testWidgets('menu ẩn Tạo việc khi không có onCreateTask', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: OmniTheme.light(TargetPlatform.android),
        home: Scaffold(
          body: Column(
            children: [
              const Expanded(child: SizedBox()),
              MessageComposer(
                onSend: (text, images, replyTo) async {},
                onPickImages: (_) async => const [],
                loadTemplates: () async => const ['x'],
              ),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip('Thêm'));
    await tester.pumpAndSettle();
    expect(find.text('Tạo việc'), findsNothing);
    expect(find.text('Mẫu trả lời'), findsOneWidget);
  });

  testWidgets('chạm ngoài menu thì menu đóng', (tester) async {
    await tester.pumpWidget(host());
    await tester.tap(find.byTooltip('Thêm'));
    await tester.pumpAndSettle();
    expect(find.text('Tạo việc'), findsOneWidget);

    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();
    expect(find.text('Tạo việc'), findsNothing);
  });

  testWidgets(
    '360px: không tràn, ⊕ không đè ô nhập, mặt cười trong ô, chạm 44',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(host());
      expect(tester.takeException(), isNull);

      final add = tester.getRect(find.byTooltip('Thêm'));
      final input = tester.getRect(find.byType(TextField));
      expect(add.right, lessThanOrEqualTo(input.left));
      // Mặt cười NẰM TRONG ô nhập.
      final smile = tester.getRect(find.byTooltip('Biểu tượng cảm xúc'));
      expect(smile.left, greaterThanOrEqualTo(input.left));
      expect(smile.right, lessThanOrEqualTo(input.right));
      for (final tip in ['Thêm', 'Gửi']) {
        final r = tester.getRect(find.byTooltip(tip));
        expect(r.width, greaterThanOrEqualTo(44), reason: tip);
        expect(r.height, greaterThanOrEqualTo(44), reason: tip);
      }
      final emoji = tester.getRect(find.byTooltip('Biểu tượng cảm xúc'));
      expect(emoji.width, greaterThanOrEqualTo(44));
      expect(emoji.right, lessThanOrEqualTo(360));

      await tester.enterText(find.byType(TextField), 'chào');
      await tester.pumpAndSettle();
      final send = tester.getRect(find.byTooltip('Gửi'));
      expect(send.width, greaterThanOrEqualTo(44));
      expect(send.height, greaterThanOrEqualTo(44));
      expect(send.right, lessThanOrEqualTo(360));
      expect(tester.takeException(), isNull);
    },
  );
}
