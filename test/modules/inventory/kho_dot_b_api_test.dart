import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/core/network/api_client.dart';
import 'package:omni_app/modules/inventory/data/inventory_api.dart';
import 'package:omni_app/modules/inventory/domain/inventory_models.dart';

/// Kho chuẩn hóa Đợt B trên dây: app GHI bằng đúng tên khoá của controller API
/// (`ProductController`, `StockController`, `ReservationController`,
/// `InventorySettingsController`, `UnitController::reserve`,
/// `OrderController::fromUnits`) rồi ĐỌC LẠI qua `fromJson` — máy chủ trong bộ
/// nhớ lưu thân đã gửi như API thật. Khoá sai tên / parse sót là bài này đỏ.
void main() {
  late _Server server;
  late InventoryApi api;

  setUp(() {
    server = _Server();
    final dio = Dio(BaseOptions(baseUrl: 'http://api.test'))
      ..httpClientAdapter = server;
    api = InventoryApi(ApiClient(dio));
  });

  test('bậc giá: đủ ba bậc, bậc tên null bị ẩn', () async {
    final all = await api.priceTiers();
    expect(all.map((t) => (t.key, t.name)), [
      (PriceTierKey.wholesale, 'Giá sỉ'),
      (PriceTierKey.retail, 'Giá lẻ'),
      (PriceTierKey.tier3, null),
    ]);
    expect(PriceTier.active(all).map((t) => t.name), ['Giá sỉ', 'Giá lẻ']);
    // API cũ chưa có `price_tiers`: dùng hai bậc mặc định.
    expect(PriceTier.active(null).length, 2);
  });

  test('loại hàng: danh sách phẳng thành cây, bỏ loại lưu trữ', () async {
    final list = await api.listCategories();
    final tree = categoryTree(list);
    expect(tree.map((n) => (n.path, n.depth)), [
      ('Piano', 0),
      ('Piano / Piano cơ', 1),
      ('Ghế', 0),
    ]);
  });

  test(
    'mã hàng: lọc, đọc giá / tồn / vị trí; sửa tên + giá rồi đọc lại',
    () async {
      var list = await api.listProducts(
        categoryId: 'c-ghe',
        q: 'ghe',
        tracking: ProductTracking.qty,
      );
      expect(server.lastQuery, {
        'category_id': 'c-ghe',
        'q': 'ghe',
        'tracking': 'qty',
        'limit': 500,
      });
      final ghe = list.single;
      expect(ghe.isQty, isTrue);
      expect(ghe.unitLabel, 'Chiếc');
      expect(ghe.priceOf(PriceTierKey.wholesale), 1200000);
      expect(ghe.priceOf(PriceTierKey.tier3), isNull);
      expect(ghe.fixedCost, 800000);
      expect(ghe.onHand, 12);
      expect(ghe.qtyAt('loc-main'), 10);
      expect(ghe.qtyAt('loc-p1'), 2);

      await api.updateProduct(
        'p-ghe',
        name: ' Ghế đàn nâng hạ cao cấp ',
        prices: {PriceTierKey.retail: 1600000, PriceTierKey.tier3: null},
      );
      expect(server.last('PUT', '/inventory/products/p-ghe'), {
        'name': 'Ghế đàn nâng hạ cao cấp',
        'prices': {'retail': 1600000, 'tier3': null},
      });
      list = await api.listProducts();
      final back = list.firstWhere((p) => p.id == 'p-ghe');
      expect(back.name, 'Ghế đàn nâng hạ cao cấp');
      expect(back.priceOf(PriceTierKey.retail), 1600000);
      // Bậc không gửi giữ giá cũ.
      expect(back.priceOf(PriceTierKey.wholesale), 1200000);
    },
  );

  test('hàng số lượng: nhập, chuyển, đặt số thật (meta.delta)', () async {
    var p = await api.receiveStock(
      productId: 'p-ghe',
      qty: 5,
      locationId: 'loc-main',
      unitCost: 850000,
    );
    expect(server.last('POST', '/inventory/stock/receive'), {
      'product_id': 'p-ghe',
      'qty': 5,
      'location_id': 'loc-main',
      'unit_cost': 850000,
    });
    expect(p.qtyAt('loc-main'), 15);
    expect(p.onHand, 17);
    expect(p.fixedCost, 850000);

    p = await api.transferStock(
      productId: 'p-ghe',
      from: 'loc-main',
      to: 'loc-p1',
      qty: 3,
    );
    expect(server.last('POST', '/inventory/stock/transfer'), {
      'product_id': 'p-ghe',
      'from': 'loc-main',
      'to': 'loc-p1',
      'qty': 3,
    });
    expect((p.qtyAt('loc-main'), p.qtyAt('loc-p1')), (12, 5));

    final r = await api.adjustStock(
      productId: 'p-ghe',
      locationId: 'loc-p1',
      qty: 4,
      note: ' Kiểm kê ',
    );
    expect(server.last('POST', '/inventory/stock/adjust'), {
      'product_id': 'p-ghe',
      'location_id': 'loc-p1',
      'qty': 4,
      'note': 'Kiểm kê',
    });
    expect(r.delta, -1);
    expect(r.product.qtyAt('loc-p1'), 4);
    final again = (await api.listProducts()).firstWhere((x) => x.id == 'p-ghe');
    expect(again.onHand, 16);
  });

  test('giữ hàng có ngày nhận cọc, nguồn tiền, hạn; đọc lại ở phiếu', () async {
    await api.reserve(
      unitIds: ['u1'],
      customerId: 'c1',
      prices: {'u1': 47500000},
      deposit: 5000000,
      depositPaidAt: '2026-11-09',
      moneyAccountId: 'acc-vcb',
      expiresAt: '2026-11-30',
    );
    expect(server.last('POST', '/inventory/units/reserve'), {
      'unit_ids': ['u1'],
      'customer_id': 'c1',
      'prices': {'u1': 47500000},
      'deposit': 5000000,
      'deposit_paid_at': '2026-11-09',
      'money_account_id': 'acc-vcb',
      'expires_at': '2026-11-30',
    });
    final list = await api.listReservations(status: ReservationStatus.active);
    expect(server.lastQuery['status'], 'active');
    final r = list.single;
    expect(r.customerName, 'Anh Dũng Hoàng');
    expect(r.lines.single.label, 'YAMAHA U3H');
    expect(r.lines.single.serial, 'B62-2');
    expect(r.lines.single.price, 47500000);
    expect(r.total, 47500000);
    expect(r.deposit!.amount, 5000000);
    expect(r.deposit!.paidAt, '2026-11-09');
    expect(r.deposit!.moneyAccountId, 'acc-vcb');
    expect(r.expiresAt, '2026-11-30');
    expect(r.expiredOn(DateTime(2026, 12, 1)), isTrue);
    expect(r.expiredOn(DateTime(2026, 11, 30)), isFalse);

    // Client cũ / không có cọc: không gửi khoá mới.
    await api.reserve(unitIds: ['u1'], customerId: 'c1');
    expect(
      server.last('POST', '/inventory/units/reserve')!.keys,
      isNot(contains('deposit_paid_at')),
    );
  });

  test(
    'bán: items[] hàng số lượng, chỉ items thì không gửi unit_ids',
    () async {
      await api.sell(
        customerId: 'c1',
        unitIds: ['u1'],
        prices: {'u1': 50000000},
        items: const [SellItem(productId: 'p-ghe', qty: 2, price: 1200000)],
      );
      expect(server.last('POST', '/orders/from-units'), {
        'customer_id': 'c1',
        'unit_ids': ['u1'],
        'items': [
          {'product_id': 'p-ghe', 'qty': 2, 'price': 1200000},
        ],
        'prices': {'u1': 50000000},
      });

      await api.sell(
        customerId: 'c1',
        unitIds: const [],
        items: const [SellItem(productId: 'p-ghe', qty: 1)],
      );
      expect(server.last('POST', '/orders/from-units'), {
        'customer_id': 'c1',
        'items': [
          {'product_id': 'p-ghe', 'qty': 1},
        ],
      });
    },
  );

  test('cây: mã hàng, loại, giá sỉ từ mã hàng; API cũ → null', () async {
    final u = await api.getUnit('u1');
    expect(u.productId, 'p-u3h');
    expect(u.categoryId, 'c-co');
    expect(u.wholesalePrice, 45000000);
    expect(u.tierPrice(PriceTierKey.wholesale), 45000000);
    expect(u.tierPrice(PriceTierKey.retail), 50000000);
    expect(u.tierPrice(PriceTierKey.tier3), isNull);
    final old = InventoryUnit.fromJson(const {'id': 'x', 'lot_id': 'l'});
    expect(old.productId, isNull);
    expect(old.wholesalePrice, isNull);
  });
}

