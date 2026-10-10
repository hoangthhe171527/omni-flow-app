import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:omni_app/core/domain/channel.dart';
import 'package:omni_app/design/tokens/omni_colors.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/modules/inbox/domain/conversation.dart';
import 'package:omni_app/modules/inbox/presentation/widgets/conversation_row.dart';

void main() {
  setUpAll(() => initializeDateFormatting('vi_VN'));

  const lan = Conversation(
    id: 'c1',
    channel: Channel.zalo,
    status: ConversationStatus.open,
    customerName: 'Lan Anh',
    lastMessage: 'Còn lịch chiều nay không ạ?',
    unread: 2,
    sourceName: 'Zalo OA · Trung Nguyên',
    tags: ['Đặt lịch'],
    assigneeId: 'u1',
    assigneeName: 'Hoàng Trần',
  );

  Future<void> pump(
    WidgetTester tester, {
    VoidCallback? onTap,
    VoidCallback? onPeek,
    Conversation c = lan,
  }) => tester.pumpWidget(
    MaterialApp(
      theme: OmniTheme.light(TargetPlatform.android),
      home: Scaffold(
        body: ConversationRow(
          conversation: c,
          onTap: onTap ?? () {},
          onPeek: onPeek,
        ),
      ),
    ),
  );

  testWidgets('dòng nguồn OA · Trung Nguyên, chấm nhãn, người phụ trách', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('OA'), findsOneWidget);
    expect(find.textContaining('Trung Nguyên'), findsOneWidget);
    expect(find.bySemanticsLabel('Nhãn: Đặt lịch'), findsOneWidget);
    expect(find.text('HT'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
  });

  test(
    'màu chữ nguồn mọi kênh đạt 4.5:1 (sáng trên trắng, tối trên nền tối)',
    () {
      double contrast(Color a, Color b) {
        final x = a.computeLuminance(), y = b.computeLuminance();
        final hi = x > y ? x : y, lo = x > y ? y : x;
        return (hi + 0.05) / (lo + 0.05);
      }

      for (final ch in Channel.values) {
        final m = ch.meta;
        expect(
          contrast(m.textColorOf(Brightness.light), Colors.white),
          greaterThanOrEqualTo(4.5),
          reason: ch.name,
        );
        expect(
          contrast(m.textColorOf(Brightness.dark), OmniColors.darkCard),
          greaterThanOrEqualTo(4.5),
          reason: ch.name,
        );
      }
    },
  );

  testWidgets('không nhãn → không chấm; chưa gán → –', (tester) async {
    await pump(
      tester,
      c: const Conversation(
        id: 'c2',
        channel: Channel.web,
        status: ConversationStatus.open,
        customerName: 'Phạm Duy',
        lastMessage: 'Giá gói tháng?',
        unread: 0,
      ),
    );
    expect(find.bySemanticsLabel(RegExp('^Nhãn:')), findsNothing);
    expect(find.text('–'), findsOneWidget);
  });

  testWidgets(
    'giữ 450ms → onPeek, không onTap; giữ 300ms rồi thả → không peek',
    (tester) async {
      var peeks = 0, taps = 0;
      await pump(tester, onTap: () => taps++, onPeek: () => peeks++);

      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Lan Anh')),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await gesture.up();
      await tester.pump();
      expect(peeks, 0);
      expect(taps, 1, reason: 'thả sau 300ms vẫn là một chạm');
      taps = 0;

      final hold = await tester.startGesture(
        tester.getCenter(find.text('Lan Anh')),
      );
      await tester.pump(
        ConversationRow.peekDelay + const Duration(milliseconds: 10),
      );
      await hold.up();
      await tester.pumpAndSettle();
      expect(peeks, 1);
      expect(taps, 0, reason: 'giữ đủ 450ms không phát onTap');
    },
  );

  double scaleOf(WidgetTester tester) =>
      tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale;

  testWidgets('kéo/cuộn bắt đầu trên dòng: không co, không peek', (
    tester,
  ) async {
    var peeks = 0;
    await pump(tester, onPeek: () => peeks++);
    final g = await tester.startGesture(tester.getCenter(find.text('Lan Anh')));
    await tester.pump(const Duration(milliseconds: 50));
    await g.moveBy(const Offset(0, -60));
    await tester.pump(const Duration(milliseconds: 200));
    expect(scaleOf(tester), 1);
    await g.up();
    await tester.pumpAndSettle();
    expect(scaleOf(tester), 1);
    expect(peeks, 0);
  });

  testWidgets('giữ quá 100ms thì co; thả thì trả lại', (tester) async {
    await pump(tester, onPeek: () {});
    final g = await tester.startGesture(tester.getCenter(find.text('Lan Anh')));
    await tester.pump(const Duration(milliseconds: 50));
    expect(scaleOf(tester), 1);
    await tester.pump(const Duration(milliseconds: 100));
    expect(scaleOf(tester), lessThan(1));
    await g.up();
    await tester.pumpAndSettle();
    expect(scaleOf(tester), 1);
  });

  testWidgets('giảm chuyển động: không co', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: OmniTheme.light(TargetPlatform.android),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: Scaffold(
          body: ConversationRow(conversation: lan, onTap: () {}, onPeek: () {}),
        ),
      ),
    );
    final g = await tester.startGesture(tester.getCenter(find.text('Lan Anh')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(scaleOf(tester), 1);
    await g.up();
    await tester.pumpAndSettle();
  });
}
