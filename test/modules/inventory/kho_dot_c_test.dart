import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/modules/inventory/application/inventory_providers.dart';
import 'package:omni_app/modules/inventory/domain/inventory_models.dart';
import 'package:omni_app/modules/inventory/domain/inventory_permissions.dart';
import 'package:omni_app/modules/inventory/presentation/counts_page.dart';
import 'package:omni_app/modules/inventory/presentation/delivered_page.dart';
import 'package:omni_app/modules/inventory/presentation/stock_page.dart';
import 'package:omni_app/security/permissions/access_policy.dart';
import 'package:omni_app/security/session/session_controller.dart';

import 'fake_inventory_api.dart';

/// Kho chuẩn hóa Đợt C trên app: Kiểm kê (gõ serial để tick, tick tay, đếm
/// hàng số lượng, chốt, duyệt), Hàng đã giao (phiếu xuất, giá bán, hóa đơn,
/// Nhập lại kho, Mở việc bảo hành). Phần mới chỉ hiện khi API có capability;
/// mỗi lần ghi gửi đúng khoá và màn đọc lại thấy giá trị mới.
void main() {
  final today = DateTime(2026, 11, 11);

  const old = InventoryPerms(
    read: true,
    write: true,
    reserve: true,
    sell: true,
    locations: true,
  );
  const all = InventoryPerms(
    read: true,
    write: true,
    reserve: true,
    sell: true,
    workshop: true,
    locations: true,
    products: true,
    stockQty: true,
    invoices: true,
    delivered: true,
    returns: true,
    counts: true,
    doCounts: true,
    approveCounts: true,
    slips: true,
  );
  const viewer = InventoryPerms(
    read: true,
    locations: true,
    counts: true,
    delivered: true,
  );

  const locations = [
    StockLocation(id: 'main', name: 'Kho chính', isDefault: true),
    StockLocation(id: 'p1', name: 'Showroom Q7', kind: 'showroom'),
  ];

  const u1 = InventoryUnit(
    id: 'u1',
    lotId: 'l62',
    lotCode: 'Ep 62',
    maker: 'YAMAHA',
    model: 'U1H',
    serial: 'B62-3',
    place: UnitPlace.inStock,
    condition: UnitCondition.ready,
    locationId: 'main',
    locationName: 'Kho chính',
  );
  const u2 = InventoryUnit(
    id: 'u2',
    lotId: 'l62',
    lotCode: 'Ep 62',
    maker: 'KAWAI',
    model: 'BL71',
    serial: 'K-881',
    place: UnitPlace.inStock,
    locationId: 'main',
    locationName: 'Kho chính',
  );
  const u9 = InventoryUnit(
    id: 'u9',
    lotId: 'l61',
    lotCode: 'Ep 61',
    maker: 'YAMAHA',
    model: 'U3H',
    serial: 'B61-7',
    place: UnitPlace.delivered,
    sale: UnitSale.sold,
    customerId: 'c1',
    customerName: 'Anh Dũng Hoàng',
    deliveredAt: '2026-11-10T10:00:00+07:00',
    slipNo: 'PX-2611-001',
    soldPrice: 52000000,
    invoice: UnitInvoice(status: InvoiceStatus.pending),
  );
  const ghe = InvProduct(
    id: 'p-ghe',
    code: 'GHE-01',
    name: 'Ghế đàn nâng hạ',
    unit: 'Chiếc',
    tracking: ProductTracking.qty,
    onHand: 10,
    stock: [(locationId: 'main', qty: 10)],
  );
  const slip = Slip(
    no: 'PX-2611-001',
    date: '2026-11-10',
    customerName: 'Anh Dũng Hoàng',
    lines: [
      SlipLine(
        name: 'YAMAHA U3H',
        serial: 'B61-7',
        price: 52000000,
        amount: 52000000,
      ),
      SlipLine(
        name: 'Ghế đàn nâng hạ',
        unit: 'Chiếc',
        qty: 2,
        price: 1500000,
        amount: 3000000,
      ),
    ],
    total: 55000000,
  );

  void phone(WidgetTester t) {
    t.view.physicalSize = const Size(390, 1800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
  }

  FakeInventoryApi fake() =>
      FakeInventoryApi(
          units: const [u1, u2, u9],
          multiLocation: true,
          locations: locations,
        )
        ..products = [ghe]
        ..slips = {'PX-2611-001': slip};

  Widget app(FakeInventoryApi api, InventoryPerms perms, Widget home) =>
      ProviderScope(
        overrides: [
          inventoryApiProvider.overrideWithValue(api),
          inventoryPermsProvider.overrideWithValue(perms),
          inventoryTodayProvider.overrideWithValue(today),
          workshopPlansProvider.overrideWith(
            (ref) async => const [
              (id: 'plan-bh', name: 'Bảo hành 2026', sections: []),
            ],
          ),
          accessProvider.overrideWithValue(AccessPolicy(const {})),
        ],
        child: MaterialApp(home: home),
      );

  Finder field(String key) => find.descendant(
    of: find.byKey(ValueKey(key)),
    matching: find.byType(TextField),
  );

  group('Lối vào trên Tồn kho', () {
    testWidgets('API thiếu capability Đợt C: không có nút ⋯', (t) async {
      phone(t);
      await t.pumpWidget(app(fake(), old, const StockPage()));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('inv-open-more')), findsNothing);
    });

    testWidgets('có capability: ⋯ mở menu Kiểm kê, Hàng đã giao', (t) async {
      phone(t);
      await t.pumpWidget(app(fake(), all, const StockPage()));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('inv-open-more')));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('inv-open-counts')), findsOneWidget);
      expect(find.byKey(const ValueKey('inv-open-delivered')), findsOneWidget);
    });
  });

  group('Kiểm kê', () {
    testWidgets('mở phiên, gõ serial để tick, đếm số lượng, chốt, duyệt', (
      t,
    ) async {
      phone(t);
      final api = fake();
      await t.pumpWidget(app(api, all, const CountsPage()));
      await t.pumpAndSettle();
      // Hai vị trí: có dòng chọn vị trí, mặc định đứng đầu.
      expect(find.text('Kho chính'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('inv-count-start')));
      await t.pumpAndSettle();
      expect(api.countSteps, ['open main']);
      expect(find.text('0 / 2 cây'), findsOneWidget);

      // Gõ serial (khác hoa thường, thêm khoảng trắng): khớp đúng một cây.
      await t.enterText(field('inv-count-serial'), ' b62-3 ');
      await t.pump(const Duration(milliseconds: 400));
      await t.pump();
      expect(find.text('1 / 2 cây'), findsOneWidget);
      // Cây vừa thấy hiện ngay dưới Đã thấy.
      expect(find.text('YAMAHA U1H B62-3'), findsOneWidget);
      // Ô serial được xoá để gõ cây tiếp.
      expect(
        t.widget<TextField>(field('inv-count-serial')).controller!.text,
        '',
      );
      // Lưu ngầm sau một nhịp.
      await t.pump(const Duration(milliseconds: 800));
      expect(api.countSaves.last.$2, ['u1']);

      // Đếm hàng số lượng bằng bàn phím số.
      await t.tap(find.byKey(const ValueKey('inv-count-qty-p-ghe')));
      await t.pumpAndSettle();
      for (var i = 0; i < 6; i++) {
        await t.tap(find.byKey(const ValueKey('inv-key-del')));
      }
      await t.tap(find.byKey(const ValueKey('inv-key-9')));
      await t.pump();
      await t.tap(find.byKey(const ValueKey('inv-keypad-done')));
      await t.pumpAndSettle();
      expect(find.text('9 Chiếc'), findsOneWidget);
      await t.pump(const Duration(milliseconds: 800));
      expect(api.countSaves.last.$3, {'p-ghe': 9});

      // Chốt: cây chưa tick thành Không thấy (đợi thông báo đè nút tắt).
      await t.pump(const Duration(seconds: 5));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('inv-count-submit')));
      await t.pumpAndSettle();
      expect(find.text('1 cây chưa tick sẽ ghi Không thấy.'), findsOneWidget);
      await t.tap(find.text('Chốt'));
      await t.pumpAndSettle();
      expect(api.countSteps.last, 'submit cnt1');
      expect(api.counts.single.seenUnitIds, ['u1']);
      expect(find.text('Chờ duyệt'), findsOneWidget);
      expect(find.byKey(const ValueKey('inv-count-miss-u2')), findsOneWidget);
      expect(find.text('K-881'), findsOneWidget);

      // Duyệt (inventory.settings).
      await t.pump(const Duration(seconds: 5));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('inv-count-approve')));
      await t.pumpAndSettle();
      await t.tap(find.text('Duyệt').last);
      await t.pumpAndSettle();
      expect(api.countSteps.last, 'approve cnt1');
      expect(find.text('Đã duyệt'), findsOneWidget);
      // Duyệt xong: mở được phiên mới.
      expect(find.byKey(const ValueKey('inv-count-start')), findsOneWidget);
    });

    testWidgets('tick tay bằng chạm dòng; đổi vị trí đọc phiên vị trí đó', (
      t,
    ) async {
      phone(t);
      final api = fake();
      await t.pumpWidget(app(api, all, const CountsPage()));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('inv-count-start')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('inv-count-unit-u2')));
      await t.pump(const Duration(milliseconds: 800));
      expect(api.countSaves.last.$2, ['u2']);
      await t.tap(find.byKey(const ValueKey('inv-count-tick-all')));
      await t.pump(const Duration(milliseconds: 800));
      expect(api.countSaves.last.$2!.toSet(), {'u1', 'u2'});
      expect(find.text('2 / 2 cây'), findsOneWidget);

      await t.tap(find.byKey(const ValueKey('inv-count-location')));
      await t.pumpAndSettle();
      await t.tap(find.text('Showroom Q7'));
      await t.pumpAndSettle();
      // Đợi thông báo trước tắt (nó nằm đè nút dưới).
      await t.pump(const Duration(seconds: 5));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('inv-count-start')), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('inv-count-start')));
      await t.pumpAndSettle();
      expect(api.countSteps.last, 'open p1');
      expect(find.text('Không có cây ở vị trí này'), findsOneWidget);
    });

    testWidgets('chỉ quyền xem: không mở / tick / duyệt được', (t) async {
      phone(t);
      final api = fake()
        ..counts = [
          const StockCount(
            id: 'cnt1',
            locationId: 'main',
            status: CountStatus.submitted,
            seenUnitIds: ['u1'],
            missingUnitIds: ['u2'],
            missingUnits: [
              (unitId: 'u2', label: 'KAWAI BL71', serial: 'K-881'),
            ],
            submittedAt: '2026-11-11T09:00:00+07:00',
          ),
        ];
      await t.pumpWidget(app(api, viewer, const CountsPage()));
      await t.pumpAndSettle();
      expect(find.text('Chờ duyệt'), findsOneWidget);
      expect(find.byKey(const ValueKey('inv-count-approve')), findsNothing);
      expect(find.byKey(const ValueKey('inv-count-start')), findsNothing);
      expect(find.byKey(const ValueKey('inv-count-serial')), findsNothing);
    });
  });

  group('Hàng đã giao', () {
    testWidgets('dòng cây: khách, phiếu, ngày giao, giá bán đủ số, hóa đơn', (
      t,
    ) async {
      phone(t);
      final api = fake();
      await t.pumpWidget(app(api, all, const DeliveredPage()));
      await t.pumpAndSettle();
      expect(api.listCalls.last['place'], 'delivered');
      final row = find.byKey(const ValueKey('inv-delivered-u9'));
      expect(row, findsOneWidget);
      expect(
        find.descendant(
          of: row,
          matching: find.text('Anh Dũng Hoàng · PX-2611-001 · 10/11/2026'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: row, matching: find.textContaining('52.000.000')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: row, matching: find.text('Chưa xuất')),
        findsOneWidget,
      );
      // Cây trong kho không lẫn vào.
      expect(find.byKey(const ValueKey('inv-delivered-u1')), findsNothing);
    });

    testWidgets('chi tiết cây: phiếu xuất mở sheet phiếu; hóa đơn chỉ xem', (
      t,
    ) async {
      phone(t);
      await t.pumpWidget(app(fake(), all, const DeliveredPage()));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('inv-delivered-u9')));
      await t.pumpAndSettle();
      final inv = find.byKey(const ValueKey('inv-unit-invoice'));
      expect(
        find.descendant(of: inv, matching: find.text('Chưa xuất')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('inv-unit-sold-price')),
          matching: find.textContaining('52.000.000'),
        ),
        findsOneWidget,
      );
      await t.tap(find.byKey(const ValueKey('inv-unit-slip')));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('inv-slip-line-1')), findsOneWidget);
      expect(find.text('2 Chiếc × 1.500.000đ'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('inv-slip-total')),
          matching: find.textContaining('55.000.000'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('Nhập lại kho: vị trí, tình trạng, ghi chú; rời danh sách', (
      t,
    ) async {
      phone(t);
      final api = fake();
      await t.pumpWidget(app(api, all, const DeliveredPage()));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('inv-delivered-u9')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('inv-unit-return')));
      await t.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('inv-return-condition')),
          matching: find.text('Chưa kiểm'),
        ),
        findsOneWidget,
      );
      await t.tap(find.byKey(const ValueKey('inv-return-location')));
      await t.pumpAndSettle();
      await t.tap(find.text('Showroom Q7'));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('inv-return-condition')));
      await t.pumpAndSettle();
      await t.tap(find.text('Lỗi'));
      await t.pumpAndSettle();
      await t.enterText(
        find.byKey(const ValueKey('inv-return-note')),
        'Khách trả',
      );
      await t.tap(find.byKey(const ValueKey('inv-return-save')));
      await t.pumpAndSettle();
      expect(api.returns.single.$1, 'u9');
      expect(api.returns.single.$2, {
        'location_id': 'p1',
        'condition': 'defective',
        'note': 'Khách trả',
      });
      // Đọc lại: cây về kho, không còn trong Hàng đã giao.
      expect(
        api.units.firstWhere((u) => u.id == 'u9').place,
        UnitPlace.inStock,
      );
      expect(find.byKey(const ValueKey('inv-delivered-u9')), findsNothing);
      expect(find.text('Không có cây khớp'), findsOneWidget);
    });

    testWidgets('Mở việc bảo hành: chọn kế hoạch, gửi đúng cây', (t) async {
      phone(t);
      final api = fake();
      await t.pumpWidget(app(api, all, const DeliveredPage()));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('inv-delivered-u9')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('inv-unit-warranty')));
      await t.pumpAndSettle();
      await t.tap(find.text('Bảo hành 2026'));
      await t.pumpAndSettle();
      expect(api.workshopSends.single, {
        'project_id': 'plan-bh',
        'unit_ids': ['u9'],
      });
      expect(find.text('Đã mở việc bảo hành.'), findsOneWidget);
    });

    testWidgets('chỉ quyền xem: không có nút Nhập lại kho / bảo hành', (
      t,
    ) async {
      phone(t);
      await t.pumpWidget(app(fake(), viewer, const DeliveredPage()));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('inv-delivered-u9')));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('inv-unit-return')), findsNothing);
      expect(find.byKey(const ValueKey('inv-unit-warranty')), findsNothing);
      // Thiếu `inventory.invoices`: không hiện hóa đơn.
      expect(find.byKey(const ValueKey('inv-unit-invoice')), findsNothing);
    });
  });
}
