import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/modules/plans/domain/plan.dart';
import 'package:omni_app/modules/plans/presentation/widgets/plan_row.dart';

/// Nền dự án là một KHỐI ĐẦU THẺ mang tên dự án, không phải một vạch 6dp.
///
/// Bản đầu vẽ nền thành dải mỏng ngay trên thanh tiến độ — cùng bề dày, cùng
/// bo góc — và trong ảnh chụp nó đọc như một thanh tiến độ thứ hai màu tím.
/// Nền chỉ có nghĩa khi nó ÔM tên dự án, đúng như ô xem trước lúc tạo.
void main() {
  final plan = Plan.fromJson(const {
    'id': 'p1',
    'name': 'Đàn cơ',
    'cover': 'plum-1',
    'sections': [
      {'id': 's1', 'name': 'Máy'},
      {'id': 's2', 'name': 'Sơn'},
    ],
    'stats': {'total': 12, 'done': 3, 'overdue': 2},
  });

  Widget host(Plan p) => MaterialApp(
    theme: OmniTheme.light(TargetPlatform.android),
    home: Scaffold(
      body: Padding(padding: const EdgeInsets.all(16), child: PlanRow(plan: p)),
    ),
  );

  /// Khối duy nhất trong thẻ mang gradient nền.
  Finder coverBlock() => find.byWidgetPredicate(
    (w) =>
        w is Container &&
        w.decoration is BoxDecoration &&
        (w.decoration as BoxDecoration).gradient != null,
  );

  testWidgets('tên dự án nằm TRONG khối nền, chữ trắng', (tester) async {
    await tester.pumpWidget(host(plan));

    expect(coverBlock(), findsOneWidget);
    expect(
      find.descendant(of: coverBlock(), matching: find.text('Đàn cơ')),
      findsOneWidget,
      reason: 'nền không ôm tên thì chỉ là một vạch màu vô nghĩa',
    );

    final name = tester.widget<Text>(find.text('Đàn cơ'));
    expect(name.style?.color, Colors.white);
  });

  testWidgets('khối nền là đầu thẻ: chạm mép, cao ≥ 56dp, trên thanh tiến độ', (
    tester,
  ) async {
    await tester.pumpWidget(host(plan));

    final cover = tester.getRect(coverBlock());
    final card = tester.getRect(find.byType(PlanRow));
    final bar = tester.getRect(find.byType(LinearProgressIndicator));

    // Một vạch 6dp có đệm quanh là thứ vừa bị bỏ. Khối đầu thẻ phải chạm ba
    // mép trên của thẻ (trừ nét viền 1dp) và đủ cao để chứa một dòng tên.
    expect(cover.height, greaterThanOrEqualTo(56));
    expect(cover.top, closeTo(card.top, 1.5));
    expect(cover.left, closeTo(card.left, 1.5));
    expect(cover.width, closeTo(card.width, 3));
    expect(bar.top, greaterThan(cover.bottom));
  });

  testWidgets('ba con số của quản đốc vẫn còn', (tester) async {
    await tester.pumpWidget(host(plan));

    expect(find.textContaining('Xong 3/12'), findsOneWidget);
    expect(find.textContaining('2 nhóm việc'), findsOneWidget);
    expect(find.text('Trễ 2'), findsOneWidget);
  });

  testWidgets('dự án tạo trước tính năng (cover null) vẫn có khối đầu', (
    tester,
  ) async {
    // Gần như mọi dự án trong cơ sở dữ liệu hôm nay. Không có khối đầu thì
    // danh sách là hai kiểu thẻ lẫn nhau.
    await tester.pumpWidget(
      host(Plan.fromJson(const {'id': 'p0', 'name': 'Dự án cũ'})),
    );

    expect(coverBlock(), findsOneWidget);
    expect(
      find.descendant(of: coverBlock(), matching: find.text('Dự án cũ')),
      findsOneWidget,
    );
    expect(find.text('Chưa có việc nào'), findsOneWidget);
  });
}
