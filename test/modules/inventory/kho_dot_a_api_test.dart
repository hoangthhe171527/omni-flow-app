import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/core/network/api_client.dart';
import 'package:omni_app/modules/inventory/data/inventory_api.dart';
import 'package:omni_app/modules/inventory/domain/inventory_models.dart';
import 'package:omni_app/modules/inventory/domain/receive.dart';

/// Kho chuẩn hóa Đợt A trên dây: app GHI bằng đúng tên khoá của controller
/// API rồi ĐỌC LẠI qua `fromJson` — một máy chủ trong bộ nhớ lưu thân đã gửi
/// như API thật (UnitController, UnitPhotoController, LotController::receive,
/// ClaimController, SupplierController). Thiếu một chỗ (khoá sai tên, parse
/// sót) là bài này đỏ, thay vì 200 rồi mất dữ liệu lặng.
void main() {
  late _Server server;
  late InventoryApi api;

  setUp(() {
    server = _Server();
    final dio = Dio(BaseOptions(baseUrl: 'http://api.test'))
      ..httpClientAdapter = server;
    api = InventoryApi(ApiClient(dio));
  });

  test(
    'cây: nhãn lỗi, ghi chú ghi rồi đọc lại; API cũ không có khoá',
    () async {
      final before = await api.getUnit('u1');
      expect(before.defectTags, isEmpty);
      expect(before.locationName, 'Kho chính');
      expect(before.coverUrl, isNull);

      await api.updateUnit('u1', {
        'defect_tags': ['Thiếu chân', 'Sụt phím'],
        'note': 'Tiếng ấm',
      });
      final after = await api.getUnit('u1');
      expect(server.last('PUT', '/inventory/units/u1'), {
        'defect_tags': ['Thiếu chân', 'Sụt phím'],
        'note': 'Tiếng ấm',
      });
      expect(after.defectTags, ['Thiếu chân', 'Sụt phím']);
      expect(after.note, 'Tiếng ấm');

      // API trước Đợt A: không khoá → null (ẩn phần mới), không phải rỗng.
      final old = InventoryUnit.fromJson(const {'id': 'x', 'lot_id': 'l'});
      expect(old.defectTags, isNull);
      expect(old.photoCount, isNull);
      expect(old.locationId, isNull);
    },
  );

  test(
    'vị trí: multi_location, chuyển cây, lọc theo vị trí, thẻ kho',
    () async {
      expect((await api.stockSummary()).multiLocation, isTrue);
      final locs = await api.listLocations();
      expect(locs.map((l) => (l.name, l.isDefault, l.unitCount)), [
        ('Kho chính', true, 2),
        ('Đại lý Sao Mai', false, 0),
      ]);

      final res = await api.moveUnits(
        unitIds: ['u1', 'u2'],
        toLocationId: 'loc-p1',
      );
      expect(server.last('POST', '/inventory/units/move'), {
        'unit_ids': ['u1', 'u2'],
        'to_location_id': 'loc-p1',
      });
      expect(res.moved, 1);
      expect(res.skipped, 1);
      final page = await api.listUnits(locationId: 'loc-p1');
      expect(server.lastQuery['location_id'], 'loc-p1');
      // u2 đã ở đó từ trước (bị bỏ qua), u1 vừa chuyển tới.
      expect(page.items.map((u) => (u.id, u.locationName)), [
        ('u1', 'Đại lý Sao Mai'),
        ('u2', 'Đại lý Sao Mai'),
      ]);

      final ledger = await api.unitLedger('u1');
      expect(ledger.map((r) => (r.text, r.when)), [
        ('Tân trang: Lên dây', 'Đang làm'),
        ('Chuyển từ Kho chính đến Đại lý Sao Mai', '10/11/2026'),
        ('Nhận vào Kho chính', '12/10/2026'),
      ]);
    },
  );

  test(
    'ảnh: tải nhiều ảnh files[], đặt đại diện, xoá; ảnh việc chỉ đọc',
    () async {
      final dir = Directory.systemTemp.createTempSync('kho-a');
      addTearDown(() => dir.deleteSync(recursive: true));
      final a = File('${dir.path}/a.jpg')..writeAsBytesSync([1, 2, 3]);
      final b = File('${dir.path}/b.jpg')..writeAsBytesSync([4, 5]);

      final up = await api.uploadPhotos('u1', [
        (path: a.path, name: 'a.jpg'),
        (path: b.path, name: 'b.jpg'),
      ]);
      expect(server.uploadedFields, ['files[]', 'files[]']);
      expect(up.where((p) => !p.fromTask).length, 2);

      var list = await api.unitPhotos('u1');
      expect(list.firstWhere((p) => p.isCover).id, 'p1');
      expect(list.where((p) => p.fromTask).single.taskTitle, 'Lên dây');

      await api.setCover('u1', 'p2');
      expect(server.last('PUT', '/inventory/units/u1/cover'), {
        'photo_id': 'p2',
      });
      list = await api.unitPhotos('u1');
      expect(list.firstWhere((p) => p.isCover).id, 'p2');

      await api.deletePhoto('u1', 'p2');
      list = await api.unitPhotos('u1');
      expect(list.map((p) => p.id), ['p1', 'task:t1']);
      expect(list.firstWhere((p) => p.isCover).id, 'p1');
      expect(await api.defectTags(), contains('Thiếu chân'));
    },
  );

  test(
    'nhận hàng: vị trí + cách xử lý cây thiếu / lỗi, đọc lại khoản đòi',
    () async {
      const units = [
        InventoryUnit(id: 'u1', lotId: 'l1'),
        InventoryUnit(id: 'u2', lotId: 'l1'),
        InventoryUnit(id: 'u3', lotId: 'l1'),
      ];
      final results = {'u2': ReceiveResult.missing, 'u3': ReceiveResult.defect};
      final lines = buildReceiveLines(
        units,
        result: (id) => results[id] ?? ReceiveResult.ok,
        serials: const {},
        claims: const {
          'u3': ReceiveClaim(
            resolution: ClaimResolution.deduct,
            amountJpy: 20000,
          ),
        },
        withClaims: true,
      );
      await api.receive(
        'l1',
        receivedAt: '2026-11-10',
        results: lines,
        locationId: 'loc-p1',
      );
      final body = server.last('POST', '/inventory/lots/l1/receive')!;
      expect(body['location_id'], 'loc-p1');
      expect(body['results'], [
        {'unit_id': 'u2', 'result': 'missing', 'resolution': 'deduct'},
        {
          'unit_id': 'u3',
          'result': 'defect',
          'resolution': 'deduct',
          'amount_jpy': 20000,
        },
      ]);

      final lot = await api.getLot('l1');
      expect(lot.claims!.map((c) => (c.unitId, c.missing, c.resolution)), [
        ('u2', true, ClaimResolution.deduct),
        ('u3', false, ClaimResolution.deduct),
      ]);
      expect(lot.claims!.last.amountJpy, 20000);
    },
  );

  test('khoản đòi + tổng ¥ dự kiến: sửa rồi đọc lại lô', () async {
    await api.updateClaim(
      'c1',
      const ClaimInput(
        missing: true,
        resolution: ClaimResolution.replaceLater,
        settled: true,
        amountJpy: 999,
      ),
    );
    // Cây thiếu: không gửi số ¥ riêng (API bỏ).
    expect(server.last('PUT', '/inventory/claims/c1'), {
      'resolution': 'replace_later',
      'status': 'settled',
    });
    await api.setExpectedJpy('l2', 1850000);
    expect(server.last('PUT', '/inventory/lots/l2'), {'expected_jpy': 1850000});

    final lot = await api.getLot('l2');
    final c = lot.claims!.single;
    expect(c.resolution, ClaimResolution.replaceLater);
    expect(c.settled, isTrue);
    expect(lot.expectedJpy, 1850000);
    expect(lot.debtBaseJpy, 1700000);
    expect(lot.prepaidJpy, 0);
  });

  test('nhà cung cấp: hồ sơ ghi rồi đọc lại; nợ chỉ khi có quyền', () async {
    final list = await api.listSupplierDetails();
    expect(list.map((s) => (s.code, s.hasDebt)), [
      ('Epco', true),
      ('ĐN', false),
    ]);

    final s = await api.getSupplier('s1');
    expect(s.lots!.single.overdue, isTrue);
    await api.updateSupplier(
      's1',
      SupplierInput(
        name: 'Epco Hamamatsu',
        foreign: true,
        person: false,
        currency: 'JPY',
        term: PaymentTermKind.days,
        termDays: 15,
        phone: ' +81 53 000 0101 ',
        address: '',
        bankAccounts: const [
          BankAccount(bank: 'Shizuoka Bank', number: '0123456', holder: ''),
          BankAccount(bank: '', number: '999'),
        ],
      ),
    );
    final body = server.last('PUT', '/inventory/suppliers/s1')!;
    expect(body['payment_term'], {'kind': 'days', 'days': 15});
    expect(body['address'], isNull);
    expect(body['bank_accounts'], [
      {'bank': 'Shizuoka Bank', 'number': '0123456', 'holder': null},
    ]);

    final back = await api.getSupplier('s1');
    expect(back.name, 'Epco Hamamatsu');
    expect(back.phone, '+81 53 000 0101');
    expect(back.termLabel, 'Trả sau 15 ngày');
    expect(back.bankAccounts.single.number, '0123456');
    expect(back.debtJpy, 1700000);
  });
}

