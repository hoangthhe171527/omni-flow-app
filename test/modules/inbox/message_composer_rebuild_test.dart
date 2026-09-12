import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/design/components/components.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/modules/inbox/presentation/widgets/message_composer.dart';

/// Gõ phím vào composer không được dựng lại cả composer, càng không được vẽ
/// lại nền phía sau.
///
/// Trước đây mỗi ký tự là một `setState(() {})` trên toàn bộ composer (để đổi
/// nút ảnh ↔ nút gửi), và composer nằm trong cùng một lớp vẽ với hoạ tiết nền
/// — nên một phím gõ là dựng lại ô nhập, khay ảnh, dải ghi chú, rồi raster lại
/// cả trăm nét hoạ tiết của màn hình.
void main() {
  Widget host() => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: OmniTheme.light(TargetPlatform.android),
    home: Scaffold(
      body: OmniBackdrop(
        name: 'walnut',
        child: Column(
          children: [
            const Expanded(child: SizedBox.expand()),
            MessageComposer(
              onSend: (text, mode, images, replyTo) async {},
              onPickImages: () async => const [],
            ),
          ],
        ),
      ),
    ),
  );

  Future<void> type(WidgetTester tester, String text) async {
    for (var i = 1; i <= text.length; i++) {
      await tester.enterText(find.byType(TextField), text.substring(0, i));
      await tester.pump();
    }
  }

  // TextField cũng có CustomPaint của riêng nó; hoạ tiết nền là cái duy nhất
  // được đánh dấu isComplex.
  final patternPaint = find.byWidgetPredicate(
    (w) => w is CustomPaint && w.isComplex,
    description: 'CustomPaint hoạ tiết nền (isComplex)',
  );

  testWidgets('gõ 5 ký tự → hoạ tiết nền vẽ lại 0 lần', (tester) async {
    await tester.pumpWidget(host());

    final pattern = tester.renderObject(patternPaint);
    var paints = 0;
    // Trả biến debug về null NGAY trong thân bài: binding kiểm tra các biến
    // debug của rendering trước cả addTearDown.
    debugOnProfilePaint = (renderObject) {
      if (identical(renderObject, pattern)) paints++;
    };
    try {
      await type(tester, 'chào');
    } finally {
      debugOnProfilePaint = null;
    }

    expect(find.text('chào'), findsOneWidget);
    expect(paints, 0);
  });

  testWidgets('gõ phím không dựng lại ô nhập — vẫn là cùng một widget', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    final before = tester.widget<TextField>(find.byType(TextField));

    await type(tester, 'chào');

    final after = tester.widget<TextField>(find.byType(TextField));
    expect(
      identical(before, after),
      isTrue,
      reason:
          'Ô nhập bị tạo lại nghĩa là cả composer đã dựng lại vì một phím gõ; '
          'chỉ cụm nút gửi mới cần nghe controller.',
    );
  });

  testWidgets('nút gửi vẫn hiện khi có chữ và ẩn khi xoá hết', (tester) async {
    await tester.pumpWidget(host());
    expect(find.byIcon(Icons.send_rounded), findsNothing);
    expect(find.byIcon(Icons.image_outlined), findsOneWidget);

    await type(tester, 'ok');
    expect(find.byIcon(Icons.send_rounded), findsOneWidget);

    await tester.enterText(find.byType(TextField), '');
    await tester.pump();
    expect(find.byIcon(Icons.send_rounded), findsNothing);
  });

  testWidgets('composer có RepaintBoundary của riêng nó', (tester) async {
    await tester.pumpWidget(host());

    // Một ranh giới nằm TRÊN ô nhập và DƯỚI MessageComposer: lớp vẽ của composer
    // tách khỏi danh sách tin nhắn phía trên nó.
    expect(
      find.ancestor(
        of: find.byType(TextField),
        matching: find.descendant(
          of: find.byType(MessageComposer),
          matching: find.byType(RepaintBoundary),
        ),
      ),
      findsWidgets,
    );
  });
}
