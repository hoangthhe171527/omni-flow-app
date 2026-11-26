import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:omni_app/core/domain/channel.dart';
import 'package:omni_app/design/components/components.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/design/tokens/tokens.dart';
import 'package:omni_app/modules/inbox/domain/conversation.dart';
import 'package:omni_app/modules/inbox/presentation/widgets/conversation_row.dart';
import 'package:omni_app/modules/inbox/presentation/widgets/message_composer.dart';

/// Quy ước hộp thư (duyệt 26/11/2026): chưa đọc = một chấm đỏ đầu dòng; khẩn
/// và quá hạn trả lời không còn chấm giữa câu mà giờ đổi sang đỏ "cần chú
/// ý"; mẫu trả lời chèn câu vào ô nhập.
void main() {
  setUpAll(() => initializeDateFormatting('vi_VN'));

  Widget host(Widget child) => MaterialApp(
    theme: OmniTheme.light(TargetPlatform.android),
    home: Scaffold(body: child),
  );

  Conversation conversation({
    int unread = 0,
    bool urgent = false,
    Duration ago = const Duration(minutes: 1),
  }) => Conversation(
    id: 'c1',
    channel: Channel.zalo,
    status: ConversationStatus.parse('open'),
    customerName: 'Nguyễn Thị Lan',
    lastMessage: 'Chị muốn lắp thêm 2 phòng',
    lastMessageAt: DateTime.now().subtract(ago),
    unread: unread,
    urgent: urgent,
  );

  /// Chấm tròn nằm trong Tooltip (kiểu cũ: chấm khẩn/quá hạn giữa câu).
  int tooltipDots(WidgetTester tester) => tester
      .widgetList<Container>(
        find.descendant(
          of: find.byType(Tooltip),
          matching: find.byType(Container),
        ),
      )
      .map((c) => c.decoration)
      .whereType<BoxDecoration>()
      .where((d) => d.shape == BoxShape.circle)
      .length;

  /// Màu chữ giờ ở góc phải dòng (nằm trong Tooltip khi cần chú ý).
  Color? stampColor(WidgetTester tester) => tester
      .widget<Text>(
        find.descendant(of: find.byType(Tooltip), matching: find.byType(Text)),
      )
      .style
      ?.color;

  testWidgets('chưa đọc: chỉ hiện chấm đỏ, không hiện số', (tester) async {
    await tester.pumpWidget(
      host(
        ConversationRow(conversation: conversation(unread: 3), onTap: () {}),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(OmniUnreadDot), findsOneWidget);
    expect(find.bySemanticsLabel('Chưa đọc'), findsOneWidget);
    expect(find.text('3'), findsNothing);
  });

  testWidgets('khẩn: giờ đỏ, không chấm giữa câu', (tester) async {
    await tester.pumpWidget(
      host(
        ConversationRow(
          conversation: conversation(unread: 1, urgent: true),
          onTap: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tooltipDots(tester), 0);
    expect(stampColor(tester), OmniColors.attentionDot);
  });

  testWidgets('quá hạn trả lời: giờ đỏ, không chấm giữa câu', (tester) async {
    await tester.pumpWidget(
      host(
        ConversationRow(
          conversation: conversation(
            unread: 1,
            ago: const Duration(minutes: 40),
          ),
          onTap: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tooltipDots(tester), 0);
    expect(stampColor(tester), OmniColors.attentionDot);
  });

  testWidgets('mẫu trả lời: chọn là chèn vào ô, không gửi', (tester) async {
    var sent = 0;
    await tester.pumpWidget(
      host(
        Column(
          children: [
            const Expanded(child: SizedBox()),
            MessageComposer(
              loadTemplates: () async => const ['Em gửi báo giá ạ'],
              onSend: (text, images, replyTo) async => sent++,
              onPickImages: (_) async => const [],
            ),
          ],
        ),
      ),
    );

    await tester.tap(find.byTooltip('Thêm'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mẫu trả lời'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Em gửi báo giá ạ'));
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, 'Em gửi báo giá ạ');
    expect(sent, 0);
  });
}