/// Máy chủ Kho Đợt B trong bộ nhớ — hình dạng phản hồi theo controller API.
class _Server implements HttpClientAdapter {
  final _bodies = <String, Object?>{};
  Map<String, dynamic> lastQuery = const {};

  Map<String, dynamic>? last(String method, String path) =>
      _bodies['$method $path'] as Map<String, dynamic>?;

  final products = <String, Map<String, dynamic>>{
    'p-ghe': {
      'id': 'p-ghe',
      'code': 'GHE-01',
      'name': 'Ghế đàn nâng hạ',
      'category_id': 'c-ghe',
      'category_name': 'Ghế',
      'unit': 'Chiếc',
      'tracking': 'qty',
      'prices': {'wholesale': 1200000, 'retail': 1500000, 'tier3': null},
      'fixed_cost': 800000,
      'archived_at': null,
      'stock': [
        {'location_id': 'loc-main', 'qty': 10},
        {'location_id': 'loc-p1', 'qty': 2},
      ],
    },
  };

  final reservations = <Map<String, dynamic>>[];

  Map<String, dynamic> _present(Map<String, dynamic> p) {
    final stock = (p['stock'] as List).cast<Map<String, dynamic>>();
    final onHand = stock.fold<int>(0, (s, x) => s + (x['qty'] as int));
    return {...p, 'on_hand': onHand, 'available': onHand};
  }

