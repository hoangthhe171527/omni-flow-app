import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/modules/inbox/domain/message.dart';
import 'package:omni_app/modules/inbox/presentation/widgets/message_bubble.dart';
import 'package:omni_app/modules/inbox/presentation/widgets/message_images.dart';

Message _message({String text = '', required List<MessageAttachment> atts}) =>
    Message(
      id: 'm-sticker',
      author: MessageAuthor.customer,
      text: text,
      sentAt: null,
      attachments: atts,
    );

void main() {
  test('sticker attachment is not an image and keeps sticker_id', () {
    final a = MessageAttachment.fromJson({
      'url': 'https://example.invalid/like.png',
      'type': 'sticker',
      'sticker_id': '369239263222822',
    });
    expect(a.isSticker, isTrue);
    expect(a.isImage, isFalse);
    expect(a.stickerId, '369239263222822');
    expect(a.toJson()['sticker_id'], '369239263222822');

    final img = MessageAttachment.fromJson({
      'url': 'https://example.invalid/a.jpg',
      'type': 'image',
    });
    expect(img.isSticker, isFalse);
    expect(img.isImage, isTrue);
  });

  testWidgets('sticker-only message renders bare at 112 with no bubble', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessageBubble(
            message: _message(
              atts: const [
                MessageAttachment(
                  url: 'https://example.invalid/like.png',
                  type: 'sticker',
                  stickerId: '369239263222822',
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.byType(MessageStickers), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey('message-sticker'))),
      const Size(112, 112),
    );
    expect(find.bySemanticsLabel('Nhãn dán'), findsOneWidget);
    // Không bong bóng: không Container nào mang nền bo góc của bong bóng.
    final bubbles = tester
        .widgetList<Container>(
          find.descendant(
            of: find.byType(MessageBubble),
            matching: find.byType(Container),
          ),
        )
        .where((c) => c.decoration is BoxDecoration)
        .where((c) => (c.decoration! as BoxDecoration).borderRadius != null);
    expect(bubbles, isEmpty);
    // Không vào nhánh ảnh / tệp.
    expect(find.byKey(const ValueKey('message-image-gallery')), findsNothing);
    expect(find.byType(ClipRRect), findsNothing);
    handle.dispose();
  });

  testWidgets('sticker with caption still draws the text bubble', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessageBubble(
            message: _message(
              text: 'cảm ơn',
              atts: const [
                MessageAttachment(
                  url: 'https://example.invalid/like.png',
                  type: 'sticker',
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.byType(MessageStickers), findsOneWidget);
    expect(find.textContaining('cảm ơn', findRichText: true), findsOneWidget);
  });
}
