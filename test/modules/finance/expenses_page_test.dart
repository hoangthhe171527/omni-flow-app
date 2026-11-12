import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/core/nav/shell_bar_inset.dart';
import 'package:omni_app/bootstrap.dart';
import 'package:omni_app/core/module/module_registry.dart';
import 'package:omni_app/core/module/nav_destination.dart';
import 'package:omni_app/core/network/active_tenant.dart';
import 'package:omni_app/core/network/dio_provider.dart';
import 'package:omni_app/demo/demo_backend.dart';
import 'package:omni_app/design/components/components.dart';
import 'package:omni_app/demo/modules/finance_demo.dart';
import 'package:omni_app/modules/finance/application/finance_providers.dart';
import 'package:omni_app/modules/finance/domain/finance_permissions.dart';
import 'package:omni_app/modules/finance/finance_module.dart';
import 'package:omni_app/modules/finance/presentation/expense_summary_page.dart';
import 'package:omni_app/modules/finance/presentation/expenses_page.dart';
import 'package:omni_app/security/permissions/access_policy.dart';
import 'package:omni_app/security/session/session.dart';
import 'package:omni_app/security/session/session_controller.dart';

void main() {
  // 2026-11-02 09:00 giờ Việt Nam (UTC+7)
  final fixedClock = DateTime.utc(2026, 11, 2, 2, 0);

  ({Widget app, FinanceDemoStore store, DemoRoutes routes}) buildTestHarness({
    bool seedInitialData = true,
    void Function(FinanceDemoStore store)? configureStore,
    double? textScale,
  }) {
    final routes = DemoRoutes();
    final store = registerFinanceDemo(
      routes,
      clock: fixedClock,
      seedInitialData: seedInitialData,
    );
    configureStore?.call(store);
    final dio = Dio(BaseOptions(baseUrl: 'http://demo.local'))
      ..httpClientAdapter = DemoApiAdapter(routes, latency: Duration.zero);

    final app = ProviderScope(
      overrides: [
        dioProvider.overrideWithValue(dio),
        financeClockProvider.overrideWithValue(fixedClock),
      ],
      child: MaterialApp(
        builder: textScale == null
            ? null
            : (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(textScale)),
                child: child!,
              ),
        home: const ExpensesPage(),
      ),
    );
    return (app: app, store: store, routes: routes);
  }

  group('FinanceModule — hiển thị trong mục Tất cả (DirectoryPage)', () {
    ProviderContainer containerFor(Set<String> permissions) {
      final container = ProviderContainer(
        overrides: [
          modulesProvider.overrideWithValue(appModules),
          sessionProvider.overrideWithValue(
            Session(
              status: SessionStatus.authenticated,
              policy: AccessPolicy(permissions),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('Admin có finance.expenses thấy đủ hai lối vào chi phí', () {
      final container = containerFor({FinancePermissions.base});
      final adminEntries =
          container.read(directoryGroupsProvider)[NavArea.finance] ?? const [];

      expect(
        adminEntries.map((e) => e.label),
        containsAll(['Sổ chi phí', 'Tổng hợp chi phí']),
      );
      expect(
        adminEntries.map((e) => e.routeName),
        containsAll([FinanceRoutes.expenses, FinanceRoutes.expenseSummary]),
      );
    });

    for (final permission in const [
      'finance.expenses.read',
      'orders.cost',
      'membership.members.read',
      'analytics.dashboard.read',
    ]) {
      test(
        'quyền không phải Admin $permission không thấy giao diện chi phí',
        () {
          final container = containerFor({permission});
          final labels = container
              .read(visibleNavEntriesProvider)
              .map((entry) => entry.label);

          expect(labels, isNot(contains('Sổ chi phí')));
          expect(labels, isNot(contains('Tổng hợp chi phí')));
        },
      );
    }

    test('route và menu dùng cùng điều kiện Admin', () {
      final financeRoutes = const FinanceModule().routes();
      final adminPolicy = AccessPolicy({FinancePermissions.base});
      final nonAdminPolicy = AccessPolicy({'membership.members.read'});

      for (final route in financeRoutes) {
        expect(route.access.isSatisfiedBy(adminPolicy), isTrue);
        expect(route.access.isSatisfiedBy(nonAdminPolicy), isFalse);
      }
    });
  });

  group('ExpensesPage — đồng bộ chuẩn 100% với API & Web', () {
    testWidgets(
      'hiển thị đúng số liệu từ API tháng 11, biến động so với tháng 10 và 5 khoản cố định từ lịch sử 3 tháng',
      (tester) async {
        final h = buildTestHarness();
        await tester.pumpWidget(h.app);
        await tester.pumpAndSettle();

        expect(find.text('Sổ chi phí'), findsNothing);
        expect(find.text('Tháng 11/2026'), findsOneWidget);
        // 2.450.000 + 6.000.000 + 1.650.000 = 10.100.000
        expect(find.text('10.100.000'), findsOneWidget);
        expect(find.text('Đã trả'), findsOneWidget);
        expect(find.text('5.450.000 đ'), findsOneWidget);
        expect(find.text('Phải trả'), findsOneWidget);
        expect(find.text('4.650.000 đ'), findsOneWidget);
        expect(find.textContaining('vs T10'), findsOneWidget);

        // Thẻ 4 khoản cố định tự nội suy từ tháng trước trên API (12tr + 1.85tr + 4.5tr + 3tr = 21.35tr, không có Lương nhân sự)
        expect(find.text('Khoản cố định'), findsOneWidget);
        expect(find.text('4 khoản · 21.350.000 đ'), findsOneWidget);
        expect(find.text('Ghi tất cả'), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('finance-recur-head')));
        await tester.pumpAndSettle();

        expect(find.text('Chi phí kho T11'), findsOneWidget);
        expect(find.text('Điện nước T11'), findsOneWidget);
        expect(find.text('Lương nhân sự T11'), findsNothing);
        expect(find.text('Lãi vay T11'), findsOneWidget);
        expect(find.text('Dịch vụ kế toán T11'), findsOneWidget);
      },
    );

    testWidgets(
      'tháng rỗng trên API hiển thị đúng 0 đ và trạng thái trống — tuyệt đối KHÔNG rò rỉ dữ liệu mẫu giả',
      (tester) async {
        final h = buildTestHarness(seedInitialData: false);
        await tester.pumpWidget(h.app);
        await tester.pumpAndSettle();

        expect(find.text('Tháng 11/2026'), findsOneWidget);
        expect(find.text('0'), findsOneWidget);
        expect(
          find.text('Chưa có khoản chi nào trong Tháng 11/2026.'),
          findsOneWidget,
        );
        // Không còn số liệu giả cũ 26.650.000 hay 41.350.000
        expect(find.text('26.650.000'), findsNothing);
        expect(find.text('5 khoản · 41.350.000 đ'), findsNothing);
        expect(
          find.text('4 khoản gợi ý · Chạm để nhập số tiền'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'chuyển kỳ sang Tháng 10 và Tháng 6 gọi GET /finance/expenses?month=… từ API và hiển thị đúng số liệu',
      (tester) async {
        final h = buildTestHarness(
          configureStore: (store) {
            store.insertRawExpense(
              spentOn: '2026-06-15',
              groupId: 'g_sw',
              title: 'Gia hạn bản quyền đám mây T6',
              amount: 8200000,
              accountId: 'acc_bank',
              payments: [
                {
                  'id': 'pay_jun_1',
                  'paid_on': '2026-06-15',
                  'amount': 8200000,
                  'account_id': 'acc_bank',
                },
              ],
            );
          },
        );
        await tester.pumpWidget(h.app);
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('finance-prev-month-btn')));
        await tester.pumpAndSettle();

        expect(find.text('Tháng 10/2026'), findsOneWidget);
        expect(find.text('21.350.000'), findsOneWidget);
        expect(find.text('Dịch vụ kế toán T10'), findsOneWidget);
        expect(find.text('Lương nhân sự T10'), findsNothing);

        await tester.drag(find.byType(ListView).first, const Offset(0, -350));
        await tester.pumpAndSettle();
        expect(find.text('Chi phí kho T10'), findsOneWidget);

        // Cuộn lại lên đầu: nút chọn kỳ nằm trong danh sách.
        await tester.drag(find.byType(ListView).first, const Offset(0, 800));
        await tester.pumpAndSettle();

        // Chọn tháng 6 (chưa prefetch) từ menu kỳ -> tải trực tiếp từ API
        await tester.tap(find.byTooltip('Chọn tháng khác'));
        await tester.pumpAndSettle();
        expect(find.text('Chạm để tải dữ liệu'), findsWidgets);
        await tester.ensureVisible(find.text('Tháng 6/2026'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Tháng 6/2026'));
        await tester.pumpAndSettle();

        expect(find.text('Tháng 6/2026'), findsOneWidget);
        expect(find.text('8.200.000'), findsOneWidget);
        expect(find.text('Gia hạn bản quyền đám mây T6'), findsOneWidget);
      },
    );

    testWidgets(
      'header gọn: hàng trên không còn nút riêng, đổi tháng bằng › và vuốt ngang thẻ tổng chi',
      (tester) async {
        final h = buildTestHarness();
        await tester.pumpWidget(h.app);
        await tester.pumpAndSettle();

        // Sắp xếp nằm trong viên kính tìm; "+" là nút kính góc phải dưới.
        expect(find.byType(OmniTopBarAction), findsNothing);
        expect(find.byTooltip('Sắp xếp danh sách'), findsOneWidget);
        expect(find.byTooltip('Thêm khoản chi'), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('finance-next-month-btn')));
        await tester.pumpAndSettle();
        expect(find.text('Tháng 12/2026'), findsOneWidget);

        // Vuốt sang phải = về tháng trước.
        await tester.fling(
          find.byKey(const ValueKey('finance-month-carousel')),
          const Offset(200, 0),
          800,
        );
        await tester.pumpAndSettle();
        expect(find.text('Tháng 11/2026'), findsOneWidget);
        expect(find.text('10.100.000'), findsOneWidget);
      },
    );

    testWidgets(
      'bố cục màn hình hẹp (360px + chữ phóng to 1.15x) vẫn gọn gàng, tuyệt đối KHÔNG cắt cụt số tiền bằng dấu "..."',
      (tester) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final h = buildTestHarness(textScale: 1.15);
        await tester.pumpWidget(h.app);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        for (final textValue in [
          '10.100.000',
          '5.450.000 đ',
          '4.650.000 đ',
          'Khoản cố định',
          '4 khoản · 21.350.000 đ',
          '2.450.000 đ',
          '6.000.000 đ',
          'còn 3.000.000 đ',
          '1.650.000 đ',
        ]) {
          final finder = find.text(textValue);
          expect(
            finder,
            findsWidgets,
            reason: 'Phải hiển thị đầy đủ "$textValue"',
          );
          for (final element in finder.evaluate()) {
            final widget = element.widget;
            if (widget is Text) {
              expect(
                widget.overflow,
                isNot(TextOverflow.ellipsis),
                reason:
                    '"$textValue" không được phép dùng TextOverflow.ellipsis',
              );
            }
          }
        }
      },
    );

    testWidgets(
      'bấm "Ghi tất cả" tạo thật 4 khoản lên API (POST) và bấm "Hoàn tác" xoá thật trên API (DELETE)',
      (tester) async {
        final h = buildTestHarness();
        final initialNovCount = h.store.expenses
            .where((e) => e['month'] == '2026-11')
            .length;
        expect(initialNovCount, 3);

        await tester.pumpWidget(h.app);
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const ValueKey('finance-recur-commit-all')),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        // 3 khoản cũ + 4 khoản cố định vừa POST lên server = 7 khoản
        expect(
          h.store.expenses.where((e) => e['month'] == '2026-11').length,
          7,
        );
        expect(find.text('Khoản cố định'), findsNothing);
        // 10.100.000 + 21.350.000 = 31.450.000
        expect(find.text('31.450.000'), findsOneWidget);
        expect(find.text('Hoàn tác'), findsOneWidget);

        // Bấm Hoàn tác -> gọi DELETE xoá 4 bản ghi trên server
        await tester.tap(find.byKey(const ValueKey('finance-undo-btn')));
        await tester.pump(const Duration(seconds: 5));

        expect(
          h.store.expenses.where((e) => e['month'] == '2026-11').length,
          3,
        );
        expect(find.text('Khoản cố định'), findsOneWidget);
        expect(find.text('10.100.000'), findsOneWidget);
      },
    );

    testWidgets(
      'xoá khoản chi yêu cầu xác nhận 2 bước (Bước 1/2 -> Bước 2/2) trước khi xoá thật trên API',
      (tester) async {
        final h = buildTestHarness();
        await tester.pumpWidget(h.app);
        await tester.pumpAndSettle();

        final cashItemFinder = find.text('Tiếp khách đối tác chiến lược');
        await tester.ensureVisible(cashItemFinder);
        await tester.pumpAndSettle();
        await tester.tap(cashItemFinder);
        await tester.pumpAndSettle();

        // Xoá nằm ở nhóm đỏ cuối sheet: cuộn tới rồi mới chạm.
        await tester.ensureVisible(find.byTooltip('Xoá khoản chi'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Xoá khoản chi'));
        await tester.pumpAndSettle();

        expect(find.text('Bước 1/2 · Kiểm tra mục sắp xoá'), findsOneWidget);
        await tester.tap(
          find.byKey(const ValueKey('finance-delete-step1-btn')),
        );
        await tester.pumpAndSettle();

        expect(find.text('Bước 2/2 · Xác nhận xoá vĩnh viễn'), findsOneWidget);
        await tester.tap(
          find.byKey(const ValueKey('finance-delete-step2-btn')),
        );
        await tester.pumpAndSettle();
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();

        expect(find.text('Tiếp khách đối tác chiến lược'), findsNothing);
        expect(
          h.store.expenses.where((e) => e['month'] == '2026-11').length,
          2,
        );
      },
    );

    testWidgets(
      'xử lý chuẩn nhóm không tính chi phí (counts_as_expense: false) và khoản hoàn/giảm trừ âm (amount < 0)',
      (tester) async {
        final h = buildTestHarness(
          configureStore: (store) {
            store.insertRawExpense(
              spentOn: '2026-11-02',
              groupId: 'g_profit', // Chia lợi nhuận (counts_as_expense: false)
              title: 'Tạm chia cổ tức đợt 1',
              amount: 20000000,
              accountId: 'acc_bank',
              payments: [
                {
                  'id': 'pay_div',
                  'paid_on': '2026-11-02',
                  'amount': 20000000,
                  'account_id': 'acc_bank',
                },
              ],
            );
            store.insertRawExpense(
              spentOn: '2026-11-02',
              groupId: 'g_op',
              title: 'Chiết khấu hoàn cước vận chuyển',
              amount: -500000,
            );
          },
        );

        await tester.pumpWidget(h.app);
        await tester.pumpAndSettle();

        // Tổng chi tháng 11 = 10.100.000 - 500.000 = 9.600.000 (KHÔNG cộng 20tr Chia lợi nhuận)
        expect(find.text('9.600.000'), findsOneWidget);
        expect(
          find.textContaining('Ngoài chi phí: 20.000.000 đ'),
          findsOneWidget,
        );
        expect(find.text('-500.000 đ'), findsOneWidget);
        expect(find.text('Hoàn/giảm'), findsOneWidget);

        // Mở bảng tỷ trọng theo nhóm -> nhóm Chia lợi nhuận hiện "Không tính CP" thay vì %
        await tester.tap(find.byKey(const ValueKey('finance-grp-toggle')));
        await tester.pumpAndSettle();
        expect(find.text('Không tính CP'), findsWidgets);
      },
    );

    testWidgets(
      'tìm kiếm theo số tiền viết tắt (2.45tr, 1.65tr), tên chứng từ và sắp xếp theo nhóm + xem chi tiết',
      (tester) async {
        final h = buildTestHarness();
        await tester.pumpWidget(h.app);
        await tester.pumpAndSettle();

        // Ô tìm luôn nằm trong viên kính dưới thanh trên, không còn nút bật.
        expect(
          find.byKey(const ValueKey('finance-search-toggle')),
          findsNothing,
        );
        final searchInput = find.byKey(const ValueKey('finance-search-input'));
        expect(find.text('Tìm khoản chi, số tiền'), findsOneWidget);
        expect(find.byTooltip('Xoá tìm kiếm'), findsNothing);

        await tester.enterText(searchInput, '2.45tr');
        await tester.pumpAndSettle();
        expect(find.byTooltip('Xoá tìm kiếm'), findsOneWidget);
        expect(find.text('Tiếp khách đối tác chiến lược'), findsOneWidget);
        expect(find.text('Vật tư đóng gói & vận đơn'), findsNothing);

        await tester.enterText(searchInput, 'Hoa-don-tiep-khach');
        await tester.pumpAndSettle();
        expect(find.text('Tiếp khách đối tác chiến lược'), findsOneWidget);

        // Xoá tìm kiếm & sắp xếp theo nhóm
        await tester.tap(find.byTooltip('Xoá tìm kiếm'));
        await tester.pumpAndSettle();
        expect(find.byTooltip('Xoá tìm kiếm'), findsNothing);

        // Ô tìm còn focus mà trống thì thân màn bị phủ mờ: "Huỷ" để thoát tìm.
        await tester.tap(find.text('Huỷ'));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('finance-sort-btn')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Loại chi phí (theo nhóm)'));
        await tester.pumpAndSettle();
        expect(find.text('Đang lọc: Loại chi phí (theo nhóm)'), findsOneWidget);

        // Mở Sheet Chi tiết khoản trả đủ 1 lần có chứng từ
        final cashItemFinder = find.text('Tiếp khách đối tác chiến lược');
        await tester.ensureVisible(cashItemFinder);
        await tester.pumpAndSettle();
        await tester.tap(cashItemFinder);
        await tester.pumpAndSettle();

        expect(find.text('Chi tiết khoản chi'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('finance-detail-title-btn')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('finance-detail-paid-date-cell')),
          findsOneWidget,
        );
        expect(find.text('Ngày ghi nhận'), findsOneWidget);
        expect(find.text('Ngày thanh toán'), findsOneWidget);
        expect(find.text('Đã trả đủ · 02/11'), findsOneWidget);
        expect(find.text('1 chứng từ'), findsOneWidget);
        expect(find.text('Hoa-don-tiep-khach.jpg'), findsOneWidget);

        await tester.tap(find.byTooltip('Đóng'));
        await tester.pumpAndSettle();

        // Mở khoản trả một phần
        final partialFinder = find.text('Quảng cáo chiến dịch đầu tháng');
        await tester.ensureVisible(partialFinder);
        await tester.pumpAndSettle();
        await tester.tap(partialFinder);
        await tester.pumpAndSettle();

        expect(find.text('Đã trả 3.000.000 đ'), findsOneWidget);
        expect(find.text('Còn 3.000.000 đ'), findsOneWidget);
        expect(find.text('Trả · 3.000.000 đ'), findsOneWidget);
      },
    );

    testWidgets(
      'đổi workspace (activeTenantIdProvider) tự động reset state và tải lại dữ liệu của tenant mới',
      (tester) async {
        var currentTenant = 'tenant-a';
        final routes = DemoRoutes();
        final storeA = FinanceDemoStore(
          clock: fixedClock,
          seedInitialData: false,
        );
        storeA.insertRawExpense(
          spentOn: '2026-11-01',
          groupId: 'g_op',
          title: 'Khoản chi riêng Tenant A',
          amount: 7500000,
        );
        final storeB = FinanceDemoStore(
          clock: fixedClock,
          seedInitialData: false,
        );
        storeB.insertRawExpense(
          spentOn: '2026-11-01',
          groupId: 'g_pe',
          title: 'Khoản chi riêng Tenant B',
          amount: 15000000,
        );

        routes.get('/finance/expense-groups', (_) {
          final s = currentTenant == 'tenant-a' ? storeA : storeB;
          return DemoResponse(200, {
            'success': true,
            'meta': {'year': 2026, 'recurring_templates': s.recurringTemplates},
            'data': s.groups,
          });
        });
        routes.get('/finance/money-accounts', (_) {
          final s = currentTenant == 'tenant-a' ? storeA : storeB;
          return ok(s.accounts);
        });
        routes.get('/finance/expenses', (req) {
          final s = currentTenant == 'tenant-a' ? storeA : storeB;
          return ok(s.buildLedgerResponse(month: req.q('month') ?? '2026-11'));
        });

        final dio = Dio(BaseOptions(baseUrl: 'http://demo.local'))
          ..httpClientAdapter = DemoApiAdapter(routes, latency: Duration.zero);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              dioProvider.overrideWithValue(dio),
              financeClockProvider.overrideWithValue(fixedClock),
              activeTenantIdProvider.overrideWith((_) => 'tenant-a'),
            ],
            child: const MaterialApp(home: ExpensesPage()),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Khoản chi riêng Tenant A'), findsOneWidget);
        expect(find.text('7.500.000'), findsOneWidget);
        expect(find.text('Khoản chi riêng Tenant B'), findsNothing);

        // Chuyển sang Tenant B
        currentTenant = 'tenant-b';
        final container = ProviderScope.containerOf(
          tester.element(find.byType(ExpensesPage)),
        );
        container.read(activeTenantIdProvider.notifier).state = 'tenant-b';
        await tester.pumpAndSettle();

        expect(find.text('Khoản chi riêng Tenant B'), findsOneWidget);
        expect(find.text('15.000.000'), findsOneWidget);
        expect(find.text('Khoản chi riêng Tenant A'), findsNothing);
      },
    );

    testWidgets(
      'Thêm chi phí: gõ "Quảng" gợi ý "Quảng cáo Facebook" + tự gán nhóm Marketing, có Ngày thanh toán riêng và 2 nút Lưu / Lưu & thêm tiếp',
      (tester) async {
        final h = buildTestHarness();
        await tester.pumpWidget(h.app);
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('finance-add-btn')));
        await tester.pumpAndSettle();

        // Khi ô trống: hiện 4 chip cố định trong Wrap gọn gàng, có Ngày thanh toán và 2 nút Lưu
        expect(
          find.byKey(const ValueKey('finance-preset-chips')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('finance-add-paid-date-row')),
          findsOneWidget,
        );
        expect(find.text('Ngày thanh toán'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('finance-save-and-continue-btn')),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey('finance-save-btn')), findsOneWidget);

        // Gõ "Quảng" -> hiện gợi ý "Quảng cáo Facebook" và tự gán nhóm "Tiếp thị & khách"
        await tester.enterText(
          find.byKey(const ValueKey('finance-smart-input')),
          'Quảng',
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('finance-autocomplete-chips')),
          findsOneWidget,
        );
        expect(find.text('Quảng cáo Facebook'), findsOneWidget);
        expect(find.text('Quảng cáo Google Ads'), findsOneWidget);
        expect(find.text('Tiếp thị & khách'), findsOneWidget);

        // Chạm vào chip gợi ý "Quảng cáo Facebook" rồi nhập kèm số tiền 2.5tr
        await tester.tap(
          find.byKey(const ValueKey('finance-suggest-Quảng cáo Facebook')),
        );
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('finance-smart-input')),
          'Quảng cáo Facebook 2.5tr',
        );
        await tester.pumpAndSettle();

        // Bấm "Lưu & thêm tiếp" -> tạo khoản chi thứ nhất lên API nhưng giữ sheet mở để nhập tiếp
        await tester.tap(
          find.byKey(const ValueKey('finance-save-and-continue-btn')),
        );
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();

        expect(
          h.store.expenses.where((e) => e['month'] == '2026-11').length,
          4,
        );
        // Sheet vẫn mở để nhập khoản tiếp theo
        expect(
          find.byKey(const ValueKey('finance-smart-input')),
          findsOneWidget,
        );

        // Nhập khoản thứ 2 và bấm "Lưu khoản chi" -> lưu và đóng sheet
        await tester.enterText(
          find.byKey(const ValueKey('finance-smart-input')),
          'Cước Internet 1.67tr',
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('finance-save-btn')));
        await tester.pumpAndSettle();
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();

        expect(
          h.store.expenses.where((e) => e['month'] == '2026-11').length,
          5,
        );
        expect(find.text('Quảng cáo Facebook'), findsOneWidget);
        expect(find.text('Cước Internet'), findsOneWidget);
      },
    );

    testWidgets(
      'ExpenseSummaryPage trong tab: cuộn hết thì dòng cuối nằm trên thanh tab kính',
      (tester) async {
        // Thanh tab kính phủ lên body (extendBody). Lề đáy cố định 48 nhỏ hơn
        // thanh (78) nên dòng cuối "Phần mềm & dịch vụ" nằm mãi dưới lớp mờ.
        final routes = DemoRoutes();
        registerFinanceDemo(routes, clock: fixedClock, seedInitialData: true);
        final dio = Dio(BaseOptions(baseUrl: 'http://demo.local'))
          ..httpClientAdapter = DemoApiAdapter(routes, latency: Duration.zero);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              dioProvider.overrideWithValue(dio),
              financeClockProvider.overrideWithValue(fixedClock),
            ],
            child: const MaterialApp(
              home: ShellBarInset(
                height: ShellBarInset.barHeight,
                child: ExpenseSummaryPage(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final list = tester.widget<ListView>(
          find
              .descendant(
                of: find.byType(RefreshIndicator),
                matching: find.byType(ListView),
              )
              .first,
        );
        final padding = list.padding!.resolve(TextDirection.ltr);
        expect(padding.bottom, greaterThan(ShellBarInset.barHeight));
      },
    );

    testWidgets(
      'ExpenseSummaryPage — màn độc lập Tổng hợp chi phí theo Tháng, Quý, Năm gọn gàng, chuyển đổi mượt',
      (tester) async {
        tester.view.physicalSize = const Size(840, 2200);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final routes = DemoRoutes();
        registerFinanceDemo(routes, clock: fixedClock, seedInitialData: true);
        final dio = Dio(BaseOptions(baseUrl: 'http://demo.local'))
          ..httpClientAdapter = DemoApiAdapter(routes, latency: Duration.zero);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              dioProvider.overrideWithValue(dio),
              financeClockProvider.overrideWithValue(fixedClock),
            ],
            child: const MaterialApp(home: ExpenseSummaryPage()),
          ),
        );
        await tester.pumpAndSettle();

        // Màn đứng gốc trong bài kiểm: logo thay chữ, tên chỉ để đọc.
        expect(
          find.byWidgetPredicate(
            (w) => w is Semantics && w.properties.label == 'Tổng hợp chi phí',
          ),
          findsOneWidget,
        );
        // Tháng / Quý / Năm là OmniSegmented; kỳ nằm ở nút ‹ kỳ ›, tiêu đề
        // thẻ chỉ còn "Tổng chi" (rà soát 12/11).
        Finder scopeTab(String label) => find.descendant(
          of: find.byKey(const ValueKey('finance-summary-scope')),
          matching: find.text(label),
        );
        expect(scopeTab('Tháng'), findsOneWidget);
        expect(scopeTab('Quý'), findsOneWidget);
        expect(scopeTab('Năm'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('finance-summary-refresh-btn')),
          findsNothing,
        );
        expect(find.text('Quý 4 · 2026'), findsOneWidget);
        expect(find.text('Tổng chi'), findsOneWidget);
        expect(find.text('3 THÁNG TRONG QUÝ 4/2026'), findsNothing);
        expect(find.text('Tháng 10/2026'), findsOneWidget);
        expect(find.text('Tháng 11/2026'), findsOneWidget);
        expect(find.text('Tháng 12/2026'), findsOneWidget);
        // Tiêu đề kể lại "Cơ cấu chi phí trong kỳ" đã bỏ (liquid đợt 3).
        expect(find.text('CƠ CẤU CHI PHÍ TRONG KỲ'), findsNothing);

        final dimAccountBtn = find.byKey(
          const ValueKey('finance-summary-dim-account'),
        );
        await tester.ensureVisible(dimAccountBtn);
        await tester.pumpAndSettle();
        await tester.tap(dimAccountBtn);
        await tester.pumpAndSettle();
        expect(find.textContaining('Tiền mặt'), findsWidgets);

        await tester.tap(scopeTab('Năm'));
        await tester.pumpAndSettle();
        expect(find.text('Năm 2026'), findsOneWidget);
        expect(find.text('DIỄN BIẾN NĂM 2026'), findsNothing);
        expect(
          find.byKey(const ValueKey('finance-summary-year-by-quarter')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('finance-summary-year-by-month')),
          findsOneWidget,
        );

        await tester.tap(scopeTab('Tháng'));
        await tester.pumpAndSettle();
        expect(find.text('Tháng 11 · 2026'), findsOneWidget);
        expect(find.text('SO SÁNH 3 THÁNG GẦN NHẤT'), findsNothing);
      },
    );
  });
}