  void _addQty(Map<String, dynamic> p, String loc, int d) {
    final stock = (p['stock'] as List).cast<Map<String, dynamic>>();
    final row = stock.where((s) => s['location_id'] == loc).firstOrNull;
    if (row == null) {
      stock.add({'location_id': loc, 'qty': d});
    } else {
      row['qty'] = (row['qty'] as int) + d;
    }
  }

  Object? _handle(String method, String path, Object? data) {
    final body = data is Map<String, dynamic>
        ? data
        : const <String, dynamic>{};
    switch ((method, path)) {
      case ('GET', '/inventory/settings'):
        return {
          'defect_tags': ['Thiếu chân'],
          'price_tiers': [
            {'key': 'wholesale', 'name': 'Giá sỉ'},
            {'key': 'retail', 'name': 'Giá lẻ'},
            {'key': 'tier3', 'name': null},
          ],
        };
      case ('GET', '/inventory/categories'):
        return [
          {
            'id': 'c-ghe',
            'name': 'Ghế',
            'parent_id': null,
            'order': 2,
            'archived_at': null,
          },
          {
            'id': 'c-piano',
            'name': 'Piano',
            'parent_id': null,
            'order': 1,
            'archived_at': null,
          },
          {
            'id': 'c-co',
            'name': 'Piano cơ',
            'parent_id': 'c-piano',
            'order': 0,
            'archived_at': null,
          },
          {
            'id': 'c-old',
            'name': 'Loại cũ',
            'parent_id': null,
            'order': 0,
            'archived_at': '2026-11-01',
          },
        ];
      case ('GET', '/inventory/products'):
        return [for (final p in products.values) _present(p)];
      case ('PUT', '/inventory/products/p-ghe'):
        final p = products['p-ghe']!;
        if (body['name'] != null) p['name'] = body['name'];
        if (body['prices'] is Map) {
          p['prices'] = {
            ...p['prices'] as Map<String, dynamic>,
            ...body['prices'] as Map<String, dynamic>,
          };
        }
        return _present(p);
      case ('POST', '/inventory/stock/receive'):
        final p = products[body['product_id']]!;
        _addQty(p, body['location_id'] as String, body['qty'] as int);
        if (body['unit_cost'] != null) p['fixed_cost'] = body['unit_cost'];
        return _Meta(_present(p), const {});
      case ('POST', '/inventory/stock/transfer'):
        final p = products[body['product_id']]!;
        _addQty(p, body['from'] as String, -(body['qty'] as int));
        _addQty(p, body['to'] as String, body['qty'] as int);
        return _Meta(_present(p), const {});
      case ('POST', '/inventory/stock/adjust'):
        final p = products[body['product_id']]!;
        final loc = body['location_id'] as String;
        final stock = (p['stock'] as List).cast<Map<String, dynamic>>();
        final cur =
            stock.firstWhere((s) => s['location_id'] == loc)['qty'] as int;
        final delta = (body['qty'] as int) - cur;
        _addQty(p, loc, delta);
        return _Meta(_present(p), {'delta': delta});
      case ('POST', '/inventory/units/reserve'):
        final ids = (body['unit_ids'] as List).cast<String>();
        final prices = (body['prices'] as Map?)?.cast<String, dynamic>() ?? {};
        reservations
          ..clear()
          ..add({
            'id': 'r1',
            'status': 'active',
            'customer_id': body['customer_id'],
            'customer_name': 'Anh Dũng Hoàng',
            'unit_ids': ids,
            'units': [
              for (final id in ids)
                {
                  'unit_id': id,
                  'label': 'YAMAHA U3H',
                  'serial': 'B62-2',
                  'sale': 'reserved',
                  'place': 'in_stock',
                  'price': prices[id],
                },
            ],
            'total': prices.values.fold<num>(0, (s, v) => s + (v as num)),
            'deposit': body['deposit'] == null
                ? null
                : {
                    'amount': body['deposit'],
                    'paid_at': body['deposit_paid_at'],
                    'money_account_id': body['money_account_id'],
                  },
            'expires_at': body['expires_at'],
            'order_id': null,
            'note': null,
            'created_by': 'me',
            'created_at': '2026-11-09T10:00:00+07:00',
            'released_at': null,
          });
        return [_unit()];
      case ('GET', '/inventory/reservations'):
        return _Meta(
          [
            for (final r in reservations)
              if (lastQuery['status'] == null ||
                  r['status'] == lastQuery['status'])
                r,
          ],
          {'total': reservations.length},
        );
      case ('POST', '/orders/from-units'):
        return {'id': 'o1', 'code': 'DH-1'};
      case ('GET', '/inventory/units/u1'):
        return _unit();
    }
    throw StateError('Chưa giả lập: $method $path');
  }

  static Map<String, dynamic> _unit() => {
    'id': 'u1',
    'lot_id': 'l62',
    'maker': 'YAMAHA',
    'model': 'U3H',
    'serial': 'B62-2',
    'list_price': 50000000,
    'place': 'in_stock',
    'sale': 'reserved',
    'category_id': 'c-co',
    'product_id': 'p-u3h',
    'wholesale_price': 45000000,
  };

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.path.replaceFirst('/api/v1', '');
    if (options.method == 'GET') lastQuery = {...options.queryParameters};
    final data = options.data is Map
        ? jsonDecode(jsonEncode(options.data)) as Map<String, dynamic>
        : options.data;
    if (data is Map<String, dynamic>) _bodies['${options.method} $path'] = data;
    final out = _handle(options.method, path, data);
    final body = out is _Meta
        ? {'success': true, 'data': out.data, 'meta': out.meta}
        : {'success': true, 'data': out};
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _Meta {
  const _Meta(this.data, this.meta);

  final Object? data;
  final Map<String, Object?> meta;
}
