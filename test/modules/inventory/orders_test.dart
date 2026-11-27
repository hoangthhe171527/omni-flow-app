import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:omni_app/core/network/api_envelope.dart';
import 'package:omni_app/modules/inventory/application/inventory_providers.dart';
import 'package:omni_app/modules/inventory/domain/inventory_models.dart';
import 'package:omni_app/modules/inventory/domain/inventory_permissions.dart';
import 'package:omni_app/modules/inventory/domain/order_list.dart';
import 'package:omni_app/modules/inventory/domain/order_units.dart';
import 'package:omni_app/modules/inventory/presentation/order_units_page.dart';
import 'package:omni_app/modules/inventory/presentation/orders_page.dart';
import 'package:omni_app/security/permissions/access_policy.dart';
import 'package:omni_app/security/session/session_controller.dart';
import 'package:omni_app/modules/inventory/presentation/widgets/pick_order_units_sheet.dart';
import 'package:omni_app/modules/inventory/presentation/widgets/record_payment_sheet.dart';

import 'fake_inventory_api.dart';

/// Danh sách đơn, ghi thu, chọn đàn tạo đơn (bản mẫu NWUQNP).
class _OrdersApi extends FakeInventoryApi {
  _OrdersApi(this.rows);
  final List<OrderRow> rows;
  final payments = <Map<String, Object?>>[];
  final orderCalls = <Map<String, String?>>[];

  @override
  Future<Paged<OrderRow>> listOrders({
    String? search,
    String? status,
    int page = 1,
    int perPage = 50,
  }) async {
    orderCalls.add({'search': search, 'status': status, 'page': '$page'});
    final start = (page - 1) * perPage;
    final slice = rows.skip(start).take(perPage).toList();
    final last = rows.isEmpty ? 1 : (rows.length + perPage - 1) ~/ perPage;
    return Paged(
      items: slice,
      pagination: ApiPagination(
        currentPage: page,
        lastPage: last,
        perPage: perPage,
        total: rows.length,
      ),
    );
  }

  @override
  Future<OrdersDue> ordersDue() async =>
      (outstanding: 261500000.0, awaiting: 2);

  @override
  Future<void> recordPayment(
    String orderId, {
    required int amount,
    required DateTime paidAt,
    required PaymentMethod method,
    String? note,
  }) async {
    payments.add({
      'order': orderId,
      'amount': amount,
      'paid_at': paidAt,
      'method': method.wire,
    });
  }
}

OrderRow _row(String id, Map<String, dynamic> x) =>
    OrderRow.fromJson({'id': id, 'code': 'DH-$id', ...x});

final _today = DateTime(2026, 11, 12);

