import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:omni_app/modules/inbox/domain/message.dart';
import 'package:omni_app/modules/inbox/presentation/widgets/message_bubble.dart';

/// Duyệt 26/11/2026 (kiểu iMessage): tin mình gửi CUỐI ghi chữ "Đã gửi / Đã
/// nhận / Đã xem" + giờ, không dấu tích; tin khác không có dòng giờ, chạm vào
/// bong bóng mới hiện giờ + dấu tích.
void main() {
  testWidgets('tin cuối đã nhận: chữ "Đã nhận", không dấu tích', (
    tester,
  ) async {
    await tester.pumpWidget(_bubble(DeliveryStatus.delivered));

    expect(
      find.byKey(const ValueKey('delivery-receipt-delivered')),
      findsOneWidget,
    );
    expect(find.text('Đã nhận'), findsOneWidget);
    expect(find.text('Đã xem'), findsNothing);
    expect(find.byIcon(LucideIcons.checkCheck), findsNothing);
  });

  testWidgets('tin cuối đã xem: chữ "Đã xem" màu chữ phụ, không xanh', (
    tester,
  ) async {
    await tester.pumpWidget(_bubble(DeliveryStatus.read));

    expect(find.byKey(const ValueKey('delivery-receipt-read')), findsOneWidget);
    final label = tester.widget<Text>(find.text('Đã xem'));
    final scheme = Theme.of(tester.element(find.text('Đã xem'))).colorScheme;
    expect(label.style!.color, scheme.onSurfaceVariant);
  });

  testWidgets('tin cuối chưa có biên nhận: "Đã gửi"', (tester) async {
    await tester.pumpWidget(_bubble(DeliveryStatus.sent));

    expect(find.text('Đã gửi'), findsOneWidget);
    expect(find.byIcon(LucideIcons.checkCheck), findsNothing);
  });

  testWidgets('tin gửi cũ hơn: không dòng giờ; chạm mới hiện dấu tích', (
    tester,
  ) async {
    await tester.pumpWidget(
      _bubble(DeliveryStatus.delivered, isLatestOutbound: false),
    );

    expect(find.byIcon(LucideIcons.checkCheck), findsNothing);
    expect(find.text('Đã nhận'), findsNothing);
    await tester.tap(find.text('Xin chào'));
    await tester.pump();
    expect(find.byIcon(LucideIcons.checkCheck), findsOneWidget);
    expect(find.text('Đã nhận'), findsNothing);
  });

  testWidgets('tin đã gửi (một tích) khi chạm vào tin cũ', (tester) async {
    await tester.pumpWidget(
      _bubble(
        DeliveryStatus.sent,
        isLatestOutbound: false,
        isLastInGroup: false,
      ),
    );

    expect(find.byIcon(LucideIcons.check), findsNothing);
    await tester.tap(find.text('Xin chào'));
    await tester.pump();
    expect(find.byIcon(LucideIcons.check), findsOneWidget);
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
