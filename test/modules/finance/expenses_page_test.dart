import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/bootstrap.dart';
import 'package:omni_app/core/module/module_registry.dart';
import 'package:omni_app/core/module/nav_destination.dart';
import 'package:omni_app/modules/finance/domain/finance_models.dart';
import 'package:omni_app/modules/finance/domain/finance_permissions.dart';
import 'package:omni_app/modules/finance/finance_module.dart';
import 'package:omni_app/modules/finance/presentation/expenses_page.dart';
import 'package:omni_app/security/permissions/access_policy.dart';
import 'package:omni_app/security/session/session.dart';
import 'package:omni_app/security/session/session_controller.dart';

void main() {
  Widget buildTestApp() {
    return const ProviderScope(child: MaterialApp(home: ExpensesPage()));
  }

  group('FinanceModule — hiển thị trong mục Tất cả (DirectoryPage)', () {
    for (final perm in [
      FinancePermissions.base, // 'finance.expenses'
      FinancePermissions.read, // 'finance.expenses.read'
      FinancePermissions.ordersCost, // 'orders.cost'
      FinancePermissions.membersRead, // 'membership.members.read'
      FinancePermissions.dashboardRead, // 'analytics.dashboard.read'
    ]) {
      test(
        'hiện ô "Sổ chi phí" trong nhóm Đội & quản trị khi có quyền $perm',
        () {
          final container = ProviderContainer(
            overrides: [
              modulesProvider.overrideWithValue(appModules),
              sessionProvider.overrideWithValue(
                Session(
                  status: SessionStatus.authenticated,
                  policy: AccessPolicy({perm}),
                ),
              ),
            ],
          );
          addTearDown(container.dispose);

          final adminEntries =
              container.read(directoryGroupsProvider)[NavArea.admin] ??
              const [];
          expect(adminEntries.map((e) => e.label), contains('Sổ chi phí'));
          expect(
            adminEntries.map((e) => e.routeName),
            contains(FinanceRoutes.expenses),
          );
        },
      );
    }
  });

  group('ExpensesPage — Sổ chi phí (so-chi-phi-mobile.html + PO upgrades)', () {
    testWidgets(
      'hiển thị Tổng chi tháng 11, thẻ 5 Khoản cố định tháng 11 (41.350.000 đ) và danh sách gom theo ngày',
      (tester) async {
        await tester.pumpWidget(buildTestApp());
        await tester.pumpAndSettle();

        expect(find.text('Sổ chi phí'), findsOneWidget);
        expect(find.text('Tổng chi tháng 11'), findsOneWidget);
        expect(find.text('26.650.000'), findsOneWidget);
        expect(find.text('Đã trả'), findsOneWidget);
        expect(find.text('12.730.000 đ'), findsOneWidget);
        expect(find.text('Phải trả'), findsOneWidget);
        expect(find.text('13.920.000 đ'), findsOneWidget);

        // Thẻ 5 khoản cố định đầu tháng 11 theo yêu cầu anh Lê Nguyên
        expect(find.text('Khoản cố định tháng 11'), findsOneWidget);
        expect(find.text('5 khoản · 41.350.000 đ'), findsOneWidget);
        expect(find.text('Ghi tất cả'), findsOneWidget);

        // Mở rộng thẻ Khoản cố định kiểm tra đủ 5 mục
        await tester.tap(find.byKey(const ValueKey('finance-recur-head')));
        await tester.pumpAndSettle();

        expect(find.text('Chi phí kho T11'), findsOneWidget);
        expect(find.text('Điện nước T11'), findsOneWidget);
        expect(find.text('Lương nhân sự T11'), findsOneWidget);
        expect(find.text('Lãi vay T11'), findsOneWidget);
        expect(find.text('Lương kế toán dịch vụ T11'), findsOneWidget);

        // Lịch sử 3 tháng có đủ cho cả 5 khoản cố định
        for (final title in [
          'Chi phí kho',
          'Điện nước',
          'Lương nhân sự',
          'Lãi vay',
          'Lương kế toán dịch vụ',
        ]) {
          expect(FinanceSeedCatalog.historyForTitle(title), isNotNull);
        }
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

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(1.15)),
                child: child!,
              ),
              home: const ExpensesPage(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        for (final textValue in [
          '26.650.000',
          '12.730.000 đ',
          '13.920.000 đ',
          'Khoản cố định tháng 11',
          '5 khoản · 41.350.000 đ',
          '4.500.000 đ',
          '2.450.000 đ',
          '420.000 đ',
          '1.280.000 đ',
          '18.000.000 đ',
          'còn 9.000.000 đ',
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
      'bấm "Ghi tất cả" ghi 5 khoản cố định vào tháng 11 (tổng tăng lên 68.000.000) và có nút Hoàn tác',
      (tester) async {
        await tester.pumpWidget(buildTestApp());
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const ValueKey('finance-recur-commit-all')),
        );
        await tester.pump();

        // Thẻ Khoản cố định ẩn đi sau khi ghi, tổng chi tăng từ 26.65tr + 41.35tr = 68.000.000
        expect(find.text('Khoản cố định tháng 11'), findsNothing);
        expect(find.text('68.000.000'), findsOneWidget);
        expect(find.text('Chi phí kho T11'), findsOneWidget);
        expect(find.text('Lãi vay T11'), findsOneWidget);
        expect(find.text('Hoàn tác'), findsOneWidget);

        // Bấm Hoàn tác khôi phục lại trạng thái ban đầu
        await tester.tap(find.byKey(const ValueKey('finance-undo-btn')));
        await tester.pump(const Duration(seconds: 5));

        expect(find.text('Khoản cố định tháng 11'), findsOneWidget);
        expect(find.text('26.650.000'), findsOneWidget);
      },
    );

    testWidgets(
      'tìm kiếm theo số tiền viết tắt (2.45tr, 420k), số nguyên (1280000) và tên chứng từ đính kèm',
      (tester) async {
        await tester.pumpWidget(buildTestApp());
        await tester.pumpAndSettle();

        // Mở thanh tìm kiếm
        await tester.tap(find.byKey(const ValueKey('finance-search-toggle')));
        await tester.pumpAndSettle();

        final searchInput = find.byKey(const ValueKey('finance-search-input'));
        expect(searchInput, findsOneWidget);

        // 1. Tìm theo số tiền viết tắt "2.45tr" -> khớp "Phí hosting tháng 11" (2.450.000 đ)
        await tester.enterText(searchInput, '2.45tr');
        await tester.pumpAndSettle();
        expect(find.text('Phí hosting tháng 11'), findsOneWidget);
        expect(find.text('Quảng cáo Facebook đầu tháng'), findsNothing);

        // 2. Tìm theo số tiền "420k" -> khớp "Văn phòng phẩm & mực in" (420.000 đ)
        await tester.enterText(searchInput, '420k');
        await tester.pumpAndSettle();
        expect(find.text('Văn phòng phẩm & mực in'), findsOneWidget);
        expect(find.text('Phí hosting tháng 11'), findsNothing);

        // 3. Tìm theo tên tệp chứng từ "Phieu-chi-tien-mat" -> khớp "Tiếp khách đối tác chiến lược"
        await tester.enterText(searchInput, 'Phieu-chi-tien-mat');
        await tester.pumpAndSettle();
        expect(find.text('Tiếp khách đối tác chiến lược'), findsOneWidget);
      },
    );

    testWidgets(
      'sắp xếp đa chiều chuẩn iOS (theo Loại chi phí, Thời gian nhập, Ngày thanh toán, Số tiền)',
      (tester) async {
        await tester.pumpWidget(buildTestApp());
        await tester.pumpAndSettle();

        // Mở menu Sắp xếp
        await tester.tap(find.byKey(const ValueKey('finance-sort-btn')));
        await tester.pumpAndSettle();

        expect(find.text('Ngày ghi nhận (mới nhất)'), findsOneWidget);
        expect(find.text('Thời gian nhập (mới nhập)'), findsOneWidget);
        expect(find.text('Ngày thanh toán (mới trả)'), findsOneWidget);
        expect(find.text('Loại chi phí (theo nhóm)'), findsOneWidget);
        expect(find.text('Số tiền (cao › thấp)'), findsOneWidget);

        // Chọn "Loại chi phí (theo nhóm)"
        await tester.tap(find.text('Loại chi phí (theo nhóm)'));
        await tester.pumpAndSettle();

        expect(find.text('Đang lọc: Loại chi phí (theo nhóm)'), findsOneWidget);
        expect(find.text('Nhân sự & tiền lương'), findsWidgets);
        expect(find.text('Tiếp thị & bán hàng'), findsWidgets);
      },
    );

    testWidgets(
      'Sheet Chi tiết hiển thị chứng từ đính kèm, thời gian nhập và 1 pill xanh gọn nhẹ khi trả đủ 1 lần',
      (tester) async {
        await tester.pumpWidget(buildTestApp());
        await tester.pumpAndSettle();

        // Mở khoản chi tiền mặt có đính kèm phiếu chi ("Tiếp khách đối tác chiến lược")
        final cashItemFinder = find.text('Tiếp khách đối tác chiến lược');
        await tester.ensureVisible(cashItemFinder);
        await tester.pumpAndSettle();
        await tester.tap(cashItemFinder);
        await tester.pumpAndSettle();

        expect(find.text('Đã trả đủ · 01/11'), findsOneWidget);
        expect(find.text('1 chứng từ'), findsOneWidget);
        expect(find.text('Phieu-chi-tien-mat-0111.jpg'), findsOneWidget);
        expect(find.text('Nhập lúc 01/11 14:20'), findsOneWidget);
        expect(find.textContaining('Lần 1 ·'), findsNothing);

        // Đóng sheet
        await tester.tap(find.byTooltip('Đóng'));
        await tester.pumpAndSettle();

        // Mở khoản trả một phần ("Tạm ứng lương bộ phận KD")
        await tester.tap(find.text('Tạm ứng lương bộ phận KD'));
        await tester.pumpAndSettle();

        expect(find.text('Đã trả 9.000.000 đ'), findsOneWidget);
        expect(find.text('Còn 9.000.000 đ'), findsOneWidget);
        expect(find.text('Trả · 9.000.000 đ'), findsOneWidget);
      },
    );
  });
}
