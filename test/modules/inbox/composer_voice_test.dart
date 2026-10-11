import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/modules/inbox/application/voice_recorder.dart';
import 'package:omni_app/modules/inbox/domain/outbound_capabilities.dart';
import 'package:omni_app/modules/inbox/domain/pending_attachment.dart';
import 'package:omni_app/modules/inbox/presentation/widgets/composer_snack_bar.dart';
import 'package:omni_app/modules/inbox/presentation/widgets/message_composer.dart';

import '../../support/fake_voice_recorder.dart';

void main() {
  final native = OutboundCapabilities.fromJson(const {
    'can_send': true,
    'text': 'native',
    'image': 'native',
    'file': 'native',
    'audio': 'native',
    'video': 'native',
  });
  // Zalo OA: `audio: link`.
  final zaloOa = OutboundCapabilities.fromJson(const {
    'can_send': true,
    'text': 'native',
    'image': 'native',
    'file': 'docs_only',
    'audio': 'link',
    'video': 'link',
  });
  final noAudio = OutboundCapabilities.fromJson(const {
    'can_send': true,
    'text': 'native',
    'image': 'native',
    'file': 'native',
    'audio': 'none',
    'video': 'none',
  });

  late FakeVoiceRecorder recorder;
  late List<PendingAttachment> voices;
  late bool failSend;
  // Giữ qua các lần pumpWidget: composer được cập nhật, không dựng lại.
  late GlobalKey key;

  setUp(() {
    recorder = FakeVoiceRecorder();
    voices = [];
    failSend = false;
    key = GlobalKey();
  });

  Widget composer({
    OutboundCapabilities? capabilities,
    bool warn = false,
    bool withVoice = true,
    bool withRecorder = true,
  }) => MessageComposer(
    capabilities: capabilities,
    onSend: (text, attachments, replyTo) async {},
    onPickImages: (_) async => const [],
    onTakePhoto: () async => null,
    voiceRecorder: withRecorder ? recorder : null,
    warnVoiceAsLink: warn,
    onSendVoice: withVoice
        ? (voice) async {
            if (failSend) throw StateError('mạng');
            voices.add(voice);
          }
        : null,
  );

  Widget host({
    OutboundCapabilities? capabilities,
    bool warn = false,
    bool reduceMotion = false,
    bool withVoice = true,
    bool mounted = true,
    bool withRecorder = true,
  }) {
    return MaterialApp(
      theme: OmniTheme.light(TargetPlatform.android),
      builder: (c, child) => MediaQuery(
        data: MediaQuery.of(c).copyWith(disableAnimations: reduceMotion),
        child: child!,
      ),
      home: Scaffold(
        body: ComposerSnackBarScope(
          barKey: key,
          child: Column(
            children: [
              const Expanded(child: SizedBox()),
              if (mounted)
                KeyedSubtree(
                  key: key,
                  child: composer(
                    capabilities: capabilities ?? native,
                    warn: warn,
                    withVoice: withVoice,
                    withRecorder: withRecorder,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> tapMic(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Ghi âm'));
    await tester.pump();
    await tester.pump();
  }

  group('nút Ghi âm', () {
    testWidgets('có khi audio native + onSendVoice', (tester) async {
      await tester.pumpWidget(host());
      expect(find.byTooltip('Ghi âm'), findsOneWidget);
      final r = tester.getRect(find.byTooltip('Ghi âm'));
      expect(r.width, greaterThanOrEqualTo(44));
      expect(r.height, greaterThanOrEqualTo(44));
    });

    testWidgets('không có khi audio none', (tester) async {
      await tester.pumpWidget(host(capabilities: noAudio));
      expect(find.byTooltip('Ghi âm'), findsNothing);
    });

    testWidgets('không có khi không có onSendVoice', (tester) async {
      await tester.pumpWidget(host(withVoice: false));
      expect(find.byTooltip('Ghi âm'), findsNothing);
    });

    testWidgets('gõ chữ thì mic thu cùng cụm công cụ', (tester) async {
      await tester.pumpWidget(host());
      await tester.enterText(find.byType(TextField), 'chào');
      await tester.pumpAndSettle();
      expect(find.byTooltip('Ghi âm').hitTestable(), findsNothing);
      expect(find.byTooltip('Hiện công cụ'), findsOneWidget);
    });
  });

  group('luồng ghi', () {
    testWidgets('mic → start .wav, 00:00 → 00:03, Gửi → onSendVoice(voice)', (
      tester,
    ) async {
      await tester.pumpWidget(host());
      await tapMic(tester);

      expect(recorder.starts, ['/tmp/ghi-am-20261010-090507.wav']);
      expect(find.text('00:00'), findsOneWidget);
      // Đang ghi: ô nhập và các nút khác bị thay bằng thanh ghi.
      expect(find.byType(TextField), findsNothing);
      expect(find.byTooltip('Thêm'), findsNothing);

      recorder.tick(const Duration(seconds: 3, milliseconds: 200));
      await tester.pump();
      expect(find.text('00:03'), findsOneWidget);

      await tester.tap(find.byTooltip('Gửi ghi âm'));
      await tester.pump();
      await tester.pump();

      expect(recorder.stops, 1);
      expect(voices, hasLength(1));
      expect(voices.single.kind, PendingKind.voice);
      expect(voices.single.path, '/tmp/ghi-am-20261010-090507.wav');
      expect(voices.single.name, 'ghi-am-20261010-090507.wav');
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byTooltip('Gửi ghi âm'), findsNothing);
    });

    testWidgets('Huỷ → cancel, không gửi', (tester) async {
      await tester.pumpWidget(host());
      await tapMic(tester);
      recorder.tick(const Duration(seconds: 4));
      await tester.pump();

      await tester.tap(find.byTooltip('Huỷ ghi âm'));
      await tester.pump();
      await tester.pump();

      expect(recorder.cancels, 1);
      expect(voices, isEmpty);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('quyền bị từ chối → báo, không start', (tester) async {
      recorder.permission = false;
      await tester.pumpWidget(host());
      await tapMic(tester);

      expect(recorder.starts, isEmpty);
      expect(
        find.text('Chưa có quyền micro — bật trong Cài đặt để ghi âm.'),
        findsOneWidget,
      );
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('dưới 1 giây → "Ghi âm quá ngắn.", không gửi', (tester) async {
      await tester.pumpWidget(host());
      await tapMic(tester);
      recorder.tick(const Duration(milliseconds: 600));
      await tester.pump();

      await tester.tap(find.byTooltip('Gửi ghi âm'));
      await tester.pump();
      await tester.pump();

      expect(voices, isEmpty);
      expect(recorder.cancels, 1);
      expect(find.text('Ghi âm quá ngắn.'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('5:00 → tự dừng, giữ thanh, chưa gửi; Gửi sau đó gửi', (
      tester,
    ) async {
      await tester.pumpWidget(host());
      await tapMic(tester);
      recorder.tick(const Duration(minutes: 5));
      await tester.pump();
      await tester.pump();

      expect(recorder.stops, 1);
      expect(voices, isEmpty);
      expect(find.text('05:00'), findsOneWidget);
      expect(find.byTooltip('Gửi ghi âm'), findsOneWidget);
      expect(find.textContaining('tối đa 5 phút'), findsOneWidget);

      // Nhịp trễ sau khi dừng không đổi đồng hồ.
      recorder.tick(const Duration(minutes: 5, seconds: 1));
      await tester.pump();
      expect(find.text('05:00'), findsOneWidget);

      await tester.tap(find.byTooltip('Gửi ghi âm'));
      await tester.pump();
      await tester.pump();
      expect(recorder.stops, 1, reason: 'đã dừng, không dừng lại lần nữa');
      expect(voices, hasLength(1));
    });

    testWidgets('gửi lỗi → giữ thanh để gửi lại', (tester) async {
      failSend = true;
      await tester.pumpWidget(host());
      await tapMic(tester);
      recorder.tick(const Duration(seconds: 2));
      await tester.pump();

      await tester.tap(find.byTooltip('Gửi ghi âm'));
      await tester.pump();
      await tester.pump();
      expect(voices, isEmpty);
      expect(find.byTooltip('Gửi ghi âm'), findsOneWidget);

      failSend = false;
      await tester.tap(find.byTooltip('Gửi ghi âm'));
      await tester.pump();
      await tester.pump();
      expect(voices, hasLength(1));
      expect(recorder.stops, 1);
    });

    testWidgets('gửi xong → xoá tệp ghi; gửi lỗi → giữ tệp', (tester) async {
      failSend = true;
      await tester.pumpWidget(host());
      await tapMic(tester);
      recorder.tick(const Duration(seconds: 2));
      await tester.pump();

      await tester.tap(find.byTooltip('Gửi ghi âm'));
      await tester.pump();
      await tester.pump();
      expect(recorder.discards, isEmpty, reason: 'lỗi: giữ tệp để gửi lại');

      failSend = false;
      await tester.tap(find.byTooltip('Gửi ghi âm'));
      await tester.pump();
      await tester.pump();
      expect(voices, hasLength(1));
      expect(recorder.discards, ['/tmp/ghi-am-20261010-090507.wav']);
    });

    testWidgets('xoá tệp lỗi → vẫn đóng thanh, không ném', (tester) async {
      recorder.failDiscard = true;
      await tester.pumpWidget(host());
      await tapMic(tester);
      recorder.tick(const Duration(seconds: 2));
      await tester.pump();

      await tester.tap(find.byTooltip('Gửi ghi âm'));
      await tester.pump();
      await tester.pump();
      expect(voices, hasLength(1));
      expect(recorder.discards, hasLength(1));
      expect(tester.takeException(), isNull);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('Gửi lúc đang tự dừng ở 5:00 → chờ tệp chốt xong rồi gửi', (
      tester,
    ) async {
      final gate = Completer<String?>();
      recorder.stopGate = gate;
      await tester.pumpWidget(host());
      await tapMic(tester);
      recorder.tick(const Duration(minutes: 5));
      await tester.pump();
      expect(recorder.stops, 1);

      await tester.tap(find.byTooltip('Gửi ghi âm'));
      await tester.pump();
      await tester.pump();
      expect(voices, isEmpty, reason: 'tệp chưa chốt, chưa được gửi');

      gate.complete('/tmp/ghi-am-xong.wav');
      await tester.pump();
      await tester.pump();
      expect(recorder.stops, 1);
      expect(voices, hasLength(1));
      expect(voices.single.path, '/tmp/ghi-am-xong.wav');
    });

    testWidgets('mất onSendVoice khi đang ghi → huỷ lượt ghi', (tester) async {
      await tester.pumpWidget(host());
      await tapMic(tester);
      recorder.tick(const Duration(seconds: 2));
      await tester.pump();

      await tester.pumpWidget(host(withVoice: false));
      await tester.pump();
      expect(recorder.cancels, 1);
      expect(find.byTooltip('Gửi ghi âm'), findsNothing);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('mất voiceRecorder khi đang ghi → huỷ trên máy ghi cũ', (
      tester,
    ) async {
      await tester.pumpWidget(host());
      await tapMic(tester);

      await tester.pumpWidget(host(withRecorder: false));
      await tester.pump();
      expect(recorder.cancels, 1);
      expect(find.byTooltip('Gửi ghi âm'), findsNothing);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('gỡ composer khi đang ghi → cancel', (tester) async {
      await tester.pumpWidget(host());
      await tapMic(tester);
      expect(recorder.starts, hasLength(1));

      await tester.pumpWidget(host(mounted: false));
      await tester.pump();
      expect(recorder.cancels, 1);
    });
  });

  group('Zalo OA (audio: link)', () {
    testWidgets('hỏi trước lượt đầu; Huỷ → không start; đồng ý → start; '
        'lần sau không hỏi lại', (tester) async {
      await tester.pumpWidget(host(capabilities: zaloOa, warn: true));

      await tester.tap(find.byTooltip('Ghi âm'));
      await tester.pumpAndSettle();
      expect(find.textContaining('gửi dưới dạng đường link'), findsOneWidget);
      await tester.tap(find.text('Huỷ'));
      await tester.pumpAndSettle();
      expect(recorder.starts, isEmpty);

      await tester.tap(find.byTooltip('Ghi âm'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Vẫn ghi âm'));
      await tester.pump();
      await tester.pump();
      // Hộp thoại mờ dần; không pumpAndSettle vì chấm đỏ nhấp nháy mãi.
      await tester.pump(const Duration(milliseconds: 400));
      expect(recorder.starts, hasLength(1));

      await tester.tap(find.byTooltip('Huỷ ghi âm'));
      await tester.pump();
      await tester.pump();

      await tester.tap(find.byTooltip('Ghi âm'));
      await tester.pump();
      await tester.pump();
      expect(find.textContaining('gửi dưới dạng đường link'), findsNothing);
      expect(recorder.starts, hasLength(2));
    });

    testWidgets('kênh native: không hỏi', (tester) async {
      await tester.pumpWidget(host());
      await tapMic(tester);
      expect(find.textContaining('đường link'), findsNothing);
      expect(recorder.starts, hasLength(1));
    });
  });

  testWidgets('giảm chuyển động: chấm đỏ không chạy hoạt ảnh lặp', (
    tester,
  ) async {
    await tester.pumpWidget(host(reduceMotion: true));
    await tapMic(tester);
    await tester.pump();
    expect(find.byTooltip('Huỷ ghi âm'), findsOneWidget);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('có chuyển động: chấm đỏ nhấp nháy', (tester) async {
    await tester.pumpWidget(host());
    await tapMic(tester);
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.hasRunningAnimations, isTrue);
    // Gỡ trước khi kết thúc (hoạt ảnh lặp).
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('chấm đỏ: giữ một Animation qua các lần dựng lại', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    await tapMic(tester);
    Animation<double> opacity() => tester
        .widget<FadeTransition>(
          find
              .ancestor(
                of: find.byKey(const ValueKey('voice-record-dot')),
                matching: find.byType(FadeTransition),
              )
              .first,
        )
        .opacity;
    final first = opacity();
    recorder.tick(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 100));
    expect(opacity(), same(first));
    await tester.pumpWidget(const SizedBox());
  });

  test('RecordVoiceRecorder.discard xoá tệp; tệp không có thì thôi', () async {
    final dir = await Directory.systemTemp.createTemp('voice-discard');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}${Platform.pathSeparator}a.wav');
    await file.writeAsBytes([1, 2, 3]);
    final r = RecordVoiceRecorder();
    await r.discard(file.path);
    expect(await file.exists(), isFalse);
    await r.discard(file.path);
  });

  testWidgets('giao diện tối: thanh ghi dựng không lỗi, chấm dùng màu lỗi', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: OmniTheme.dark(TargetPlatform.android),
        builder: (c, child) => MediaQuery(
          data: MediaQuery.of(c).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: Scaffold(
          body: Column(
            children: [
              const Expanded(child: SizedBox()),
              composer(capabilities: native),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tapMic(tester);
    final scheme = Theme.of(
      tester.element(find.byTooltip('Huỷ ghi âm')),
    ).colorScheme;
    final dot = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey('voice-record-dot')),
    );
    expect((dot.decoration as BoxDecoration).color, scheme.error);
    expect(tester.takeException(), isNull);
  });

  testWidgets('360px: không tràn khi có mic; thanh ghi cũng không tràn', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(host(reduceMotion: true));
    expect(tester.takeException(), isNull);
    final mic = tester.getRect(find.byTooltip('Ghi âm'));
    final input = tester.getRect(find.byType(TextField));
    expect(mic.right, lessThanOrEqualTo(input.left));
    expect(input.width, greaterThanOrEqualTo(100));

    await tapMic(tester);
    expect(tester.takeException(), isNull);
    for (final tip in ['Huỷ ghi âm', 'Gửi ghi âm']) {
      final r = tester.getRect(find.byTooltip(tip));
      expect(r.width, greaterThanOrEqualTo(44), reason: tip);
      expect(r.right, lessThanOrEqualTo(360), reason: tip);
    }
  });

  testWidgets('snackbar nổi phía trên composer, không che nút', (tester) async {
    recorder.permission = false;
    await tester.pumpWidget(host());
    await tapMic(tester);
    await tester.pumpAndSettle();

    // Rect của SnackBar gồm cả lề; đo phần vẽ (Material).
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
    // Nút trong composer vẫn bấm được khi snackbar đang hiện.
    expect(find.byTooltip('Ghi âm').hitTestable(), findsOneWidget);
  });
}
