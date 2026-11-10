import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/core/network/api_client.dart';
import 'package:omni_app/modules/inventory/data/inventory_api.dart';
import 'package:omni_app/modules/inventory/domain/inventory_models.dart';
import 'package:omni_app/modules/inventory/domain/inventory_permissions.dart';
import 'package:omni_app/security/permissions/access_policy.dart';

/// Kho chuẩn hóa Đợt C trên dây: app GHI bằng đúng tên khoá của controller API
/// (`UnitController::returnUnit`, `CountController`) rồi ĐỌC LẠI qua
/// `fromJson` (`InventoryPresenter::unit` / `::count`, `SlipController`) — máy
/// chủ trong bộ nhớ lưu thân đã gửi như API thật.
void main() {
  late _Server server;
  late InventoryApi api;

  setUp(() {
    server = _Server();
    final dio = Dio(BaseOptions(baseUrl: 'http://api.test'))
      ..httpClientAdapter = server;
    api = InventoryApi(ApiClient(dio));
  });

  test('cây đã giao: khách, phiếu xuất, giá bán, hóa đơn', () async {
    final page = await api.listUnits(place: 'delivered');
    expect(server.lastQuery['place'], 'delivered');
    final u = page.items.single;
    expect(u.place, UnitPlace.delivered);
    expect(u.customerName, 'Anh Dũng');
    expect(u.slipNo, 'PX-2611-001');
    expect(u.soldPrice, 52000000);
    expect(u.invoice?.status, InvoiceStatus.issued);
    expect(u.invoice?.no, 'HD-77');
    expect(u.invoice?.date, '2026-11-10');
    // Cây bán trước khi có tính năng: invoice null, không đoán "Chưa xuất".
    final old = InventoryUnit.fromJson({
      'id': 'x',
      'lot_id': 'l',
      'invoice': null,
    });
    expect(old.invoice, isNull);
    expect(old.slipNo, isNull);
  });

  test('nhập lại kho: gửi vị trí, tình trạng, ghi chú; đọc lại cây', () async {
    final u = await api.returnUnit(
      'u9',
      locationId: 'loc-p1',
      condition: UnitCondition.defective,
      note: '  Khách trả, sứt góc ',
    );
    expect(server.last('POST', '/inventory/units/u9/return'), {
      'location_id': 'loc-p1',
      'condition': 'defective',
      'note': 'Khách trả, sứt góc',
    });
    expect(u.place, UnitPlace.inStock);
    expect(u.locationId, 'loc-p1');
    expect(u.condition, UnitCondition.defective);
    expect(u.sale, UnitSale.available);

    // Mặc định: không gửi khoá nào (vị trí mặc định, Chưa kiểm).
    await api.returnUnit('u9');
    expect(server.last('POST', '/inventory/units/u9/return'), isEmpty);
  });

  test('kiểm kê: mở, tick + đếm, chốt, duyệt — mỗi bước đọc lại', () async {
    var c = await api.openCount('loc-main');
    expect(server.last('POST', '/inventory/counts'), {
      'location_id': 'loc-main',
    });
    expect(c.status, CountStatus.open);
    expect(c.locationName, 'Kho chính');

    c = await api.saveCount(c.id, seenUnitIds: ['u1', 'u2'], qty: {'p-ghe': 9});
    expect(server.last('PUT', '/inventory/counts/cnt1'), {
      'seen_unit_ids': ['u1', 'u2'],
      'qty': [
        {'product_id': 'p-ghe', 'qty': 9},
      ],
    });
    expect(c.seenUnitIds, ['u1', 'u2']);
    expect(c.qty, {'p-ghe': 9});

    // Đọc lại qua danh sách theo vị trí.
    final list = await api.listCounts(locationId: 'loc-main');
    expect(server.lastQuery, {'location_id': 'loc-main'});
    expect(list.single.seenUnitIds, ['u1', 'u2']);

    c = await api.submitCount(c.id);
    expect(c.status, CountStatus.submitted);
    expect(c.missingUnitIds, ['u3']);
    expect(c.missingUnits.single.label, 'YAMAHA U1H');
    expect(c.missingUnits.single.serial, 'B-3');
    expect(c.submittedAt, isNotNull);
    expect(c.missingCount, isNull);

    c = await api.approveCount(c.id);
    expect(c.status, CountStatus.approved);
    expect(c.missingCount, 1);
    expect(c.qtyDeltas, {'p-ghe': -1});
    expect((await api.getCount(c.id)).status, CountStatus.approved);
  });

  test('cây theo sổ: đọc hết các trang, bỏ cây đã Không thấy', () async {
    server.stockUnits = 205;
    final units = await api.countUnits('loc-main');
    expect(server.unitQueries.length, 2);
    expect(server.unitQueries.first, {
      'place': 'in_stock',
      'location_id': 'loc-main',
      'limit': 200,
      'offset': 0,
    });
    expect(server.unitQueries.last['offset'], 200);
    // Cây thứ 0 là `missing`.
    expect(units.length, 204);
    expect(units.any((u) => u.condition == UnitCondition.missing), isFalse);
  });

  test('phiếu xuất: dòng hàng, serial, ĐVT, thành tiền, tổng', () async {
    final s = await api.getSlip('PX-2611-001');
    expect(s.no, 'PX-2611-001');
    expect(s.customerName, 'Anh Dũng');
    expect(s.date, '2026-11-10');
    expect(s.lines.length, 2);
    expect(s.lines.first.serial, 'B62-2');
    expect(s.lines.first.unit, 'Chiếc');
    expect(s.lines.last.qty, 2);
    expect(s.lines.last.unit, 'Bộ');
    expect(s.lines.last.amount, 3000000);
    expect(s.total, 55000000);
  });

  test('quyền Đợt C: thiếu capability thì ẩn hết', () {
    final policy = AccessPolicy(const {
      'inventory.read',
      'inventory.write',
      'inventory.settings',
    });
    final none = InventoryPerms.from(
      capable: true,
      policy: policy,
      supports: (_) => false,
    );
    expect([
      none.counts,
      none.delivered,
      none.returns,
      none.slips,
      none.invoices,
    ], everyElement(isFalse));
    final all = InventoryPerms.from(
      capable: true,
      policy: policy,
      supports: (c) => true,
    );
    expect(all.counts && all.doCounts && all.approveCounts, isTrue);
    expect(all.delivered && all.returns && all.slips && all.invoices, isTrue);
    final readOnly = InventoryPerms.from(
      capable: true,
      policy: AccessPolicy(const {'inventory.read'}),
      supports: (c) => true,
    );
    expect(readOnly.counts && readOnly.delivered, isTrue);
    expect([
      readOnly.doCounts,
      readOnly.approveCounts,
      readOnly.returns,
    ], everyElement(isFalse));
  });
}