/// Máy chủ Kho trong bộ nhớ — hình dạng phản hồi theo controller API.
class _Server implements HttpClientAdapter {
  final _bodies = <String, Object?>{};
  Map<String, dynamic> lastQuery = const {};
  List<String> uploadedFields = const [];

  Map<String, dynamic>? last(String method, String path) =>
      _bodies['$method $path'] as Map<String, dynamic>?;

  final units = <String, Map<String, dynamic>>{
    'u1': _unit('u1', 'loc-main', 'Kho chính'),
    'u2': _unit('u2', 'loc-p1', 'Đại lý Sao Mai'),
  };
  final locations = [
    {
      'id': 'loc-main',
      'name': 'Kho chính',
      'kind': 'warehouse',
      'partner_customer_id': null,
      'partner_customer_name': null,
      'is_default': true,
      'archived_at': null,
      'unit_count': 2,
    },
    {
      'id': 'loc-p1',
      'name': 'Đại lý Sao Mai',
      'kind': 'partner',
      'partner_customer_id': null,
      'partner_customer_name': null,
      'is_default': false,
      'archived_at': null,
      'unit_count': 0,
    },
  ];
  final photos = <Map<String, dynamic>>[];
  final lots = <String, Map<String, dynamic>>{
    'l1': _lot('l1', claims: []),
    'l2': _lot(
      'l2',
      claims: [
        {
          'id': 'c1',
          'lot_id': 'l2',
          'unit_id': 'u9',
          'kind': 'missing',
          'resolution': 'deduct',
          'status': 'open',
          'settled_at': null,
          'note': null,
          'debt_cut_jpy': 150000,
        },
      ],
    ),
  };
  final suppliers = <String, Map<String, dynamic>>{
    's1': {
      ..._supplier('s1', 'Epco', 'foreign'),
      'debt_jpy': 1700000,
      'overdue_jpy': 1700000,
      'prepaid_jpy': 0,
      'open_lots': 1,
    },
    's2': _supplier('s2', 'ĐN', 'domestic'),
  };

