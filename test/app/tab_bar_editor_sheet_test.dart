import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/app/shell/tab_bar_editor_sheet.dart';
import 'package:omni_app/core/module/module_registry.dart';
import 'package:omni_app/core/module/nav_destination.dart';
import 'package:omni_app/core/nav/tab_order.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

ModuleNavEntry _e(String route, String label, NavArea area) => ModuleNavEntry(
  moduleId: route,
  label: label,
  icon: Icons.circle_outlined,
  selectedIcon: Icons.circle,
  routeName: route,
  area: area,
  weight: NavWeight.primary,
);

final _all = [
  _e('dashboard.home', 'Tổng quan', NavArea.work),
  _e('inbox.list', 'Hộp thư', NavArea.communication),
  _e('customers.list', 'Khách', NavArea.sales),
  _e('plans.teams', 'Việc', NavArea.work),
  _e('finance.expenses', 'Sổ chi phí', NavArea.admin),
  _e('team.list', 'Nhân viên', NavArea.admin),
];

void main() {
  late ProviderContainer container;

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    container = ProviderContainer(
      overrides: [
        primaryNavEntriesProvider.overrideWithValue(_all.take(4).toList()),
        pinnableNavEntriesProvider.overrideWithValue(_all),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: OmniTheme.light(),
          home: const Scaffold(body: TabBarEditor()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  List<String> tabs() =>
      container.read(tabEntriesProvider).map((e) => e.routeName).toList();

  testWidgets('mặc định đủ 4/4: nút thêm khoá lại', (tester) async {
    await pump(tester);

    expect(find.text('4/4'), findsOneWidget);
    final add = tester.widget<IconButton>(
      find.ancestor(
        of: find.byTooltip('Thêm Sổ chi phí vào thanh menu'),
        matching: find.byType(IconButton),
      ),
    );
    expect(add.onPressed, isNull);
  });

  testWidgets('bỏ một mục rồi thêm Sổ chi phí: thanh đổi ngay', (tester) async {
    await pump(tester);

    await tester.tap(find.byTooltip('Bỏ Khách khỏi thanh menu'));
    await tester.pumpAndSettle();
    expect(find.text('3/4'), findsOneWidget);
    expect(tabs(), ['dashboard.home', 'inbox.list', 'plans.teams']);

    await tester.tap(find.byTooltip('Thêm Sổ chi phí vào thanh menu'));
    await tester.pumpAndSettle();
    expect(tabs(), [
      'dashboard.home',
      'inbox.list',
      'plans.teams',
      'finance.expenses',
    ]);
  });

  testWidgets('thao tác "Lên" của trình đọc màn hình đổi thứ tự', (
    tester,
  ) async {
    await pump(tester);
    final row = tester.widget<Semantics>(
      find.byWidgetPredicate(
        (w) =>
            w is Semantics &&
            (w.properties.label?.startsWith('Hộp thư, vị trí 2') ?? false),
      ),
    );
    final actions = row.properties.customSemanticsActions!;
    expect(actions.keys.map((a) => a.label), ['Lên', 'Xuống']);
    actions[const CustomSemanticsAction(label: 'Lên')]!();
    await tester.pumpAndSettle();
    expect(tabs().take(2), ['inbox.list', 'dashboard.home']);
  });

  testWidgets('còn một mục thì không bỏ được; "Về mặc định" trả thanh cũ', (
    tester,
  ) async {
    await pump(tester);
    await container.read(tabPinsProvider.notifier).save(['inbox.list']);
    await tester.pumpAndSettle();

    final remove = tester.widget<IconButton>(
      find.ancestor(
        of: find.byTooltip('Bỏ Hộp thư khỏi thanh menu'),
        matching: find.byType(IconButton),
      ),
    );
    expect(remove.onPressed, isNull);

    await tester.tap(find.text('Về mặc định'));
    await tester.pumpAndSettle();
    expect(tabs(), tabRouteOrder);
  });
}
