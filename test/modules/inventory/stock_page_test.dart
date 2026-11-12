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
    List<InventoryUnit>? units,
    List<WorkshopPlan> plans = const [],
    List<String> workshopSkipped = const [],
  }) async {
    t.view.physicalSize = const Size(390, 1400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final api = FakeInventoryApi(
      units: units ?? seed(),
      workshopSkipped: workshopSkipped,
    );
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          inventoryApiProvider.overrideWithValue(api),
          inventoryPermsProvider.overrideWithValue(perms),
          inventoryTodayProvider.overrideWithValue(today),
          workshopPlansProvider.overrideWith((ref) async => plans),
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

  testWidgets('không có quyền tạo việc: không có nút Đưa vào xưởng', (t) async {
    await pump(t);

    await t.tap(find.text('Chọn nhiều cây'));
    await t.pumpAndSettle();
    await t.tap(find.text('YAMAHA U3H'));
    await t.pumpAndSettle();

    expect(find.byKey(const ValueKey('inv-stock-sell-picked')), findsOneWidget);
    expect(find.byKey(const ValueKey('inv-stock-send-picked')), findsNothing);
  });

  group('Đưa vào xưởng', () {
    const workshop = InventoryPerms(read: true, workshop: true);
    const plans = <WorkshopPlan>[
      (id: 'p1', name: 'Tân trang đàn piano cơ', sections: []),
      (id: 'p2', name: 'Đàn điện', sections: []),
    ];

    // s1 chưa vào xưởng, s2 đang có việc tân trang mở, s3 đã tân trang xong.
    List<InventoryUnit> units() => const [
      InventoryUnit(
        id: 's1',
        lotId: 'l61',
        lotCode: 'Ep 61',
        maker: 'YAMAHA',
        model: 'U3H',
        place: UnitPlace.inStock,
        workshop: [],
      ),
      InventoryUnit(
        id: 's2',
        lotId: 'l61',
        lotCode: 'Ep 61',
        maker: 'KAWAI',
        model: 'K5',
        place: UnitPlace.inStock,
        condition: UnitCondition.refurbishing,
        workshop: [
          UnitWork(taskId: 't2', state: UnitWork.doing, done: 5, total: 10),
        ],
      ),
      InventoryUnit(
        id: 's3',
        lotId: 'l57',
        lotCode: 'Ep 57',
        maker: 'KAWAI',
        model: 'BL71',
        place: UnitPlace.inStock,
        condition: UnitCondition.ready,
        workshop: [
          UnitWork(
            taskId: 't3',
            state: UnitWork.doneState,
            done: 10,
            total: 10,
          ),
        ],
      ),
    ];

    testWidgets(
      'chọn cây, chọn kế hoạch: gửi cây chưa có việc mở, báo kết quả',
      (t) async {
        final api = await pump(
          t,
          perms: workshop,
          units: units(),
          plans: plans,
        );

        await t.tap(find.text('Chọn nhiều cây'));
        await t.pumpAndSettle();
        // Dòng cây lúc chọn: tình hình xưởng bên phải, tình trạng ở dòng phụ.
        expect(find.text('Chưa vào xưởng'), findsOneWidget);
        expect(find.text('5/10'), findsOneWidget);
        expect(find.text('Xong'), findsWidgets);

        await t.tap(find.text('YAMAHA U3H'));
        await t.tap(find.text('KAWAI K5'));
        await t.tap(find.text('KAWAI BL71'));
        await t.pumpAndSettle();
        // Cây đang có việc tân trang mở không tính.
        expect(find.text('Đưa vào xưởng · 2 cây'), findsOneWidget);
        // Không có quyền bán: không có nút bán.
        expect(
          find.byKey(const ValueKey('inv-stock-sell-picked')),
          findsNothing,
        );

        await t.tap(find.byKey(const ValueKey('inv-stock-send-picked')));
        await t.pumpAndSettle();
        expect(find.text('Chọn kế hoạch'), findsOneWidget);
        await t.tap(find.text('Tân trang đàn piano cơ'));
        await t.pumpAndSettle();

        expect(api.workshopSends.single, {
          'project_id': 'p1',
          'unit_ids': ['s1', 's3'],
        });
        expect(find.text('Đã tạo 2 việc xưởng.'), findsOneWidget);
        // Bỏ chọn, thoát chế độ chọn, danh sách tải lại.
        expect(find.text('Chọn nhiều cây'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('inv-stock-send-picked')),
          findsNothing,
        );
        expect(
          api.listCalls.where((c) => c['limit'] == 50).length,
          greaterThan(1),
        );
      },
    );

    testWidgets('server bỏ qua cây: câu báo có số cây bỏ qua', (t) async {
      await pump(
        t,
        perms: workshop,
        units: units(),
        plans: plans,
        workshopSkipped: const ['s3'],
      );

      await t.tap(find.text('Chọn nhiều cây'));
      await t.pumpAndSettle();
      await t.tap(find.text('YAMAHA U3H'));
      await t.tap(find.text('KAWAI BL71'));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('inv-stock-send-picked')));
      await t.pumpAndSettle();
      await t.tap(find.text('Đàn điện'));
      await t.pumpAndSettle();

      expect(
        find.text('Đã tạo 1 việc xưởng, bỏ qua 1 cây đang có việc tân trang.'),
        findsOneWidget,
      );
    });

    testWidgets('kế hoạch nhiều nhóm: chọn nhóm việc, gửi section_id', (
      t,
    ) async {
      final api = await pump(
        t,
        perms: workshop,
        units: units(),
        plans: const [
          (
            id: 'p1',
            name: 'Tân trang đàn piano cơ',
            sections: [
              (id: 'sA', name: 'Nhập xưởng'),
              (id: 'sB', name: 'Lên dây'),
            ],
          ),
        ],
      );

      await t.tap(find.text('Chọn nhiều cây'));
      await t.pumpAndSettle();
      await t.tap(find.text('YAMAHA U3H'));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('inv-stock-send-picked')));
      await t.pumpAndSettle();
      await t.tap(find.text('Tân trang đàn piano cơ'));
      await t.pumpAndSettle();
      expect(find.text('Nhóm việc'), findsOneWidget);
      await t.tap(find.text('Lên dây'));
      await t.pumpAndSettle();

      expect(api.workshopSends.single, {
        'project_id': 'p1',
        'unit_ids': ['s1'],
        'section_id': 'sB',
      });
    });

    testWidgets('không có kế hoạch quản lý được: báo, không gọi API', (
      t,
    ) async {
      final api = await pump(t, perms: workshop, units: units());

      await t.tap(find.text('Chọn nhiều cây'));
      await t.pumpAndSettle();
      await t.tap(find.text('YAMAHA U3H'));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('inv-stock-send-picked')));
      await t.pumpAndSettle();

      expect(
        find.text('Chưa có kế hoạch đang chạy nào bạn quản lý được.'),
        findsOneWidget,
      );
      expect(api.workshopSends, isEmpty);
    });

    testWidgets('chỉ chọn cây đang ở xưởng: không có nút', (t) async {
      await pump(t, perms: workshop, units: units(), plans: plans);

      await t.tap(find.text('Chọn nhiều cây'));
      await t.pumpAndSettle();
      await t.tap(find.text('KAWAI K5'));
      await t.pumpAndSettle();

      expect(find.byKey(const ValueKey('inv-stock-send-picked')), findsNothing);
    });

    testWidgets('có cả quyền bán: hai nút, không che nhau', (t) async {
      await pump(
        t,
        perms: const InventoryPerms(
          read: true,
          reserve: true,
          sell: true,
          workshop: true,
        ),
        units: units(),
        plans: plans,
      );

      await t.tap(find.text('Chọn nhiều cây'));
      await t.pumpAndSettle();
      await t.tap(find.text('YAMAHA U3H'));
      await t.pumpAndSettle();

      final send = t.getRect(
        find.byKey(const ValueKey('inv-stock-send-picked')),
      );
      final sell = t.getRect(
        find.byKey(const ValueKey('inv-stock-sell-picked')),
      );
      expect(send.bottom, lessThanOrEqualTo(sell.top));
    });
  });
}
