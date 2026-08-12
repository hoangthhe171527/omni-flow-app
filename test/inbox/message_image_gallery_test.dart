import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/modules/inbox/domain/message.dart';
import 'package:omni_app/modules/inbox/presentation/widgets/message_bubble.dart';

void main() {
  testWidgets('groups images and opens a swipeable viewer', (tester) async {
    final attachments = List.generate(
      5,
      (index) => MessageAttachment(
        url: 'https://example.invalid/$index.jpg',
        type: 'image/jpeg',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessageBubble(
            message: Message(
              id: 'message-1',
              author: MessageAuthor.agent,
              text: '',
              sentAt: null,
              attachments: attachments,
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('message-image-gallery')), findsOneWidget);
    expect(find.text('+1'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('message-image-tile-3')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('message-image-viewer')), findsOneWidget);
    expect(find.text('4 / 5'), findsOneWidget);

    await tester.fling(find.byType(PageView), const Offset(-700, 0), 1000);
    await tester.pumpAndSettle();

    expect(find.text('5 / 5'), findsOneWidget);
  });
}