  static Map<String, dynamic> _unit(String id, String loc, String name) => {
    'id': id,
    'lot_id': 'l1',
    'maker': 'YAMAHA',
    'model': 'U3H',
    'place': 'in_stock',
    'sale': 'available',
    'location_id': loc,
    'location_name': name,
    'location_kind': 'warehouse',
    'delivered_at': null,
    'defect_tags': <String>[],
    'photo_count': 0,
    'cover_url': null,
    'note': null,
  };

  static Map<String, dynamic> _lot(String id, {required List claims}) => {
    'id': id,
    'code': 'Ep 6${id.substring(1)}',
    'status': 'in_transit',
    'expected_jpy': null,
    'debt_base_jpy': 1700000,
    'prepaid_jpy': 0,
    'claims': claims,
  };

  static Map<String, dynamic> _supplier(String id, String code, String o) => {
    'id': id,
    'code': code,
    'name': code,
    'country': null,
    'kind': 'import',
    'origin': o,
    'party': 'org',
    'tax_id': null,
    'phone': null,
    'address': null,
    'bank_accounts': <Map<String, dynamic>>[],
    'customer_id': null,
    'customer_name': null,
    'currency': 'JPY',
    'payment_term': {'kind': 'on_clearance', 'days': null},
    'note': null,
  };

  List<Map<String, dynamic>> _allPhotos() => [
    for (final p in photos) {...p, 'is_cover': p['id'] == _cover},
    {
      'id': 'task:t1',
      'url': 'https://x.test/t1.jpg',
      'source': 'task',
      'task_id': 't1',
      'task_title': 'Lên dây',
      'by': null,
      'at': '2026-11-01',
      'is_cover': false,
    },
  ];
  String? _cover;

