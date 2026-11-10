import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/modules/inventory/application/inventory_providers.dart';
import 'package:omni_app/modules/inventory/domain/inventory_models.dart';
import 'package:omni_app/modules/inventory/domain/inventory_permissions.dart';
import 'package:omni_app/modules/inventory/presentation/stock_page.dart';

import 'fake_inventory_api.dart';

/// Màn Tồn kho với API giả: dòng tổng ngắn, tiền đủ số, khoá theo quyền,
/// serial chạm để sửa, đổi phân đoạn Còn bán / Đã có khách.
void main() {
  final today = DateTime(2026, 11, 9);

  List<InventoryUnit> seed() => const [
    InventoryUnit(
      id: 's1',
      lotId: 'l61',
      lotCode: 'Ep 61',
      maker: 'YAMAHA',
      model: 'U3H',
      serial: '2076942',
      category: 'Piano Upright cũ',
      listPrice: 35500000,
      costVnd: 25046036,
      place: UnitPlace.inStock,
      receivedAt: '2026-08-17',
    ),
    InventoryUnit(
      id: 's2',
      lotId: 'l61',
      lotCode: 'Ep 61',
      maker: 'KAWAI',
      model: 'CA48A',
      category: 'Piano điện cũ',
      listPrice: 17500000,
      costVnd: 11131571,
      condition: UnitCondition.defective,
      place: UnitPlace.inStock,
    ),
    InventoryUnit(
      id: 'r1',
      lotId: 'l10',
      lotCode: 'Hmn10',
      maker: 'YAMAHA',
      model: 'U1H',
      serial: '1635970',
      listPrice: 24000000,
      sale: UnitSale.reserved,
      customerId: 'c1',
      customerName: 'Anh Phúc',
      reservedPrice: 24000000,
      place: UnitPlace.inStock,
    ),
  ];

  const all = InventoryPerms(
    read: true,
    write: true,
    reserve: true,
    cost: true,
    pay: true,
    sell: true,
  );

  Future<FakeInventoryApi> pump(
    WidgetTester t, {
    InventoryPerms perms = all,
  }) async {
    t.view.physicalSize = const Size(390, 1400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final api = FakeInventoryApi(units: seed());
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          inventoryApiProvider.overrideWithValue(api),
          inventoryPermsProvider.overrideWithValue(perms),
          inventoryTodayProvider.overrideWithValue(today),
        ],
        child: const MaterialApp(home: StockPage()),
      ),
    );
    await t.pumpAndSettle();
    return api;
  }

  testWidgets('Còn bán: dòng tổng ngắn, tiền đủ số, tuổi tồn, tình trạng', (
    t,
  ) async {
    final api = await pump(t);

    expect(api.listCalls.first['place'], 'in_stock');
    expect(find.text('Còn bán 2'), findsOneWidget);
    expect(find.text('Đã có khách 1'), findsOneWidget);
    expect(find.text('2 cây'), findsOneWidget);
    // Đã tải hết → có tổng niêm yết và vốn, đủ chữ số.
    expect(find.text('53.000.000đ'), findsOneWidget);
    expect(find.text('Vốn'), findsOneWidget);
    expect(find.text('36.177.607đ'), findsOneWidget);
    expect(find.text('35.500.000đ'), findsOneWidget);
    expect(find.text('Ep 61 · Upright · 84 ngày'), findsOneWidget);
    expect(find.text('Lỗi'), findsOneWidget);
    expect(find.text('Chọn nhiều cây'), findsOneWidget);
    // Cây đã có khách không nằm ở Còn bán.
    expect(find.text('YAMAHA U1H'), findsNothing);
  });

  testWidgets('thiếu quyền giá và giữ hàng: không Vốn, không Chọn nhiều cây', (
    t,
  ) async {
    await pump(t, perms: const InventoryPerms(read: true));

    expect(find.text('Vốn'), findsNothing);
    expect(find.text('Chọn nhiều cây'), findsNothing);
    // Không quyền sửa: serial chỉ là chữ, không có "+ Thêm serial".
    expect(find.text('+ Thêm serial'), findsNothing);
    expect(find.text('chưa có serial'), findsOneWidget);
  });

  testWidgets('chạm serial để sửa: gửi serial đã chuẩn hoá', (t) async {
    final api = await pump(t);

    await t.tap(find.text('+ Thêm serial'));
    await t.pumpAndSettle();
    await t.enterText(
      find.byKey(const ValueKey('inv-serial-input')),
      ' y026280.0 ',
    );
    await t.testTextInput.receiveAction(TextInputAction.done);
    await t.pumpAndSettle();

    expect(api.updates.single.$1, 's2');
    expect(api.updates.single.$2, {'serial': 'Y026280'});
    expect(find.text('Y026280'), findsOneWidget);
  });

  testWidgets('Đã có khách: tải sale=reserved,sold, hiện tên khách', (t) async {
    final api = await pump(t);

    await t.tap(find.text('Đã có khách 1'));
    await t.pumpAndSettle();

    expect(api.listCalls.last['sale'], 'reserved,sold');
    expect(find.text('YAMAHA U1H'), findsOneWidget);
    expect(find.text('Anh Phúc · 24.000.000đ'), findsOneWidget);
    expect(find.text('Chọn nhiều cây'), findsNothing);
  });

  testWidgets('chọn nhiều cây rồi Bán / Đặt trước mở sheet đủ số cây', (
    t,
  ) async {
    await pump(t);

    await t.tap(find.text('Chọn nhiều cây'));
    await t.pumpAndSettle();
    await t.tap(find.text('YAMAHA U3H'));
    await t.tap(find.text('KAWAI CA48A'));
    await t.pumpAndSettle();
    expect(find.text('Đã chọn 2 cây'), findsOneWidget);

    await t.tap(find.byKey(const ValueKey('inv-stock-sell-picked')));
    await t.pumpAndSettle();
    expect(find.text('2 cây'), findsWidgets);
    expect(find.text('Giá chốt'), findsOneWidget);
    expect(find.text('Tổng 2 cây'), findsOneWidget);
  });
}
