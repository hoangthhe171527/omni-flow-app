import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/modules/inbox/domain/message.dart';
import 'package:omni_app/modules/inbox/presentation/widgets/message_bubble.dart';

/// Recognizer của link trong bong bóng sống theo VÒNG ĐỜI widget, không theo
/// build.
///
/// Trước đây `_MessageText.build` dispose rồi tạo lại toàn bộ
/// TapGestureRecognizer ở mỗi lần dựng — mà bong bóng dựng lại mỗi khi danh
/// sách dựng lại (gõ phím, biên nhận, cuộn). Với một hội thoại đầy link, đó là
/// N recognizer cấp phát và huỷ mỗi frame để ra đúng văn bản cũ.
void main() {
  // Bong bóng in giờ gửi qua intl; không nạp dữ liệu locale là ném ngay lúc dựng.
  setUpAll(() => initializeDateFormatting('vi_VN'));

  Message message(String text) => Message.fromJson({
    'id': 'm1',
    'from': 'customer',
    'text': text,
    'sent_at': DateTime.utc(2026, 1, 1, 8).toIso8601String(),
  });

  Widget host(String text) => MaterialApp(
    theme: OmniTheme.light(TargetPlatform.android),
    home: Scaffold(body: MessageBubble(message: message(text))),
  );

  /// Dựng rồi để mọi thứ lắng: theme của MaterialApp chuyển có hiệu ứng, và
  /// bong bóng có link còn xin xem trước link qua Dio (flutter_test chặn HTTP
  /// bằng một client trả 400) — timer của lượt gọi đó phải được chạy hết,
  /// không thì binding báo "A Timer is still pending" lúc dọn.
  Future<void> pumpBubble(WidgetTester tester, String text) async {
    await tester.pumpWidget(host(text));
    await tester.pumpAndSettle();
  }

  List<TapGestureRecognizer> recognizers(WidgetTester tester) {
    final text = tester.widget<Text>(
      find.byWidgetPredicate((w) => w is Text && w.textSpan != null),
    );
    final root = text.textSpan! as TextSpan;
    return [
      for (final span in root.children!.whereType<TextSpan>())
        if (span.recognizer case final TapGestureRecognizer tap) tap,
    ];
  }

  const twoLinks = 'Xem https://viomni.vn và omni.vn/gia nhé';

  testWidgets(
    '2 link → 2 recognizer; dựng lại 3 lần cùng text → vẫn là 2 cái đó',
    (tester) async {
      await pumpBubble(tester, twoLinks);
      final first = recognizers(tester);
      expect(first, hasLength(2));

      for (var i = 0; i < 3; i++) {
        await pumpBubble(tester, twoLinks);
      }

      final after = recognizers(tester);
      expect(after, hasLength(2));
      for (var i = 0; i < 2; i++) {
        expect(
          identical(first[i], after[i]),
          isTrue,
          reason:
              'Cùng text mà recognizer khác là build đã tạo lại — cấp phát theo '
              'frame chứ không theo vòng đời.',
        );
      }
    },
  );

  testWidgets('đổi text → recognizer mới, recognizer cũ đã dispose', (
    tester,
  ) async {
    final disposed = <Object>[];
    void onEvent(ObjectEvent event) {
      if (event is ObjectDisposed && event.object is TapGestureRecognizer) {
        disposed.add(event.object);
      }
    }

    FlutterMemoryAllocations.instance.addListener(onEvent);
    try {
      await pumpBubble(tester, twoLinks);
      final first = recognizers(tester);

      await pumpBubble(tester, 'Chỉ còn https://viomni.vn thôi');
      final after = recognizers(tester);

      expect(after, hasLength(1));
      expect(after.single, isNot(anyOf(first.map(same))));
      for (final old in first) {
        expect(
          disposed.any((d) => identical(d, old)),
          isTrue,
          reason: 'Recognizer bị thay phải được dispose, không rò.',
        );
      }

      // Gỡ bong bóng: cái còn lại cũng phải được dispose.
      await tester.pumpWidget(const SizedBox());
      expect(disposed.any((d) => identical(d, after.single)), isTrue);
    } finally {
      FlutterMemoryAllocations.instance.removeListener(onEvent);
    }
  });

  testWidgets('text không có link → không recognizer nào', (tester) async {
    await pumpBubble(tester, 'Dạ em chào anh ạ');
    expect(recognizers(tester), isEmpty);
  });
}
