import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/modules/inventory/application/inventory_providers.dart';
import 'package:omni_app/modules/inventory/domain/inventory_models.dart';
import 'package:omni_app/modules/inventory/domain/inventory_permissions.dart';
import 'package:omni_app/modules/inventory/presentation/widgets/sell_sheet.dart';

import 'fake_inventory_api.dart';

/// Sheet "Bán / Đặt trước" dùng chung: giữ cho khách, tạo đơn ngay, thêm vào
/// đơn đang mở, tạo nhanh khách; hàng chưa về chỉ đặt trước.
void main() {
  const inStock = InventoryUnit(
    id: 's1',
    lotId: 'l61',
    maker: 'YAMAHA',
    model: 'U3H',
    serial: '2076942',
    listPrice: 35500000,
    place: UnitPlace.inStock,
  );
  const incoming = InventoryUnit(
    id: 'e7',
    lotId: 'l64',
    lineNo: 11,
    maker: 'YAMAHA',
    model: 'ELS01',
    listPrice: 13500000,
  );
  const long = InventoryCustomer(
    id: 'c1',
    name: 'Nhạc cụ Hoàng Long',
    phone: '0903 112 233',
  );

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
    required List<InventoryUnit> units,
    InventoryPerms perms = all,
    List<OpenOrder> open = const [],
    bool allowRetail = false,
  }) async {
    t.view.physicalSize = const Size(390, 1600);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final api = FakeInventoryApi(customers: [long], openOrders: open);
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          inventoryApiProvider.overrideWithValue(api),
          inventoryPermsProvider.overrideWithValue(perms),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: FilledButton(
                  onPressed: () => openSellSheet(
                    context,
                    units: units,
                    allowRetail: allowRetail,
                  ),
                  child: const Text('mở'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('mở'));
    await t.pumpAndSettle();
    return api;
  }

  Future<void> pickLong(WidgetTester t) async {
    await t.tap(find.byKey(const ValueKey('inv-cust-c1')));
    await t.pumpAndSettle();
  }

  FilledButton saveButton(WidgetTester t) =>
      t.widget<FilledButton>(find.byKey(const ValueKey('inv-sell-save')));

  testWidgets('chưa chọn khách thì không lưu được; Đặt trước gửi giá + cọc', (
    t,
  ) async {
    final api = await pump(t, units: [inStock]);

    expect(find.text('35.500.000đ'), findsWidgets);
    expect(saveButton(t).onPressed, isNull);

    await pickLong(t);
    expect(find.text('Nhạc cụ Hoàng Long'), findsOneWidget);
    expect(find.text('Đổi'), findsOneWidget);
    expect(saveButton(t).onPressed, isNotNull);

    await t.tap(find.byKey(const ValueKey('inv-sell-save')));
    await t.pumpAndSettle();

    expect(api.reserves.single, {
      'unit_ids': ['s1'],
      'customer_id': 'c1',
      'retail': false,
      'prices': {'s1': 35500000},
      'deposit': 0,
    });
    expect(api.sells, isEmpty);
    expect(find.text('Đã giữ 1 cây cho Nhạc cụ Hoàng Long.'), findsOneWidget);
  });

  testWidgets('Tạo đơn ngay gọi from-units với giá chốt', (t) async {
    final api = await pump(t, units: [inStock]);
    await pickLong(t);

    await t.tap(find.text('Tạo đơn ngay'));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('inv-sell-deposit')), findsNothing);
    await t.tap(find.byKey(const ValueKey('inv-sell-save')));
    await t.pumpAndSettle();

    expect(api.sells.single['unit_ids'], ['s1']);
    expect(api.sells.single['order_id'], isNull);
    expect(api.sells.single['prices'], {'s1': 35500000});
    expect(
      find.text('Đã tạo đơn DH-1043 cho Nhạc cụ Hoàng Long.'),
      findsOneWidget,
    );
  });

  testWidgets('khách có đơn đang mở: Thêm vào đơn gửi order_id', (t) async {
    final api = await pump(
      t,
      units: [inStock],
      open: const [OpenOrder(id: 'o9', code: 'DH-1042')],
    );
    await pickLong(t);

    await t.tap(find.text('Thêm vào DH-1042'));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('inv-sell-save')));
    await t.pumpAndSettle();

    expect(api.sells.single['order_id'], 'o9');
    expect(find.text('Đã thêm 1 cây vào đơn DH-1042.'), findsOneWidget);
  });

  testWidgets('hàng chưa về: chỉ Đặt trước, có Để bán lẻ', (t) async {
    final api = await pump(t, units: [incoming], allowRetail: true);
    await pickLong(t);

    expect(find.text('Tạo đơn ngay'), findsNothing);
    expect(find.text('#11'), findsOneWidget);

    await t.tap(find.byKey(const ValueKey('inv-sell-retail')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('inv-sell-save')));
    await t.pumpAndSettle();

    expect(api.reserves.single['retail'], isTrue);
    expect(api.reserves.single['customer_id'], isNull);
  });

  testWidgets('chỉ có quyền tạo đơn (không giữ hàng): không có Đặt trước', (
    t,
  ) async {
    await pump(
      t,
      units: [inStock],
      perms: const InventoryPerms(read: true, sell: true),
    );
    await pickLong(t);

    expect(find.text('Đặt trước'), findsNothing);
    expect(find.text('Tạo đơn'), findsOneWidget);
  });

  testWidgets('tạo nhanh khách từ chữ đã gõ', (t) async {
    final api = await pump(t, units: [inStock]);

    await t.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('inv-sell-customer-search')),
        matching: find.byType(EditableText),
      ),
      'Anh Bình',
    );
    await t.pump(const Duration(milliseconds: 400));
    await t.pumpAndSettle();
    await t.tap(find.text('Tạo khách: Anh Bình'));
    await t.pumpAndSettle();

    final name = t.widget<TextField>(
      find.byKey(const ValueKey('inv-new-name')),
    );
    expect(name.controller!.text, 'Anh Bình');
    await t.enterText(
      find.byKey(const ValueKey('inv-new-phone')),
      '0909778345',
    );
    await t.tap(find.byKey(const ValueKey('inv-new-save')));
    await t.pumpAndSettle();

    expect(api.created.single, ('Anh Bình', '0909778345'));
    expect(find.text('Anh Bình'), findsOneWidget);
    expect(saveButton(t).onPressed, isNotNull);
  });
}
