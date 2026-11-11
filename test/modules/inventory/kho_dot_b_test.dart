import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/modules/inventory/application/inventory_providers.dart';
import 'package:omni_app/modules/inventory/domain/inventory_models.dart';
import 'package:omni_app/modules/inventory/domain/inventory_permissions.dart';
import 'package:omni_app/modules/inventory/presentation/catalog_page.dart';
import 'package:omni_app/modules/inventory/presentation/reservations_page.dart';
import 'package:omni_app/modules/inventory/presentation/stock_page.dart';
import 'package:omni_app/modules/inventory/presentation/widgets/sell_sheet.dart';
import 'package:omni_app/security/permissions/access_policy.dart';
import 'package:omni_app/security/session/session_controller.dart';

import 'fake_inventory_api.dart';

/// Kho chuẩn hóa Đợt B trên app: Danh mục hàng, Đang giữ, Bán có bậc giá +
/// dòng số lượng + giữ hàng có ngày cọc / hạn. Phần mới chỉ hiện khi API có
/// capability; mỗi lần ghi gửi đúng khoá và màn đọc lại thấy giá trị mới.
void main() {
  final today = DateTime(2026, 11, 10);

  const old = InventoryPerms(
    read: true,
    write: true,
    reserve: true,
    cost: true,
    pay: true,
    sell: true,
  );
  const all = InventoryPerms(
    read: true,
    write: true,
    reserve: true,
    cost: true,
    pay: true,
    sell: true,
    locations: true,
    products: true,
    editProducts: true,
    stockQty: true,
    adjustStock: true,
    reservations: true,
  );

  const locations = [
    StockLocation(id: 'main', name: 'Kho chính', isDefault: true),
    StockLocation(id: 'p1', name: 'Showroom Q7', kind: 'showroom'),
  ];

  InvProduct ghe() => const InvProduct(
    id: 'p-ghe',
    code: 'GHE-01',
    name: 'Ghế đàn nâng hạ',
    categoryId: 'c-ghe',
    categoryName: 'Ghế',
    unit: 'Chiếc',
    tracking: ProductTracking.qty,
    prices: {PriceTierKey.wholesale: 1200000, PriceTierKey.retail: 1500000},
    fixedCost: 800000,
    onHand: 12,
    available: 12,
    stock: [(locationId: 'main', qty: 10), (locationId: 'p1', qty: 2)],
  );
  InvProduct u1h() => const InvProduct(
    id: 'p-u1h',
    code: 'U1H',
    name: 'YAMAHA U1H',
    categoryId: 'c-co',
    categoryName: 'Piano cơ',
    unit: 'Chiếc',
    prices: {PriceTierKey.wholesale: 48000000},
    onHand: 3,
    available: 3,
  );

  const unit = InventoryUnit(
    id: 'u1',
    lotId: 'l62',
    maker: 'YAMAHA',
    model: 'U1H',
    serial: 'B62-3',
    listPrice: 50000000,
    wholesalePrice: 48000000,
    place: UnitPlace.inStock,
  );
  const customer = InventoryCustomer(id: 'c1', name: 'Anh Dũng Hoàng');

  void phone(WidgetTester t) {
    t.view.physicalSize = const Size(390, 1800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
  }

  FakeInventoryApi fake() =>
      FakeInventoryApi(
          units: const [unit],
          customers: const [customer],
          multiLocation: true,
          locations: locations,
          accounts: const [MoneyAccount(id: 'acc-vcb', name: 'VCB')],
        )
        ..products = [ghe(), u1h()]
        ..categories = const [
          InvCategory(id: 'c-co', name: 'Piano cơ'),
          InvCategory(id: 'c-ghe', name: 'Ghế', order: 1),
        ];

  Widget app(FakeInventoryApi api, InventoryPerms perms, Widget home) =>
      ProviderScope(
        overrides: [
          inventoryApiProvider.overrideWithValue(api),
          inventoryPermsProvider.overrideWithValue(perms),
          inventoryTodayProvider.overrideWithValue(today),
          workshopPlansProvider.overrideWith((ref) async => const []),
          accessProvider.overrideWithValue(AccessPolicy(const {})),
        ],
        child: MaterialApp(home: home),
      );

  Future<void> keypad(WidgetTester t, String digits) async {
    // Xoá số cũ rồi gõ số mới.
    for (var i = 0; i < 12; i++) {
      await t.tap(find.byKey(const ValueKey('inv-key-del')));
    }
    for (final d in digits.split('')) {
      await t.tap(find.byKey(ValueKey('inv-key-$d')));
    }
    await t.pump();
    await t.tap(find.byKey(const ValueKey('inv-keypad-done')));
    await t.pumpAndSettle();
  }

  group('Danh mục hàng', () {
    testWidgets('dòng mã hàng: giá theo bậc đủ số, tồn; lọc theo loại', (
      t,
    ) async {
      phone(t);
      final api = fake();
      await t.pumpWidget(app(api, all, const CatalogPage()));
      await t.pumpAndSettle();

      expect(find.text('2 mã hàng'), findsOneWidget);
      expect(
        find.text('Giá sỉ 1.200.000đ · Giá lẻ 1.500.000đ'),
        findsOneWidget,
      );
      // Cây serial: chỉ giá sỉ từ mã hàng (giá lẻ theo từng cây).
      expect(find.text('Giá sỉ 48.000.000đ'), findsOneWidget);
      expect(find.text('GHE-01 · Ghế'), findsOneWidget);

      await t.tap(find.byKey(const ValueKey('inv-catalog-category')));
      await t.pumpAndSettle();
      await t.tap(find.text('Ghế').last);
      await t.pumpAndSettle();
      expect(api.productQueries.last['category_id'], 'c-ghe');
      expect(find.text('1 mã hàng'), findsOneWidget);
    });

    testWidgets('sửa giá sỉ trong sheet: gửi đúng bậc, dòng đọc lại giá mới', (
      t,
    ) async {
      phone(t);
      final api = fake();
      await t.pumpWidget(app(api, all, const CatalogPage()));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('inv-product-p-ghe')));
      await t.pumpAndSettle();

      expect(find.byKey(const ValueKey('inv-product-prices')), findsOneWidget);
      expect(find.text('800.000đ'), findsOneWidget); // giá vốn
      expect(find.text('Showroom Q7'), findsOneWidget);

      await t.tap(find.byKey(const ValueKey('inv-product-price-wholesale')));
      await t.pumpAndSettle();
      await keypad(t, '1300000');

      final up = api.productUpdates.single;
      expect((up.$1, up.$2), ('p-ghe', null));
      expect(up.$3, {PriceTierKey.wholesale: 1300000});
      expect(find.text('1.300.000đ'), findsWidgets);
      expect(api.products.first.priceOf(PriceTierKey.wholesale), 1300000);
    });

    testWidgets('nhập hàng số lượng và đặt số thật có ghi chú', (t) async {
      phone(t);
      final api = fake();
      await t.pumpWidget(app(api, all, const CatalogPage()));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('inv-product-p-ghe')));
      await t.pumpAndSettle();

      await t.tap(find.byKey(const ValueKey('inv-product-receive')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('inv-stock-qty')));
      await t.pumpAndSettle();
      await keypad(t, '5');
      await t.tap(find.byKey(const ValueKey('inv-stock-save')));
      await t.pumpAndSettle();
      expect(api.stockWrites.last.$1, 'receive');
      expect(api.stockWrites.last.$2, {
        'product_id': 'p-ghe',
        'qty': 5,
        'location_id': null,
        'unit_cost': null,
      });
      expect(find.text('17 Chiếc'), findsOneWidget);

      await t.tap(find.byKey(const ValueKey('inv-product-adjust')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('inv-stock-qty')));
      await t.pumpAndSettle();
      await keypad(t, '9');
      // Thiếu ghi chú thì chưa lưu được.
      expect(
        t
            .widget<FilledButton>(find.byKey(const ValueKey('inv-stock-save')))
            .onPressed,
        isNull,
      );
      await t.enterText(
        find.byKey(const ValueKey('inv-stock-note')),
        'Kiểm kê',
      );
      await t.pump();
      await t.tap(find.byKey(const ValueKey('inv-stock-save')));
      await t.pumpAndSettle();
      expect(api.stockWrites.last.$1, 'adjust');
      expect(api.stockWrites.last.$2, {
        'product_id': 'p-ghe',
        'location_id': 'main',
        'qty': 9,
        'note': 'Kiểm kê',
      });
      expect(find.text('Đã đặt số thật · -1 Chiếc.'), findsOneWidget);
    });

    testWidgets('thiếu quyền thiết lập: không sửa giá, không đặt số thật', (
      t,
    ) async {
      phone(t);
      await t.pumpWidget(
        app(
          fake(),
          const InventoryPerms(
            read: true,
            products: true,
            stockQty: true,
            locations: true,
          ),
          const CatalogPage(),
        ),
      );
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('inv-product-p-ghe')));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('inv-product-adjust')), findsNothing);
      expect(find.byKey(const ValueKey('inv-product-receive')), findsNothing);
      expect(find.byKey(const ValueKey('inv-product-rename')), findsNothing);
      // Giá chỉ xem: chạm không mở bàn phím.
      await t.tap(
        find.byKey(const ValueKey('inv-product-price-wholesale')),
        warnIfMissed: false,
      );
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('inv-keypad-done')), findsNothing);
    });

    testWidgets('API thiếu inventory.products: màn trống, không gọi API', (
      t,
    ) async {
      phone(t);
      final api = fake();
      await t.pumpWidget(app(api, old, const CatalogPage()));
      await t.pumpAndSettle();
      expect(find.text('Chưa có danh mục hàng'), findsOneWidget);
      expect(api.productQueries, isEmpty);
    });
  });

  group('Đang giữ', () {
    final res = [
      const Reservation(
        id: 'r1',
        customerName: 'Anh Dũng Hoàng',
        lines: [
          ReservationLine(
            unitId: 'u1',
            label: 'YAMAHA U3H',
            serial: 'B62-2',
            price: 47500000,
          ),
        ],
        total: 47500000,
        deposit: ReservationDeposit(
          amount: 5000000,
          paidAt: '2026-11-09',
          moneyAccountId: 'acc-vcb',
        ),
        expiresAt: '2026-11-08',
      ),
      const Reservation(
        id: 'r2',
        status: ReservationStatus.released,
        customerName: 'Chị Lan',
        total: 32000000,
      ),
    ];

    testWidgets('lọc trạng thái, dòng có cọc + hạn; mở phiếu xem cọc', (
      t,
    ) async {
      phone(t);
      final api = fake()..reservations = res;
      await t.pumpWidget(app(api, all, const ReservationsPage()));
      await t.pumpAndSettle();

      expect(api.reservationQueries.last, ReservationStatus.active);
      expect(find.text('Anh Dũng Hoàng'), findsOneWidget);
      expect(find.text('Chị Lan'), findsNothing);
      expect(find.text('YAMAHA U3H B62-2'), findsOneWidget);
      expect(find.text('47.500.000đ'), findsOneWidget);
      expect(find.text('cọc 5.000.000đ'), findsOneWidget);
      expect(find.text('hạn 08/11/2026'), findsOneWidget);

      await t.tap(find.byKey(const ValueKey('inv-res-r1')));
      await t.pumpAndSettle();
      expect(find.text('Ngày nhận cọc'), findsOneWidget);
      expect(find.text('09/11/2026'), findsOneWidget);
      expect(find.text('VCB'), findsOneWidget);
      expect(find.text('quá hạn'), findsOneWidget);
      await t.tapAt(const Offset(10, 10));
      await t.pumpAndSettle();

      await t.tap(find.text('Bỏ giữ'));
      await t.pumpAndSettle();
      expect(api.reservationQueries.last, ReservationStatus.released);
      expect(find.text('Chị Lan'), findsOneWidget);
    });

    testWidgets('API thiếu inventory.reservations: không có màn', (t) async {
      phone(t);
      final api = fake()..reservations = res;
      await t.pumpWidget(app(api, old, const ReservationsPage()));
      await t.pumpAndSettle();
      expect(find.text('Chưa có phiếu giữ hàng'), findsOneWidget);
      expect(api.reservationQueries, isEmpty);
    });
  });

  group('Tồn kho', () {
    testWidgets('lối vào Danh mục hàng / Đang giữ chỉ khi có capability', (
      t,
    ) async {
      phone(t);
      await t.pumpWidget(app(fake(), old, const StockPage()));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('inv-open-catalog')), findsNothing);
      expect(find.byKey(const ValueKey('inv-open-reservations')), findsNothing);

      await t.pumpWidget(app(fake(), all, const StockPage()));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('inv-open-catalog')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('inv-open-reservations')),
        findsOneWidget,
      );
    });
  });

  group('Bán / Đặt trước', () {
    Future<FakeInventoryApi> pump(
      WidgetTester t, {
      InventoryPerms perms = all,
      List<InventoryUnit> units = const [unit],
      List<InvProduct> products = const [],
    }) async {
      phone(t);
      final api = fake();
      await t.pumpWidget(
        app(
          api,
          perms,
          Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: FilledButton(
                  onPressed: () =>
                      openSellSheet(context, units: units, products: products),
                  child: const Text('mở'),
                ),
              ),
            ),
          ),
        ),
      );
      await t.tap(find.text('mở'));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('inv-cust-c1')));
      await t.pumpAndSettle();
      return api;
    }

    testWidgets('bậc giá: Giá sỉ điền giá sỉ của cây; bậc tên null bị ẩn', (
      t,
    ) async {
      final api = await pump(t);
      expect(
        find.byKey(const ValueKey('inv-sell-tier-wholesale')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('inv-sell-tier-tier3')), findsNothing);
      expect(find.text('50.000.000đ'), findsWidgets);

      await t.tap(find.byKey(const ValueKey('inv-sell-tier-wholesale')));
      await t.pumpAndSettle();
      expect(find.text('48.000.000đ'), findsWidgets);

      await t.tap(find.text('Tạo đơn ngay'));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('inv-sell-save')));
      await t.pumpAndSettle();
      expect(api.sells.single['prices'], {'u1': 48000000});
    });

    testWidgets('tạo đơn kèm dòng hàng số lượng: items[] đúng số, đúng giá', (
      t,
    ) async {
      final api = await pump(t);
      await t.tap(find.text('Tạo đơn ngay'));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('inv-sell-tier-wholesale')));
      await t.pumpAndSettle();

      await t.tap(find.byKey(const ValueKey('inv-sell-add-item')));
      await t.pumpAndSettle();
      await t.tap(find.text('GHE-01 · Ghế đàn nâng hạ · 12 Chiếc'));
      await t.pumpAndSettle();
      // Dòng mới lấy giá theo bậc đang chọn; tăng lên 2.
      expect(find.text('1.200.000đ / Chiếc · còn 12'), findsOneWidget);
      await t.tap(
        find.descendant(
          of: find.byKey(const ValueKey('inv-sell-item-p-ghe')),
          matching: find.byTooltip('Thêm'),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('50.400.000đ'), findsOneWidget); // 48tr + 2 × 1,2tr

      await t.tap(find.byKey(const ValueKey('inv-sell-save')));
      await t.pumpAndSettle();
      expect(api.sells.single['unit_ids'], ['u1']);
      expect(api.sells.single['items'], [
        {'product_id': 'p-ghe', 'qty': 2, 'price': 1200000},
      ]);
    });

    testWidgets('bán riêng hàng số lượng từ Danh mục: không có Đặt trước', (
      t,
    ) async {
      final api = await pump(t, units: const [], products: [ghe()]);
      expect(find.text('Đặt trước'), findsNothing);
      expect(find.text('Bán hàng'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('inv-sell-save')));
      await t.pumpAndSettle();
      expect(api.sells.single['unit_ids'], isEmpty);
      expect(api.sells.single['items'], [
        {'product_id': 'p-ghe', 'qty': 1, 'price': 1500000},
      ]);
    });

    testWidgets('giữ hàng có cọc: ngày nhận cọc, nguồn tiền, hạn giữ', (
      t,
    ) async {
      final api = await pump(t);
      // Đặt trước: không có dòng hàng số lượng.
      expect(find.byKey(const ValueKey('inv-sell-items')), findsNothing);
      expect(find.byKey(const ValueKey('inv-sell-paid-at')), findsNothing);
      await t.tap(find.byKey(const ValueKey('inv-sell-deposit')));
      await t.pumpAndSettle();
      await keypad(t, '5000000');

      expect(find.text('10/11/2026'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('inv-sell-account')));
      await t.pumpAndSettle();
      await t.tap(find.text('VCB'));
      await t.pumpAndSettle();

      await t.tap(find.byKey(const ValueKey('inv-sell-save')));
      await t.pumpAndSettle();
      expect(api.reserves.single, {
        'unit_ids': ['u1'],
        'customer_id': 'c1',
        'retail': false,
        'prices': {'u1': 50000000},
        'deposit': 5000000,
        'deposit_paid_at': '2026-11-10',
        'money_account_id': 'acc-vcb',
      });
    });

    testWidgets('API cũ: không bậc giá, không dòng số lượng, không khoá mới', (
      t,
    ) async {
      final api = await pump(t, perms: old);
      expect(find.byKey(const ValueKey('inv-sell-tiers')), findsNothing);
      await t.tap(find.byKey(const ValueKey('inv-sell-deposit')));
      await t.pumpAndSettle();
      await keypad(t, '1000000');
      expect(find.byKey(const ValueKey('inv-sell-paid-at')), findsNothing);
      expect(find.byKey(const ValueKey('inv-sell-expires')), findsNothing);
      await t.tap(find.byKey(const ValueKey('inv-sell-save')));
      await t.pumpAndSettle();
      expect(api.reserves.single.keys, isNot(contains('deposit_paid_at')));

      await t.tap(find.text('mở'));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('inv-cust-c1')));
      await t.pumpAndSettle();
      await t.tap(find.text('Tạo đơn ngay'));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('inv-sell-items')), findsNothing);
    });
  });

  group('Quyền & capability', () {
    test('phần Đợt B theo capability riêng; sửa / đặt số thật cần quyền', () {
      final reader = AccessPolicy({'inventory.read'});
      final none = InventoryPerms.from(capable: true, policy: reader);
      expect([
        none.products,
        none.stockQty,
        none.reservations,
      ], everyElement(isFalse));
      final caps = {
        'inventory.products',
        'inventory.stock_qty',
        'inventory.reservations',
      };
      final r = InventoryPerms.from(
        capable: true,
        policy: reader,
        supports: caps.contains,
      );
      expect([r.products, r.stockQty, r.reservations], everyElement(isTrue));
      expect([r.editProducts, r.adjustStock], everyElement(isFalse));
      final admin = InventoryPerms.from(
        capable: true,
        policy: AccessPolicy({'inventory.read', 'inventory.settings'}),
        supports: caps.contains,
      );
      expect([admin.editProducts, admin.adjustStock], everyElement(isTrue));
      // Có stock_qty mà thiếu products: không có hàng số lượng.
      final half = InventoryPerms.from(
        capable: true,
        policy: reader,
        supports: {'inventory.stock_qty'}.contains,
      );
      expect(half.stockQty, isFalse);
    });
  });
}
