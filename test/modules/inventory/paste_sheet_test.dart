import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/modules/inventory/application/inventory_providers.dart';
import 'package:omni_app/modules/inventory/domain/inventory_models.dart';
import 'package:omni_app/modules/inventory/domain/inventory_permissions.dart';
import 'package:omni_app/modules/inventory/presentation/widgets/paste_sheet.dart';

import 'fake_inventory_api.dart';

/// Sheet "Dán packing list": rỗng thì báo, xem trước đếm vấn đề, thêm bỏ
/// dòng thiếu model và bỏ ¥ khi không có quyền giá.
void main() {
  const lot = Lot(id: 'l66', code: 'Ep 66', supplierName: 'Epco');
  const text =
      'LOẠI\tMAKER\tMODEL\tSERIAL\tGiá nhập ¥\tGiá bán\tKhách hàng\n'
      'Piano Upright cũ\tYAMAHA\tU3H\t2204585.0\t135000\t35500000\tAnh Bình\n'
      'Piano điện cũ\tKAWAI\tCA48\t\t\t17500000\t\n'
      'Trống điện\tROLAND\t\t\t18000\t\t';

  Future<FakeInventoryApi> pump(WidgetTester t, InventoryPerms perms) async {
    t.view.physicalSize = const Size(390, 1600);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final api = FakeInventoryApi(lots: [lot]);
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
                  onPressed: () => openPasteSheet(context, lot: lot),
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

  testWidgets('xem trước rồi thêm cây có model, kèm ¥', (t) async {
    final api = await pump(
      t,
      const InventoryPerms(read: true, write: true, cost: true),
    );
    await t.tap(find.byKey(const ValueKey('inv-paste-next')));
    await t.pumpAndSettle();
    expect(find.text('Chưa có dòng nào'), findsOneWidget);

    await t.enterText(find.byKey(const ValueKey('inv-paste-text')), text);
    await t.tap(find.byKey(const ValueKey('inv-paste-next')));
    await t.pumpAndSettle();

    expect(find.text('Xem trước · 3 dòng'), findsOneWidget);
    expect(find.text('2 cây'), findsOneWidget);
    expect(find.text('135.000 ¥'), findsWidgets);
    expect(find.text('Serial đã bỏ “.0”'), findsOneWidget);
    expect(find.text('Thiếu giá ¥'), findsOneWidget);
    expect(find.text('Thiếu model · bỏ qua'), findsOneWidget);
    expect(find.text('chưa có serial · Piano điện'), findsOneWidget);
    expect(find.text('thiếu ¥'), findsOneWidget);
    expect(find.text('Anh Bình'), findsOneWidget);
    expect(
      find.text('Tên khách chỉ để xem · đặt trước sau khi thêm'),
      findsOneWidget,
    );

    await t.tap(find.byKey(const ValueKey('inv-paste-save')));
    await t.pumpAndSettle();

    final (lotId, units) = api.addedUnits.single;
    expect(lotId, 'l66');
    expect(units.map((u) => u.model), ['U3H', 'CA48']);
    expect(units.first.serial, '2204585');
    expect(units.first.yenPrice, 135000);
    expect(find.text('Đã thêm 2 cây vào Ep 66'), findsOneWidget);
  });

  testWidgets('không có quyền giá: ẩn ¥, không gửi ¥', (t) async {
    final api = await pump(t, const InventoryPerms(read: true, write: true));
    await t.enterText(find.byKey(const ValueKey('inv-paste-text')), text);
    await t.tap(find.byKey(const ValueKey('inv-paste-next')));
    await t.pumpAndSettle();

    expect(find.text('Thiếu giá ¥'), findsNothing);
    expect(find.text('thiếu ¥'), findsNothing);
    expect(find.textContaining('¥:'), findsNothing);

    await t.tap(find.byKey(const ValueKey('inv-paste-save')));
    await t.pumpAndSettle();
    expect(api.addedUnits.single.$2.every((u) => u.yenPrice == null), isTrue);
  });
}
