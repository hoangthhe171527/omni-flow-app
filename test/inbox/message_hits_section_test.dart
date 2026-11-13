import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/core/domain/channel.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/modules/inbox/data/inbox_api.dart';
import 'package:omni_app/modules/inbox/domain/conversation.dart';
import 'package:omni_app/modules/inbox/domain/message.dart';
import 'package:omni_app/modules/inbox/presentation/widgets/message_hits_section.dart';

/// Nhóm "Tin nhắn" của ô tìm Hộp thư (bug sheet 12/11/2026).
void main() {
  const mark = TextStyle(fontWeight: FontWeight.w900);
  List<String> marked(List<TextSpan> spans) => [
    for (final s in spans)
      if (s.style == mark) s.text!,
  ];

  test('tô chỗ khớp ĐẦU TỪ, không phân biệt hoa thường, không tô giữa từ', () {
    expect(
      marked(highlightSpans('Giá cây YAMAHA U3 rẻ hơn giá cũ', 'giá u3', mark)),
      ['Giá', 'U3', 'giá'],
    );
    expect(marked(highlightSpans('YAMAHA', 'maha', mark)), isEmpty);
  });

  test('tin dài: cắt quanh chỗ khớp đầu tiên, có dấu …', () {
    final long = '${'a ' * 150}báo giá cuối ${'b ' * 80}';
    final spans = highlightSpans(long, 'giá', mark);
    expect(spans.first.text, '…');
    expect(spans.last.text, '…');
    expect(marked(spans), ['giá']);
  });

  testWidgets('mỗi tin một dòng: tên khách, nguồn; chạm trả đúng tin', (
    tester,
  ) async {
    final opened = <String>[];
    final hit = MessageSearchHit(
      message: Message(
        id: 'm9',
        author: MessageAuthor.customer,
        text: 'Báo giá giúp anh cây KAWAI',
        sentAt: DateTime.now(),
      ),
      conversation: Conversation(
        id: 'c2',
        channel: Channel.facebook,
        status: ConversationStatus.open,
        customerName: 'Minh Đức',
        sourceName: 'Facebook Page · TN Piano',
        lastMessage: '',
        unread: 0,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: OmniTheme.light(TargetPlatform.android),
        home: Scaffold(
          body: MessageHitsSection(
            hits: [hit],
            term: 'giá',
            onOpen: (h) => opened.add(h.message.id),
          ),
        ),
      ),
    );

    expect(find.text('Tin nhắn · 1'), findsOneWidget);
    expect(find.text('Minh Đức'), findsOneWidget);
    expect(find.textContaining('TN Piano'), findsOneWidget);
    await tester.tap(find.text('Minh Đức'));
    expect(opened, ['m9']);
  });
}
