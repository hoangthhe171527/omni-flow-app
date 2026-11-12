import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:omni_app/modules/inventory/application/inventory_providers.dart';
import 'package:omni_app/modules/inventory/domain/order_units.dart';
import 'package:omni_app/modules/inventory/presentation/order_units_page.dart';

/// Phản hồi thật của `GET /orders/{id}/units` (API #111), server đã xếp thứ tự.
Map<String, dynamic> _unit(
  String id,
  String bucket, [
  Map<String, dynamic>? x,
]) => {'id': id, 'label': 'YAMAHA $id', 'bucket': bucket, ...?x};

OrderUnits _order() => OrderUnits(
  code: 'DH-2611-014',
  customerName: 'Phạm Minh Đức',
  value: 303500000,
  paid: 100000000,
  units: [
    OrderUnit.fromJson(
      _unit('BL71', 'issue', {
        'serial': '1452098',
        'work': {
          'task_id': 't1',
          'section_name': 'Lên dây',
          'state': 'doing',
          'done': 6,
          'total': 10,
        },
        'issue': {
          'task_id': 't0',
          'note': 'Nứt bảng cộng hưởng',
          'by_name': 'Bảo',
          'photos': [],
        },
      }),
    ),
    OrderUnit.fromJson(
      _unit('W106', 'in_shop', {
        'work': {
          'task_id': 't2',
          'section_name': 'Bộ phím',
          'assignee_names': ['Hoàng'],
          'due_date': '2026-11-15',
          'state': 'doing',
          'done': 8,
          'total': 10,
        },
      }),
    ),
    OrderUnit.fromJson(
      _unit('U3H', 'ready', {'location': 'Kho chính · Dãy B'}),
    ),
    OrderUnit.fromJson(
      _unit('U1H', 'not_in_shop', {
        'condition': 'sealed',
        'lot_code': 'JP-2610',
      }),
    ),
    OrderUnit.fromJson(
      _unit('KS2F', 'delivered', {'delivered_at': '2026-11-05T09:00:00+07:00'}),
    ),
  ],
);

void main() {
  setUpAll(() => initializeDateFormatting('vi_VN'));

  group('OrderUnit — đọc phản hồi', () {
    test('thiếu khoá / nhóm lạ không vỡ', () {
      final u = OrderUnit.fromJson(const {
        'id': 'x',
        'maker': 'KAWAI',
        'model': 'K5',
        'bucket': 'weird',
      });
      expect(u.label, 'KAWAI K5');
      expect(u.bucket, OrderUnitBucket.notInShop);
      expect(u.work, isNull);
      expect(u.issue, isNull);
      expect(u.price, isNull);
      expect(u.taskId, isNull);
    });

    test('chạm cây có cờ mở việc mang cờ, không phải việc của dòng', () {
      expect(_order().units.first.taskId, 't0');
      expect(_order().units[1].taskId, 't2');
    });

    test('tiến độ: xong = sẵn sàng + đã giao; nhóm theo thứ tự màn', () {
      final o = _order();
      expect(o.done, 2);
      expect(o.total, 5);
      expect(o.remaining, 203500000);
      expect(o.groups.map((g) => g.$1), OrderUnitBucket.values);
    });
  });

  testWidgets('màn Chi tiết đơn: dòng tiến độ, năm nhóm, dòng phụ', (t) async {
    t.view.physicalSize = const Size(390, 1600);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          orderUnitsProvider('o1').overrideWith((ref) async => _order()),
        ],
        child: const MaterialApp(home: OrderUnitsPage(orderId: 'o1')),
      ),
    );
    await t.pumpAndSettle();

    expect(find.text('2/5 cây xong'), findsOneWidget);
    expect(find.textContaining('203.500.000'), findsOneWidget);
    for (final label in [
      'Cần xem',
      'Ở xưởng',
      'Sẵn sàng giao',
      'Chưa vào xưởng',
      'Đã giao',
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    expect(find.text('YAMAHA BL71 1452098'), findsOneWidget);
    expect(find.text('Nứt bảng cộng hưởng — Bảo'), findsOneWidget);
    expect(find.text('6/10'), findsOneWidget);
    expect(find.text('Bộ phím · Hoàng · hạn 15/11'), findsOneWidget);
    expect(find.text('Kho chính · Dãy B'), findsOneWidget);
    expect(find.text('Nguyên thùng · JP-2610'), findsOneWidget);
    expect(find.text('05/11'), findsOneWidget);
  });
}