class _Server implements HttpClientAdapter {
  final _bodies = <String, Object?>{};
  Map<String, dynamic> lastQuery = const {};
  final unitQueries = <Map<String, dynamic>>[];
  int stockUnits = 0;

  Map<String, dynamic>? last(String method, String path) =>
      _bodies['$method $path'] as Map<String, dynamic>?;

  Map<String, dynamic>? _count;

  Map<String, dynamic> _presentCount() => {
    ..._count!,
    'location_name': 'Kho chính',
    'missing_units': [
      for (final id in _count!['missing_unit_ids'] as List)
        {'unit_id': id, 'label': 'YAMAHA U1H', 'serial': 'B-3'},
    ],
  };

  Object? _handle(String method, String path, Map<String, dynamic> body) {
    switch ((method, path)) {
      case ('GET', '/inventory/units'):
        if (lastQuery['place'] == 'delivered') {
          return _Meta(
            [
              {
                'id': 'u9',
                'lot_id': 'l62',
                'maker': 'YAMAHA',
                'model': 'U3H',
                'serial': 'B62-2',
                'place': 'delivered',
                'sale': 'sold',
                'customer_id': 'c1',
                'customer_name': 'Anh Dũng',
                'delivered_at': '2026-11-10T10:00:00+07:00',
                'slip_no': 'PX-2611-001',
                'sold_price': 52000000,
                'invoice': {
                  'status': 'issued',
                  'no': 'HD-77',
                  'date': '2026-11-10',
                },
              },
            ],
            {'total': 1},
          );
        }
        unitQueries.add({...lastQuery});
        final offset = lastQuery['offset'] as int;
        final limit = lastQuery['limit'] as int;
        return _Meta(
          [
            for (var i = offset; i < stockUnits && i < offset + limit; i++)
              {
                'id': 's$i',
                'lot_id': 'l',
                'place': 'in_stock',
                'condition': i == 0 ? 'missing' : 'ready',
              },
          ],
          {'total': stockUnits},
        );
      case ('POST', '/inventory/units/u9/return'):
        return {
          'id': 'u9',
          'lot_id': 'l62',
          'place': 'in_stock',
          'sale': 'available',
          'location_id': body['location_id'] ?? 'loc-main',
          'condition': body['condition'],
          'note': body['note'],
          'invoice': null,
        };
      case ('POST', '/inventory/counts'):
        _count ??= {
          'id': 'cnt1',
          'location_id': body['location_id'],
          'status': 'open',
          'seen_unit_ids': <String>[],
          'qty': <Map<String, dynamic>>[],
          'missing_unit_ids': <String>[],
          'result': null,
        };
        return _presentCount();
      case ('GET', '/inventory/counts'):
        return [
          if (_count != null &&
              _count!['location_id'] == lastQuery['location_id'])
            _presentCount(),
        ];
      case ('PUT', '/inventory/counts/cnt1'):
        _count!['seen_unit_ids'] = body['seen_unit_ids'];
        _count!['qty'] = body['qty'];
        return _presentCount();
      case ('GET', '/inventory/counts/cnt1'):
        return _presentCount();
      case ('POST', '/inventory/counts/cnt1/submit'):
        _count!['status'] = 'submitted';
        _count!['missing_unit_ids'] = ['u3'];
        _count!['submitted_at'] = '2026-11-11T02:00:00Z';
        return _presentCount();
      case ('POST', '/inventory/counts/cnt1/approve'):
        _count!['status'] = 'approved';
        _count!['approved_at'] = '2026-11-11T03:00:00Z';
        _count!['result'] = {
          'missing_units': 1,
          'qty_deltas': [
            {'product_id': 'p-ghe', 'delta': -1},
          ],
        };
        return _presentCount();
      case ('GET', '/inventory/slips/PX-2611-001'):
        return {
          'no': 'PX-2611-001',
          'date': '2026-11-10',
          'order_id': 'o1',
          'customer_id': 'c1',
          'customer_name': 'Anh Dũng',
          'by': 'me',
          'lines': [
            {
              'unit_id': 'u9',
              'product_id': 'p-u3h',
              'code': 'U3H',
              'name': 'YAMAHA U3H',
              'serial': 'B62-2',
              'unit': 'Chiếc',
              'qty': 1,
              'price': 52000000,
              'amount': 52000000,
            },
            {
              'unit_id': null,
              'product_id': 'p-ghe',
              'code': 'GHE-01',
              'name': 'Ghế đàn',
              'serial': null,
              'unit': 'Bộ',
              'qty': 2,
              'price': 1500000,
              'amount': 3000000,
            },
          ],
          'total': 55000000,
        };
    }
    throw StateError('Chưa giả lập: $method $path');
  }

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
        : <String, dynamic>{};
    if (options.method != 'GET') _bodies['${options.method} $path'] = data;
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
