import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/bootstrap.dart';
import 'package:omni_app/core/module/module_registry.dart';
import 'package:omni_app/core/module/nav_destination.dart';
import 'package:omni_app/core/network/dio_provider.dart';
import 'package:omni_app/demo/demo_backend.dart';
import 'package:omni_app/demo/modules/finance_demo.dart';
import 'package:omni_app/design/components/components.dart';
import 'package:omni_app/modules/finance/application/finance_providers.dart';
import 'package:omni_app/modules/finance/domain/finance_permissions.dart';
import 'package:omni_app/modules/finance/finance_module.dart';
import 'package:omni_app/modules/finance/presentation/finance_catalog_page.dart';
import 'package:omni_app/security/permissions/access_policy.dart';
import 'package:omni_app/security/session/session.dart';
import 'package:omni_app/security/session/session_controller.dart';

void main() {
  final fixedClock = DateTime.utc(2026, 11, 2, 2, 0);

  ({Widget app, FinanceDemoStore store}) harness({
    void Function(FinanceDemoStore store)? configure,
  }) {
    final routes = DemoRoutes();
    final store = registerFinanceDemo(routes, clock: fixedClock);
    configure?.call(store);
    final dio = Dio(BaseOptions(baseUrl: 'http://demo.local'))
      ..httpClientAdapter = DemoApiAdapter(routes, latency: Duration.zero);
    return (
      app: ProviderScope(
        overrides: [
          dioProvider.overrideWithValue(dio),
          financeClockProvider.overrideWithValue(fixedClock),
        ],
        child: const MaterialApp(home: FinanceCatalogPage()),
      ),
      store: store,
    );
  }

  Future<void> pumpPage(WidgetTester tester, Widget app) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
  }

  void archiveMarketing(FinanceDemoStore store) {
    store.groups.firstWhere((g) => g['id'] == 'g_mk')['archived'] = true;
  }

  testWidgets('hiện ba nhóm: Nhóm chi, Đã lưu trữ, Nguồn tiền', (tester) async {
    final h = harness(configure: archiveMarketing);
    await pumpPage(tester, h.app);

    expect(
      find.byKey(const ValueKey('finance-catalog-groups')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('finance-catalog-archived')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('finance-catalog-accounts')),
      findsOneWidget,
    );

    // Nhóm lưu trữ chỉ nằm ở "Đã lưu trữ".
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('finance-catalog-archived')),
        matching: find.text('Tiếp thị & khách'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('finance-catalog-groups')),
        matching: find.text('Tiếp thị & khách'),
      ),
      findsNothing,
    );

    final opCount = h.store.groupExpenseCount('g_op');
    expect(opCount, greaterThan(0));
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('finance-catalog-group-g_op')),
        matching: find.text('$opCount khoản'),
      ),
      findsOneWidget,
    );
    // Phụ đề chỉ ở nhóm không tính vào chi phí.
    expect(find.text('Không tính vào chi phí'), findsOneWidget);
    expect(find.text('TK ngân hàng'), findsOneWidget);
    // Câu gộp nhóm nằm trong sheet sửa nhóm, không ở cuối trang (rà soát 12/11).
    expect(find.text('Gộp nhiều nhóm làm một: dùng bản web.'), findsNothing);
  });

  testWidgets('nhóm còn khoản: Xoá nhóm bị khoá, gợi ý lưu trữ', (
    tester,
  ) async {
    final h = harness();
    await pumpPage(tester, h.app);
    final count = h.store.groupExpenseCount('g_op');

    await tester.tap(find.byKey(const ValueKey('finance-catalog-group-g_op')));
    await tester.pumpAndSettle();

    final delete = tester.widget<OmniGroupRow>(
      find.byKey(const ValueKey('finance-catalog-delete')),
    );
    expect(delete.onTap, isNull);
    expect(find.text('Còn $count khoản, hãy lưu trữ'), findsOneWidget);
    expect(find.text('Gộp nhiều nhóm làm một: dùng bản web.'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('finance-catalog-counts-switch')),
      findsOneWidget,
    );
  });

  testWidgets('nhóm trống: xoá sau khi xác nhận, danh sách cập nhật', (
    tester,
  ) async {
    final h = harness();
    await pumpPage(tester, h.app);
    expect(h.store.groupExpenseCount('g_pe'), 0);

    await tester.tap(find.byKey(const ValueKey('finance-catalog-group-g_pe')));
    await tester.pumpAndSettle();

    final delete = tester.widget<OmniGroupRow>(
      find.byKey(const ValueKey('finance-catalog-delete')),
    );
    expect(delete.onTap, isNotNull);
    await tester.tap(find.byKey(const ValueKey('finance-catalog-delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xoá').last);
    await tester.pumpAndSettle();

    expect(h.store.groups.any((g) => g['id'] == 'g_pe'), isFalse);
    expect(
      find.byKey(const ValueKey('finance-catalog-group-g_pe')),
      findsNothing,
    );
  });

  testWidgets('tắt "Tính vào chi phí" rồi Lưu gửi counts_as_expense', (
    tester,
  ) async {
    final h = harness();
    await pumpPage(tester, h.app);

    await tester.tap(find.byKey(const ValueKey('finance-catalog-group-g_op')));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('finance-catalog-save')));
    await tester.pumpAndSettle();

    final op = h.store.groups.firstWhere((g) => g['id'] == 'g_op');
    expect(op['counts_as_expense'], isFalse);
    expect(find.text('Không tính vào chi phí'), findsNWidgets(2));
  });

  test('menu Tài chính có lối vào Danh mục chi cho Admin', () {
    final entry = const FinanceModule().navEntries().firstWhere(
      (e) => e.routeName == FinanceRoutes.catalog,
    );
    expect(entry.label, 'Danh mục chi');
    expect(entry.area, NavArea.finance);
    expect(entry.order, 27);
    expect(
      const FinanceModule().routes().map((r) => r.path),
      contains(FinanceRoutes.catalogPath),
    );

    final container = ProviderContainer(
      overrides: [
        modulesProvider.overrideWithValue(appModules),
        sessionProvider.overrideWithValue(
          Session(
            status: SessionStatus.authenticated,
            policy: AccessPolicy({FinancePermissions.base}),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    final labels =
        (container.read(directoryGroupsProvider)[NavArea.finance] ?? const [])
            .map((e) => e.label);
    expect(labels, contains('Danh mục chi'));
  });
}