  Object? _handle(String method, String path, Object? data) {
    switch ((method, path)) {
      case ('GET', '/inventory/units/summary'):
        return {'available': 2, 'multi_location': true};
      case ('GET', '/inventory/locations'):
        return locations;
      case ('GET', '/inventory/settings'):
        return {
          'defect_tags': ['Thiếu chân', 'Sụt phím'],
        };
      case ('GET', '/inventory/units'):
        final loc = lastQuery['location_id'];
        return [
          for (final u in units.values)
            if (loc == null || u['location_id'] == loc) u,
        ];
      case ('POST', '/inventory/units/move'):
        final b = data! as Map<String, dynamic>;
        final to = locations.firstWhere((l) => l['id'] == b['to_location_id']);
        final moved = <String>[], skipped = <String>[];
        for (final id in (b['unit_ids'] as List).cast<String>()) {
          final u = units[id]!;
          if (u['location_id'] == to['id']) {
            skipped.add(id);
            continue;
          }
          u['location_id'] = to['id'];
          u['location_name'] = to['name'];
          moved.add(id);
        }
        return _Meta(
          [for (final id in b['unit_ids'] as List) units[id]],
          {'moved': moved, 'skipped': skipped},
        );
      case ('GET', '/inventory/units/u1/ledger'):
        return [
          {
            'id': 'task:t1',
            'type': 'work',
            'kind': 'refurbish',
            'at': null,
            'task_id': 't1',
            'title': 'Lên dây',
            'state': 'doing',
            'project_name': 'Xưởng',
          },
          {
            'id': 'm2',
            'type': 'move',
            'kind': 'transfer',
            'at': '2026-11-10T03:00:00+07:00',
            'from_location_id': 'loc-main',
            'from_location_name': 'Kho chính',
            'to_location_id': 'loc-p1',
            'to_location_name': 'Đại lý Sao Mai',
            'ref': <String, dynamic>{},
            'by': 'x',
            'note': null,
          },
          {
            'id': 'm1',
            'type': 'move',
            'kind': 'receive',
            'at': '2026-10-12',
            'from_location_id': null,
            'from_location_name': null,
            'to_location_id': 'loc-main',
            'to_location_name': 'Kho chính',
            'ref': {'lot_id': 'l1'},
            'by': 'x',
            'note': null,
          },
        ];
      case ('GET', '/inventory/units/u1/photos'):
        return _allPhotos();
      case ('POST', '/inventory/units/u1/photos'):
        final form = data! as FormData;
        uploadedFields = [for (final f in form.files) f.key];
        for (final f in form.files) {
          final id = 'p${photos.length + 1}';
          photos.add({
            'id': id,
            'url': 'https://x.test/${f.value.filename}',
            'source': 'stock',
            'task_id': null,
            'task_title': null,
            'by': 'me',
            'at': '2026-11-10',
          });
          _cover ??= id;
        }
        return _allPhotos();
      case ('PUT', '/inventory/units/u1/cover'):
        _cover = (data! as Map)['photo_id'] as String;
        return _allPhotos();
      case ('DELETE', final String p)
          when p.startsWith('/inventory/units/u1/photos/'):
        final id = p.split('/').last;
        photos.removeWhere((x) => x['id'] == id);
        if (_cover == id) _cover = photos.firstOrNull?['id'] as String?;
        return _allPhotos();
      case ('GET', final String p) when p.startsWith('/inventory/units/'):
        return units[p.split('/').last];
      case ('PUT', final String p) when p.startsWith('/inventory/units/'):
        final u = units[p.split('/').last]!
          ..addAll(data! as Map<String, dynamic>);
        return u;
      case ('POST', '/inventory/lots/l1/receive'):
        final b = data! as Map<String, dynamic>;
        final lot = lots['l1']!;
        lot['status'] = 'received';
        for (final r in (b['results'] as List).cast<Map<String, dynamic>>()) {
          if (r['result'] == 'missing' ||
              (r['result'] == 'defect' && r['resolution'] != null)) {
            (lot['claims'] as List).add({
              'id': 'c-${r['unit_id']}',
              'lot_id': 'l1',
              'unit_id': r['unit_id'],
              'kind': r['result'],
              'resolution': r['resolution'],
              'status': 'open',
              'settled_at': null,
              'note': null,
              'amount_jpy': r['amount_jpy'],
            });
          }
        }
        return _Meta(lot, {
          'counts': {'ok': 1, 'missing': 1, 'defect': 1},
          'warnings': <Object>[],
        });
      case ('GET', final String p) when p.startsWith('/inventory/lots/'):
        return lots[p.split('/').last];
      case ('PUT', final String p) when p.startsWith('/inventory/lots/'):
        return lots[p.split('/').last]!..addAll(data! as Map<String, dynamic>);
      case ('PUT', '/inventory/claims/c1'):
        final b = data! as Map<String, dynamic>;
        final c = (lots['l2']!['claims'] as List).single as Map<String, dynamic>
          ..addAll(b);
        return c;
      case ('GET', '/inventory/suppliers'):
        return suppliers.values.toList();
      case ('GET', '/inventory/suppliers/s1'):
        return {
          ...suppliers['s1']!,
          'lots': [
            {
              'id': 'l2',
              'code': 'Ep 62',
              'status': 'received',
              'received_at': '2026-10-01',
              'due_jpy': 1700000,
              'prepaid_jpy': 0,
              'overdue': true,
            },
          ],
        };
      case ('PUT', '/inventory/suppliers/s1'):
        return suppliers['s1']!..addAll(data! as Map<String, dynamic>);
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
