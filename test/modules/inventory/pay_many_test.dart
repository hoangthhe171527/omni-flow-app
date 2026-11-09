import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/modules/inventory/application/inventory_providers.dart';
import 'package:omni_app/modules/inventory/domain/inventory_models.dart';
import 'package:omni_app/modules/inventory/domain/inventory_permissions.dart';
import 'package:omni_app/modules/inventory/presentation/lot_detail_page.dart';

import 'fake_inventory_api.dart';

/// Chi tiết lô · "Trả nhiều khoản": chọn khoản dự kiến, nút ngón cái ghi tổng,
/// sheet "Ghi đã trả" gửi đúng id + số ₫ từng khoản.
void main() {
  final today = DateTime(2026, 11, 9);
  const lot = Lot(
    id: 'l64',
    code: 'Ep 64',
    status: LotStatus.inTransit,
    units: 2,
    lastFx: 170,
    plannedCount: 3,
    costs: [
      LotCost(
        id: 'c1',
        lotId: 'l64',
        kind: CostKind.goodsOutside,
        label: 'Cọc',
        amountJpy: 1000000,
        amountVnd: 168000000,
        paidAt: '2026-10-01',
      ),
      LotCost(
        id: 'c2',
        lotId: 'l64',
        kind: CostKind.goodsInvoice,
        label: 'Trả tiền hàng',
        amountJpy: 100000,
        status: CostStatus.planned,
      ),
      LotCost(
        id: 'c3',
        lotId: 'l64',
        kind: CostKind.importTax,
        amountVnd: 25000000,
        status: CostStatus.planned,
      ),
      LotCost(
        id: 'c4',
        lotId: 'l64',
        kind: CostKind.container,
        amountVnd: 500000,
        status: CostStatus.planned,
      ),
    ],
  );

  const all = InventoryPerms(
    read: true,
    write: true,
    reserve: true,
    cost: true,
    pay: true,
    sell: true,
  );

  Future<FakeInventoryApi> pump(WidgetTester t, {Lot? payResult}) async {
    t.view.physicalSize = const Size(390, 1800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final api = FakeInventoryApi(
      lots: [lot],
      accounts: const [MoneyAccount(id: 'a1', name: 'VCB')],
      payResult: payResult,
    );
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          inventoryApiProvider.overrideWithValue(api),
          inventoryPermsProvider.overrideWithValue(all),
          inventoryTodayProvider.overrideWithValue(today),
        ],
        child: const MaterialApp(home: LotDetailPage(lotId: 'l64')),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.text('Khoản trả'));
    await t.pumpAndSettle();
    return api;
  }

  Future<void> select(WidgetTester t, List<String> ids) async {
    await t.tap(find.byKey(const ValueKey('inv-lot-pay-select')));
    await t.pumpAndSettle();
    expect(find.text('Thêm khoản'), findsNothing);
    for (final id in ids) {
      await t.tap(find.byKey(ValueKey('inv-cost-pick-$id')));
      await t.pumpAndSettle();
    }
  }

  testWidgets('chọn 2 khoản dự kiến: nút ngón cái ghi tổng, gửi đúng id + ₫', (
    t,
  ) async {
    final api = await pump(t);
    expect(find.text('Nhận hàng'), findsOneWidget);

    await select(t, ['c2', 'c3']);
    // Khoản đã trả không chọn được.
    await t.tap(find.byKey(const ValueKey('inv-cost-pick-c1')));
    await t.pumpAndSettle();

    expect(find.text('Đã chọn 2 khoản'), findsOneWidget);
    expect(find.text('Nhận hàng'), findsNothing);
    // 100.000 ¥ × 170 = 17.000.000 + 25.000.000.
    expect(find.text('Ghi đã trả · 2 khoản · 42.000.000đ'), findsOneWidget);

    await t.tap(find.byKey(const ValueKey('inv-lot-pay-many')));
    await t.pumpAndSettle();
    expect(find.text('Ep 64 · 2 khoản'), findsOneWidget);
    expect(find.text('17.000.000đ'), findsWidgets);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('inv-pay-many-total')),
        matching: find.text('42.000.000đ'),
      ),
      findsOneWidget,
    );

    await t.tap(find.byKey(const ValueKey('inv-pay-many-account')));
    await t.pumpAndSettle();
    await t.tap(find.text('VCB'));
    await t.pumpAndSettle();

    await t.tap(find.byKey(const ValueKey('inv-pay-many-save')));
    await t.pumpAndSettle();

    expect(api.pays.single, {
      'lot_id': 'l64',
      'cost_ids': ['c2', 'c3'],
      'paid_at': '2026-11-09',
      'money_account_id': 'a1',
      'amounts': {'c2': 17000000, 'c3': 25000000},
    });
    expect(find.text('Đã trả 2 khoản · 42.000.000đ'), findsOneWidget);
    expect(find.text('Trả nhiều khoản'), findsOneWidget);
  });

  testWidgets('lô chốt sau khi trả: thông báo tỷ lệ chốt', (t) async {
    await pump(
      t,
      payResult: const Lot(
        id: 'l64',
        code: 'Ep 64',
        costFinal: true,
        rateApplied: 172.4,
      ),
    );
    await select(t, ['c4']);
    await t.tap(find.byKey(const ValueKey('inv-lot-pay-many')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('inv-pay-many-save')));
    await t.pumpAndSettle();

    expect(find.text('Ep 64 đã chốt 172,40'), findsOneWidget);
  });
}
