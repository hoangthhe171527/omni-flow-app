import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:omni_app/core/domain/channel.dart';
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

      final hold = await tester.startGesture(
        tester.getCenter(find.text('Lan Anh')),
      );
      await tester.pump(
        ConversationRow.peekDelay + const Duration(milliseconds: 10),
      );
      await hold.up();
      await tester.pumpAndSettle();
      expect(peeks, 1);
      expect(taps, 1, reason: 'lần thả sau 300ms vẫn là một chạm');
    },
  );
}
