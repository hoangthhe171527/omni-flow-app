import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/design/components/components.dart';
import 'package:omni_app/design/theme/omni_theme.dart';

/// Hoạ tiết nền là một lớp RIÊNG, không vẽ lại theo nội dung.
///
/// Trước đây `CustomPaint` ôm lấy child: mỗi lần nội dung vẽ lại — gõ một phím
/// vào composer, cuộn danh sách một frame — là vẽ lại cả trăm nét hoạ tiết để
/// ra đúng bức nền cũ. Bọc `RepaintBoundary` + `isComplex` để raster một lần
/// rồi chỉ composite; đổi kích thước hay đổi theme mới vẽ lại.
void main() {
  Widget host(Widget child) => MaterialApp(
    // Nhãn DEBUG của MaterialApp cũng là một CustomPaint — tắt để finder chỉ
    // thấy hoạ tiết của chính OmniBackdrop.
    debugShowCheckedModeBanner: false,
    theme: OmniTheme.light(TargetPlatform.android),
    home: OmniBackdrop(name: 'walnut', child: child),
  );

  testWidgets('hoạ tiết nằm trong RepaintBoundary riêng, isComplex', (
    tester,
  ) async {
    await tester.pumpWidget(host(const Text('nội dung')));

    final paint = tester.widget<CustomPaint>(find.byType(CustomPaint));
    expect(
      paint.isComplex,
      isTrue,
      reason: 'Gợi ý cho compositor cache raster.',
    );
    expect(paint.willChange, isFalse, reason: 'Nền là nền, không chuyển động.');

    final boundary = tester.widget<RepaintBoundary>(
      find
          .ancestor(
            of: find.byType(CustomPaint),
            matching: find.byType(RepaintBoundary),
          )
          .first,
    );
    expect(
      find.descendant(
        of: find.byWidget(boundary),
        matching: find.text('nội dung'),
      ),
      findsNothing,
      reason:
          'Ranh giới phải bọc ĐÚNG hoạ tiết, không bọc cả nội dung — không '
          'thì nội dung đổi vẫn kéo hoạ tiết vẽ lại bên trong cùng một lớp.',
    );
    expect(find.text('nội dung'), findsOneWidget);
  });

  testWidgets('nội dung đổi 5 lần → hoạ tiết vẽ lại 0 lần', (tester) async {
    late StateSetter bump;
    var n = 0;
    await tester.pumpWidget(
      host(
        StatefulBuilder(
          builder: (context, setState) {
            bump = setState;
            return Text('lần $n');
          },
        ),
      ),
    );

    final pattern = tester.renderObject(find.byType(CustomPaint));
    var paints = 0;
    // Trả biến debug về null NGAY trong thân bài: binding kiểm tra các biến
    // debug của rendering trước cả addTearDown.
    debugOnProfilePaint = (renderObject) {
      if (identical(renderObject, pattern)) paints++;
    };
    try {
      for (var i = 0; i < 5; i++) {
        bump(() => n++);
        await tester.pump();
      }
    } finally {
      debugOnProfilePaint = null;
    }

    expect(find.text('lần 5'), findsOneWidget);
    expect(
      paints,
      0,
      reason:
          'Nội dung vẽ lại 5 lần mà hoạ tiết vẽ lại theo là 5 lần raster cả '
          'màn cho cùng một bức nền.',
    );
  });
}
