import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/modules/inventory/application/inventory_providers.dart';
import 'package:omni_app/modules/inventory/domain/inventory_models.dart';
import 'package:omni_app/modules/inventory/domain/inventory_permissions.dart';
import 'package:omni_app/modules/inventory/presentation/widgets/create_lot_sheet.dart';

import 'fake_inventory_api.dart';

/// Sheet "Tạo lô": mã trùng chặn nút, nhà cung cấp mới tạo trước, thuế phí
/// dự kiến theo lô trước cùng nhà cung cấp.
void main() {
  final today = DateTime(2026, 11, 9);
  const epco = Supplier(id: 'sup1', name: 'Epco');
  const lots = [
    Lot(
      id: 'l64',
      code: 'Ep 64',
      supplierId: 'sup1',
      supplierName: 'Epco',
      plannedVnd: 10500000,
    ),
    Lot(id: 'l63', code: 'Ep 63', supplierId: 'sup1', plannedVnd: 9000000),
  ];

  const all = InventoryPerms(
    read: true,
    write: true,
    reserve: true,
    cost: true,
    pay: true,
    sell: true,
  );

  Future<(FakeInventoryApi, List<Lot?>)> pump(
    WidgetTester t, {
    InventoryPerms perms = all,
  }) async {
    t.view.physicalSize = const Size(390, 1400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final api = FakeInventoryApi(lots: lots, suppliers: [epco]);
    final results = <Lot?>[];
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          inventoryApiProvider.overrideWithValue(api),
          inventoryPermsProvider.overrideWithValue(perms),
          inventoryTodayProvider.overrideWithValue(today),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: FilledButton(
                  onPressed: () async => results.add(
                    await openCreateLotSheet(context, lots: lots),
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
    return (api, results);
  }

  FilledButton save(WidgetTester t) =>
      t.widget<FilledButton>(find.byKey(const ValueKey('inv-nl-save')));

  testWidgets('mã trùng (không phân biệt hoa thường) chặn nút Tạo lô', (
    t,
  ) async {
    await pump(t);
    expect(find.text('09/11/2026'), findsOneWidget);
    expect(save(t).onPressed, isNull);

    await t.enterText(find.byKey(const ValueKey('inv-nl-code')), 'ep 64');
    await t.pump();
    expect(find.text('Đã có lô ep 64'), findsOneWidget);
    expect(save(t).onPressed, isNull);

    await t.enterText(find.byKey(const ValueKey('inv-nl-code')), 'Ep 67');
    await t.pump();
    expect(find.byKey(const ValueKey('inv-nl-dup')), findsNothing);
    expect(save(t).onPressed, isNotNull);
  });

  testWidgets('chọn NCC hiện thuế phí lô trước; Tạo lô gọi API và trả lô', (
    t,
  ) async {
    final (api, results) = await pump(t);
    await t.enterText(find.byKey(const ValueKey('inv-nl-code')), 'Ep 67');
    await t.tap(find.byKey(const ValueKey('inv-nl-supplier')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('inv-nl-sup-sup1')));
    await t.pumpAndSettle();

    expect(find.text('Thuế phí dự kiến'), findsOneWidget);
    expect(find.text('Chép từ lô trước'), findsOneWidget);

    await t.enterText(find.byKey(const ValueKey('inv-nl-rate')), '185,5');
    await t.tap(find.byKey(const ValueKey('inv-nl-save')));
    await t.pumpAndSettle();

    expect(api.createdLots.single, {
      'code': 'Ep 67',
      'supplier_id': 'sup1',
      'ordered_at': '2026-11-09',
      'eta': null,
      'rate': 185.5,
      'fees_from_previous': true,
    });
    expect(results.single?.code, 'Ep 67');
  });

  testWidgets('nhà cung cấp mới được tạo trước khi tạo lô', (t) async {
    final (api, _) = await pump(t);
    await t.enterText(find.byKey(const ValueKey('inv-nl-code')), 'Hmn 12');
    await t.tap(find.byKey(const ValueKey('inv-nl-supplier')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('inv-nl-sup-new')));
    await t.pumpAndSettle();
    await t.enterText(
      find.byKey(const ValueKey('inv-nl-new-supplier')),
      'Hamana',
    );
    await t.tap(find.byKey(const ValueKey('inv-nl-save')));
    await t.pumpAndSettle();

    expect(api.createdSuppliers, ['Hamana']);
    expect(api.createdLots.single['supplier_id'], 'sup-new');
    expect(find.text('Thuế phí dự kiến'), findsNothing);
  });

  testWidgets('không có quyền thanh toán lô: không có tỷ lệ tạm, thuế phí', (
    t,
  ) async {
    await pump(
      t,
      perms: const InventoryPerms(read: true, write: true, cost: true),
    );
    await t.tap(find.byKey(const ValueKey('inv-nl-supplier')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('inv-nl-sup-sup1')));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('inv-nl-rate')), findsNothing);
    expect(find.text('Thuế phí dự kiến'), findsNothing);
  });
}