void main() {
  setUpAll(() => initializeDateFormatting('vi_VN'));

  group('OrderRow', () {
    test('còn phải thu: đơn huỷ / đã thu đủ = 0', () {
      expect(_row('1', {'value': 100, 'paid': 40}).remaining, 60);
      expect(_row('2', {'value': 100, 'paid': 100}).remaining, 0);
      expect(
        _row('3', {'value': 100, 'paid': 0, 'status': 'cancelled'}).remaining,
        0,
      );
      expect(_row('4', {'pay_status': 'lạ'}).payStatus, OrderPayStatus.unpaid);
    });

    test('sổ thu đọc hình thức; hình thức lạ → Khác', () {
      final p = OrderPayment.fromJson(const {
        'id': 'p',
        'amount': 5000000,
        'paid_at': '2026-11-09T03:00:00Z',
        'method': 'cash',
      });
      expect(p.method, PaymentMethod.cash);
      expect(
        OrderPayment.fromJson(const {'id': 'x', 'method': 'zalo'}).method,
        PaymentMethod.other,
      );
    });
  });

  test('chọn đàn tạo đơn: chỉ cây trong kho, chưa vào đơn, chưa bán', () {
    InventoryUnit u({
      UnitPlace place = UnitPlace.inStock,
      UnitSale sale = UnitSale.available,
      String? orderId,
    }) => InventoryUnit(
      id: 'u',
      lotId: 'l',
      maker: 'YAMAHA',
      model: 'U3H',
      place: place,
      sale: sale,
      orderId: orderId,
    );
    expect(pickableForOrder(u()), isTrue);
    expect(pickableForOrder(u(sale: UnitSale.reserved)), isTrue);
    expect(pickableForOrder(u(sale: UnitSale.sold)), isFalse);
    expect(pickableForOrder(u(orderId: 'o1')), isFalse);
    expect(pickableForOrder(u(place: UnitPlace.incoming)), isFalse);
  });

  Future<_OrdersApi> pumpList(WidgetTester t) async {
    t.view.physicalSize = const Size(390, 1400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final api = _OrdersApi([
      _row('A', {
        'customer_name': 'Phạm Minh Đức',
        'product': '5 cây',
        'value': 303500000,
        'paid': 100000000,
        'pay_status': 'partial',
        'created_at': '2026-11-11T03:00:00Z',
      }),
      _row('B', {
        'customer_name': 'Lê Thu Hà',
        'value': 58000000,
        'paid': 58000000,
        'pay_status': 'paid',
        'created_at': '2026-11-11T03:00:00Z',
      }),
      _row('C', {
        'customer_name': 'Nguyễn Hoàng Long',
        'value': 58000000,
        'paid': 0,
        'pay_status': 'unpaid',
        'created_at': '2026-10-20T03:00:00Z',
      }),
    ]);
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          inventoryApiProvider.overrideWithValue(api),
          inventoryPermsProvider.overrideWithValue(
            const InventoryPerms(read: true),
          ),
          inventoryTodayProvider.overrideWithValue(_today),
        ],
        child: const MaterialApp(home: OrdersPage()),
      ),
    );
    await t.pumpAndSettle();
    return api;
  }

  testWidgets('danh sách: mặc định Cần thu, dòng tổng, nhóm theo thời gian', (
    t,
  ) async {
    final api = await pumpList(t);
    // Số đếm vẽ riêng cạnh nhãn; trình đọc màn hình nghe "Cần thu 2".
    expect(find.bySemanticsLabel('Cần thu 2'), findsOneWidget);
    expect(find.text('Còn phải thu'), findsOneWidget);
    expect(find.text('2 đơn'), findsOneWidget);
    expect(find.text('261.500.000đ'), findsOneWidget);
    // Đơn đã thu đủ không nằm trong "Cần thu".
    expect(find.text('Lê Thu Hà'), findsNothing);

    expect(find.text('Phạm Minh Đức'), findsOneWidget);
    // Dòng duy nhất của nhóm: tiền ở dòng = tổng đầu nhóm (lớp premium).
    expect(find.text('203.500.000đ'), findsNWidgets(2));
    expect(find.text('Thu một phần'), findsOneWidget);
    expect(find.text('TUẦN NÀY'), findsOneWidget);
    expect(find.text('TRƯỚC ĐÓ'), findsOneWidget);
    expect(api.orderCalls.last['status'], isNull);

    await t.tap(find.text('Đang xử lý'));
    await t.pumpAndSettle();
    expect(api.orderCalls.last['status'], 'processing');

    await t.tap(find.text('Tất cả'));
    await t.pumpAndSettle();
    expect(find.text('Lê Thu Hà'), findsOneWidget);
  });

  testWidgets('không có quyền bán: không có nút tạo đơn', (t) async {
    await pumpList(t);
    expect(find.byTooltip('Tạo đơn'), findsNothing);
  });

  testWidgets('ghi thu: mặc định thu đủ, đổi hình thức, gửi đúng', (t) async {
    t.view.physicalSize = const Size(390, 1000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final api = _OrdersApi(const []);
    bool? done;
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          inventoryApiProvider.overrideWithValue(api),
          inventoryTodayProvider.overrideWithValue(_today),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async => done = await openRecordPaymentSheet(
                  context,
                  orderId: 'o1',
                  orderCode: 'DH-2611-014',
                  remaining: 203500000,
                ),
                child: const Text('mở'),
              ),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('mở'));
    await t.pumpAndSettle();

    expect(find.text('203.500.000đ'), findsOneWidget);
    expect(find.text('Hôm nay, 12/11'), findsOneWidget);
    await t.tap(find.text('Tiền mặt'));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('pay-save')));
    await t.pumpAndSettle();

    expect(done, isTrue);
    expect(api.payments.single, {
      'order': 'o1',
      'amount': 203500000,
      'paid_at': _today,
      'method': 'cash',
    });
  });

  test('chi tiết đơn: còn phải thu, đơn huỷ', () {
    const d = OrderUnits(
      code: 'DH',
      customerName: 'A',
      units: [],
      value: 300,
      paid: 100,
    );
    expect(d.remaining, 200);
  });

  Future<void> pumpDetail(WidgetTester t, Set<String> perms) async {
    t.view.physicalSize = const Size(390, 1400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final d = OrderUnits(
      code: 'DH-2611-014',
      customerName: 'Phạm Minh Đức',
      value: 303500000,
      paid: 100000000,
      units: const [],
      payments: [
        OrderPayment.fromJson(const {
          'id': 'p1',
          'amount': 50000000,
          'paid_at': '2026-11-05T03:00:00Z',
          'method': 'transfer',
          'note': 'Cọc',
        }),
      ],
    );
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          orderUnitsProvider('o1').overrideWith((ref) async => d),
          accessProvider.overrideWithValue(AccessPolicy(perms)),
          inventoryApiProvider.overrideWithValue(_OrdersApi(const [])),
          inventoryTodayProvider.overrideWithValue(_today),
        ],
        child: const MaterialApp(home: OrderUnitsPage(orderId: 'o1')),
      ),
    );
    await t.pumpAndSettle();
  }

  testWidgets('chi tiết đơn: sổ thu, chạm "còn …" mở Ghi thu', (t) async {
    await pumpDetail(t, {'orders.write'});
    expect(find.text('Đã thu'), findsWidgets);
    expect(find.text('50.000.000đ'), findsOneWidget);
    expect(find.text('05/11/2026 · Chuyển khoản · Cọc'), findsOneWidget);
    expect(find.text('303.500.000đ'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('order-due')));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('pay-save')), findsOneWidget);
  });

  testWidgets('chi tiết đơn: không quyền ghi đơn → không có Ghi thu', (
    t,
  ) async {
    await pumpDetail(t, const {});
    expect(find.byKey(const ValueKey('order-due')), findsNothing);
    expect(find.byKey(const ValueKey('order-pay-add')), findsNothing);
  });

  group('phân trang (sửa 27/11/2026: trước chỉ có 100 đơn mới nhất)', () {
    // 120 đơn mới nhất trước; chỉ đơn số 80–90 còn nợ.
    final many = [
      for (var i = 1; i <= 120; i++)
        _row('$i', {
          'customer_name': 'Khách $i',
          'value': 1000,
          'paid': i >= 80 && i <= 90 ? 0 : 1000,
          'created_at': '2026-11-11T03:00:00Z',
        }),
    ];

    ProviderContainer containerFor(InventoryApi api) {
      final c = ProviderContainer(
        overrides: [
          inventoryApiProvider.overrideWithValue(api),
          inventoryPermsProvider.overrideWithValue(
            const InventoryPerms(read: true),
          ),
          inventoryTodayProvider.overrideWithValue(_today),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('Tất cả: trang 50 đơn, tải thêm tới hết', () async {
      final api = _OrdersApi(many);
      final c = containerFor(api);
      const q = (filter: OrderListFilter.all, q: '');
      final sub = c.listen(ordersListProvider(q), (_, _) {});
      addTearDown(sub.close);

      var s = await c.read(ordersListProvider(q).future);
      expect(s.rows, hasLength(50));
      expect(s.hasMore, isTrue);

      await c.read(ordersListProvider(q).notifier).loadMore();
      s = c.read(ordersListProvider(q)).requireValue;
      expect(s.rows, hasLength(100));

      await c.read(ordersListProvider(q).notifier).loadMore();
      s = c.read(ordersListProvider(q)).requireValue;
      expect(s.rows, hasLength(120));
      expect(s.hasMore, isFalse);
      expect(s.rows.last.id, '120');
      expect(api.orderCalls.map((e) => e['page']), ['1', '2', '3']);
    });

    test('Cần thu: trang không có đơn nợ thì lấy tiếp, tới khi hết', () async {
      final api = _OrdersApi(many);
      final c = containerFor(api);
      const q = (filter: OrderListFilter.due, q: '');
      final sub = c.listen(ordersListProvider(q), (_, _) {});
      addTearDown(sub.close);

      final s = await c.read(ordersListProvider(q).future);
      // Trang 1 không có đơn nợ; trang 2 có 11 (< 20) nên lấy tiếp trang 3.
      expect(s.rows.map((o) => o.id), [for (var i = 80; i <= 90; i++) '$i']);
      expect(s.hasMore, isFalse);
      expect(api.orderCalls.map((e) => e['page']), ['1', '2', '3']);
    });

    test('tải thêm hỏng: giữ đơn cũ, đánh dấu để không tự gọi lại', () async {
      final api = _FlakyOrdersApi(many);
      final c = containerFor(api);
      const q = (filter: OrderListFilter.all, q: '');
      final sub = c.listen(ordersListProvider(q), (_, _) {});
      addTearDown(sub.close);

      await c.read(ordersListProvider(q).future);
      await c.read(ordersListProvider(q).notifier).loadMore();
      final s = c.read(ordersListProvider(q)).requireValue;
      expect(s.rows, hasLength(50));
      expect(s.loadFailed, isTrue);
      expect(s.hasMore, isTrue);
    });
  });
}

/// Trang 2 trở đi hỏng mạng.
class _FlakyOrdersApi extends _OrdersApi {
  _FlakyOrdersApi(super.rows);

  @override
  Future<Paged<OrderRow>> listOrders({
    String? search,
    String? status,
    int page = 1,
    int perPage = 50,
  }) {
    if (page > 1) throw Exception('mất mạng');
    return super.listOrders(
      search: search,
      status: status,
      page: page,
      perPage: perPage,
    );
  }
}
