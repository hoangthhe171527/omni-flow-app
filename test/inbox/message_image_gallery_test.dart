import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/modules/inbox/domain/message.dart';
import 'package:omni_app/modules/inbox/presentation/widgets/message_bubble.dart';

void main() {
  testWidgets('stacks images and swipes inline before opening the viewer', (
    tester,
  ) async {
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
    expect(find.text('1 / 5'), findsOneWidget);

    final inlinePages = find.byKey(
      const ValueKey('message-image-inline-page-view'),
    );
    final pageView = tester.widget<PageView>(inlinePages);
    expect(pageView.controller?.viewportFraction, 0.88);
    expect(find.byKey(const ValueKey('message-image-card-1')), findsOneWidget);

    await tester.drag(inlinePages, const Offset(-220, 0));
    await tester.pumpAndSettle();
    expect(find.text('2 / 5'), findsOneWidget);

    await tester.drag(inlinePages, const Offset(220, 0));
    await tester.pumpAndSettle();
    expect(find.text('1 / 5'), findsOneWidget);

    await tester.drag(inlinePages, const Offset(-220, 0));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('message-image-tile-1')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('message-image-viewer')), findsOneWidget);
    expect(find.text('2 / 5'), findsOneWidget);

    await tester.fling(find.byType(PageView), const Offset(-700, 0), 1000);
    await tester.pumpAndSettle();

    expect(find.text('3 / 5'), findsOneWidget);
  });
}
