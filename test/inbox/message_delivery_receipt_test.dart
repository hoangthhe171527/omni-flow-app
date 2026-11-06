import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/modules/inbox/domain/message.dart';
import 'package:omni_app/modules/inbox/presentation/widgets/message_bubble.dart';

void main() {
  testWidgets('shows a grey double check when the message is delivered', (
    tester,
  ) async {
    await tester.pumpWidget(_bubble(DeliveryStatus.delivered));

    expect(
      find.byKey(const ValueKey('delivery-receipt-delivered')),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.done_all_rounded), findsOneWidget);
    expect(find.text('Đã nhận'), findsOneWidget);
    expect(find.text('Đã xem'), findsNothing);
  });

  testWidgets(
    'turns the double check blue and says read only for read status',
    (tester) async {
      await tester.pumpWidget(_bubble(DeliveryStatus.read));

      expect(
        find.byKey(const ValueKey('delivery-receipt-read')),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.done_all_rounded), findsOneWidget);
      expect(find.text('Đã xem'), findsOneWidget);
    },
  );

  testWidgets('keeps a single check before a delivery receipt arrives', (
    tester,
  ) async {
    await tester.pumpWidget(_bubble(DeliveryStatus.sent));

    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    expect(find.text('Đã gửi'), findsOneWidget);
    expect(find.byIcon(Icons.done_all_rounded), findsNothing);
  });

  testWidgets('chỉ tin gửi mới nhất ghi chữ trạng thái, tin cũ chỉ còn tích', (
    tester,
  ) async {
    await tester.pumpWidget(
      _bubble(DeliveryStatus.delivered, isLatestOutbound: false),
    );

    expect(find.byIcon(Icons.done_all_rounded), findsOneWidget);
    expect(find.text('Đã nhận'), findsNothing);
  });

  testWidgets('tin giữa cụm ẩn giờ, chạm vào bong bóng mới hiện', (
    tester,
  ) async {
    await tester.pumpWidget(
      _bubble(
        DeliveryStatus.delivered,
        isLatestOutbound: false,
        isLastInGroup: false,
      ),
    );

    expect(find.byIcon(Icons.done_all_rounded), findsNothing);
    await tester.tap(find.text('Xin chào'));
    await tester.pump();
    expect(find.byIcon(Icons.done_all_rounded), findsOneWidget);
  });
}

Widget _bubble(
  DeliveryStatus status, {
  bool isLatestOutbound = true,
  bool isLastInGroup = true,
}) => MaterialApp(
  home: Scaffold(
    body: MessageBubble(
      isLatestOutbound: isLatestOutbound,
      isLastInGroup: isLastInGroup,
      message: Message(
        id: 'receipt-message',
        author: MessageAuthor.agent,
        text: 'Xin chào',
        sentAt: null,
        status: status,
      ),
    ),
  ),
);
