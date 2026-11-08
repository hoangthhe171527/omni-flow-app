import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/core/network/dio_provider.dart';
import 'package:omni_app/demo/demo_backend.dart';
import 'package:omni_app/demo/modules/finance_demo.dart';
import 'package:omni_app/modules/finance/application/finance_providers.dart';
import 'package:omni_app/modules/finance/presentation/expenses_page.dart';
import 'package:omni_app/modules/finance/presentation/widgets/expense_row_tile.dart';

/// Vuốt dòng khoản chi (expense-swipe-uiux.html phương án B): vòng kính hiện
/// dần trong khoảng đã lộ — không nút nào nằm dưới dòng; kéo trái hết cỡ hỏi
/// xoá ngay.
void main() {
  final fixedClock = DateTime.utc(2026, 11, 2, 2, 0);

  Widget app() {
    final routes = DemoRoutes();
    registerFinanceDemo(routes, clock: fixedClock, seedInitialData: true);
    final dio = Dio(BaseOptions(baseUrl: 'http://demo.local'))
      ..httpClientAdapter = DemoApiAdapter(routes, latency: Duration.zero);
    return ProviderScope(
      overrides: [
        dioProvider.overrideWithValue(dio),
        financeClockProvider.overrideWithValue(fixedClock),
      ],
      child: const MaterialApp(home: ExpensesPage()),
    );
  }

  void phone(WidgetTester t) {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
  }

  Finder firstRow() => find.byType(ExpenseRowTile).first;

  testWidgets('chưa vuốt: không có nút vuốt nào được dựng', (t) async {
    phone(t);
    await t.pumpWidget(app());
    await t.pumpAndSettle();
    expect(firstRow(), findsOneWidget);
    expect(find.byKey(const ValueKey('swipe-del')), findsNothing);
    expect(find.byKey(const ValueKey('swipe-dup')), findsNothing);
  });

  testWidgets('kéo trái nửa chừng: nút nằm trọn trong phần đã lộ', (t) async {
    phone(t);
    await t.pumpWidget(app());
    await t.pumpAndSettle();
    final row = t.getRect(firstRow());

    final g = await t.startGesture(row.center);
    await g.moveBy(const Offset(-20, 0));
    await g.moveBy(const Offset(-50, 0));
    await t.pump();

    final del = t.getRect(find.byKey(const ValueKey('swipe-del')));
    final dup = t.getRect(find.byKey(const ValueKey('swipe-dup')));
    // Phần đã lộ là dải ~70 sát mép phải: hai nút thu nhỏ vào đó, không
    // chồng nhau, không lấn sang phần dòng còn che.
    final revealedLeft = row.right - 70;
    expect(dup.left, greaterThanOrEqualTo(revealedLeft - 0.5));
    expect(del.left, greaterThanOrEqualTo(dup.right - 0.5));
    expect(del.right, lessThanOrEqualTo(row.right + 0.5));
    await g.up();
    await t.pumpAndSettle();
  });

  testWidgets('thả sau khi kéo đủ: mở hai nút Tháng sau, Xoá cỡ thật', (
    t,
  ) async {
    phone(t);
    await t.pumpWidget(app());
    await t.pumpAndSettle();
    await t.drag(firstRow(), const Offset(-120, 0));
    await t.pumpAndSettle();
    expect(find.text('Tháng sau'), findsOneWidget);
    expect(find.text('Xoá'), findsOneWidget);
    expect(
      t.getSize(find.byKey(const ValueKey('swipe-del'))).width,
      closeTo(64, 0.5),
    );
  });

  testWidgets('kéo trái hết cỡ: hỏi xoá ngay', (t) async {
    phone(t);
    await t.pumpWidget(app());
    await t.pumpAndSettle();
    final row = t.getRect(firstRow());
    final g = await t.startGesture(row.center);
    await g.moveBy(const Offset(-30, 0));
    await g.moveBy(const Offset(-280, 0));
    await t.pump();
    // Sắp xoá: chỉ còn nút Xoá (Tháng sau nhường chỗ).
    expect(find.byKey(const ValueKey('swipe-dup')), findsNothing);
    await g.up();
    await t.pumpAndSettle();
    expect(find.textContaining('Xoá'), findsWidgets);
    expect(find.byType(BottomSheet), findsOneWidget);
  });
}
