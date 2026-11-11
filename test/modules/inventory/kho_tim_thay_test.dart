import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/core/network/api_client.dart';
import 'package:omni_app/modules/inventory/application/inventory_providers.dart';
import 'package:omni_app/modules/inventory/domain/inventory_models.dart';
import 'package:omni_app/modules/inventory/domain/inventory_permissions.dart';
import 'package:omni_app/modules/inventory/presentation/stock_page.dart';
import 'package:omni_app/security/permissions/access_policy.dart';
import 'package:omni_app/security/session/session_controller.dart';

import 'fake_inventory_api.dart';

/// Cây "Không thấy" sau kiểm kê (TNP_KHO_DOT_B_C §2.9): tab riêng ở Tồn kho
/// (API bỏ chúng khỏi danh sách trong kho trừ khi lọc `condition=missing`),
/// nút "Tìm thấy" trong chi tiết cây gửi `POST /units/{id}/found` rồi đọc lại
/// cây và thẻ kho. Chỉ có khi API có capability `inventory.found`.
void main() {
  group('trên dây', () {
    late _Server server;
    late InventoryApi api;

    setUp(() {
      server = _Server();
      final dio = Dio(BaseOptions(baseUrl: 'http://api.test'))
        ..httpClientAdapter = server;
      api = InventoryApi(ApiClient(dio));
    });

    test(
      'lọc condition=missing; tìm thấy gửi đúng khoá, đọc lại cây',
      () async {
        await api.listUnits(place: 'in_stock', condition: 'missing', limit: 1);
        expect(server.lastQuery['condition'], 'missing');
        expect(server.lastQuery.containsKey('sale'), isFalse);

        final u = await api.foundUnit(
          'u7',
          locationId: 'loc-p1',
          condition: UnitCondition.ready,
          note: '  Nằm sau kho ',
        );
        expect(server.lastBody, {
          'location_id': 'loc-p1',
          'condition': 'ready',
          'note': 'Nằm sau kho',
        });
        expect(server.lastPath, '/inventory/units/u7/found');
        expect(u.condition, UnitCondition.ready);
        expect(u.locationId, 'loc-p1');

        // Mặc định: không gửi khoá nào (vị trí mặc định, Chưa kiểm).
        final d = await api.foundUnit('u7');
        expect(server.lastBody, isEmpty);
        expect(d.condition, isNull);
      },
    );

    test('quyền: thiếu capability thì ẩn; chỉ xem thì thấy tab, không nút', () {
      final writer = AccessPolicy(const {'inventory.read', 'inventory.write'});
      final none = InventoryPerms.from(
        capable: true,
        policy: writer,
        supports: (c) => c != 'inventory.found',
      );
      expect([none.missing, none.found], [false, false]);
      final all = InventoryPerms.from(
        capable: true,
        policy: writer,
        supports: (_) => true,
      );
      expect([all.missing, all.found], [true, true]);
      final reader = InventoryPerms.from(
        capable: true,
        policy: AccessPolicy(const {'inventory.read'}),
        supports: (_) => true,
      );
      expect([reader.missing, reader.found], [true, false]);
    });
  });

  group('Tồn kho · Không thấy', () {
    final today = DateTime(2026, 11, 11);
    const perms = InventoryPerms(
      read: true,
      write: true,
      reserve: true,
      sell: true,
      locations: true,
      counts: true,
      missing: true,
      found: true,
    );
    const viewer = InventoryPerms(read: true, locations: true, missing: true);
    const old = InventoryPerms(read: true, write: true, locations: true);
    const locations = [
      StockLocation(id: 'main', name: 'Kho chính', isDefault: true),
      StockLocation(id: 'p1', name: 'Showroom Q7', kind: 'showroom'),
    ];
    const u1 = InventoryUnit(
      id: 'u1',
      lotId: 'l62',
      lotCode: 'Ep 62',
      maker: 'KAWAI',
      model: 'BL71',
      serial: 'K-881',
      place: UnitPlace.inStock,
      receivedAt: '2026-11-01',
      locationId: 'main',
      locationName: 'Kho chính',
    );
    const u7 = InventoryUnit(
      id: 'u7',
      lotId: 'l62',
      lotCode: 'Ep 62',
      maker: 'YAMAHA',
      model: 'U3H',
      serial: 'B62-7',
      place: UnitPlace.inStock,
      condition: UnitCondition.missing,
      receivedAt: '2026-11-01',
      locationId: 'main',
      locationName: 'Kho chính',
    );

    void phone(WidgetTester t) {
      t.view.physicalSize = const Size(390, 1800);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
    }

    FakeInventoryApi fake() => FakeInventoryApi(
      units: const [u1, u7],
      multiLocation: true,
      locations: locations,
    );

    Widget app(FakeInventoryApi api, InventoryPerms p) => ProviderScope(
      overrides: [
        inventoryApiProvider.overrideWithValue(api),
        inventoryPermsProvider.overrideWithValue(p),
        inventoryTodayProvider.overrideWithValue(today),
        accessProvider.overrideWithValue(AccessPolicy(const {})),
      ],
      child: const MaterialApp(home: StockPage()),
    );

    testWidgets('tab Không thấy có số đếm, chỉ liệt kê cây không thấy', (
      t,
    ) async {
      phone(t);
      final api = fake();
      await t.pumpWidget(app(api, perms));
      await t.pumpAndSettle();
      // Còn bán không gồm cây không thấy.
      expect(find.byKey(const ValueKey('inv-unit-u7')), findsNothing);
      await t.tap(find.text('Không thấy 1'));
      await t.pumpAndSettle();
      expect(api.listCalls.last['condition'], 'missing');
      expect(api.listCalls.last['sale'], isNull);
      expect(find.byKey(const ValueKey('inv-unit-u7')), findsOneWidget);
      expect(find.byKey(const ValueKey('inv-unit-u1')), findsNothing);
      // Không chọn nhiều cây ở tab này.
      expect(find.byKey(const ValueKey('inv-stock-multi')), findsNothing);
    });

    testWidgets('Tìm thấy: vị trí, tình trạng, ghi chú; thẻ kho có dòng mới', (
      t,
    ) async {
      phone(t);
      final api = fake();
      await t.pumpWidget(app(api, perms));
      await t.pumpAndSettle();
      await t.tap(find.text('Không thấy 1'));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('inv-unit-u7')));
      await t.pumpAndSettle();
      // Cây không thấy thì không bán.
      expect(find.byKey(const ValueKey('inv-unit-sell')), findsNothing);
      await t.tap(find.byKey(const ValueKey('inv-unit-found')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('inv-return-location')));
      await t.pumpAndSettle();
      await t.tap(find.text('Showroom Q7').last);
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('inv-return-condition')));
      await t.pumpAndSettle();
      await t.tap(find.text('Sẵn sàng'));
      await t.pumpAndSettle();
      await t.enterText(
        find.byKey(const ValueKey('inv-return-note')),
        'Nằm sau kho',
      );
      await t.tap(find.byKey(const ValueKey('inv-return-save')));
      await t.pumpAndSettle();
      expect(api.founds.single.$1, 'u7');
      expect(api.founds.single.$2, {
        'location_id': 'p1',
        'condition': 'ready',
        'note': 'Nằm sau kho',
      });
      // Đọc lại: sheet ở lại với cây mới, thẻ kho tải lại có dòng thấy lại.
      expect(find.byKey(const ValueKey('inv-unit-found')), findsNothing);
      expect(find.byKey(const ValueKey('inv-unit-sell')), findsOneWidget);
      expect(find.text('Kiểm kê: thấy lại'), findsOneWidget);
      // Đóng sheet: cây rời tab Không thấy, về Còn bán.
      await t.tapAt(const Offset(195, 20));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('inv-unit-u7')), findsNothing);
      expect(find.text('Không thấy 0'), findsOneWidget);
      await t.tap(find.textContaining('Còn bán'));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('inv-unit-u7')), findsOneWidget);
    });

    testWidgets('chỉ quyền xem: có tab, không nút Tìm thấy', (t) async {
      phone(t);
      await t.pumpWidget(app(fake(), viewer));
      await t.pumpAndSettle();
      await t.tap(find.text('Không thấy 1'));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('inv-unit-u7')));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('inv-unit-found')), findsNothing);
    });

    testWidgets('API thiếu inventory.found: không tab Không thấy', (t) async {
      phone(t);
      final api = fake();
      await t.pumpWidget(app(api, old));
      await t.pumpAndSettle();
      expect(find.textContaining('Không thấy'), findsNothing);
      expect(api.listCalls.any((c) => c['condition'] != null), isFalse);
    });
  });
}

/// Máy chủ trong bộ nhớ: trả cây theo thân đã gửi như `UnitController::found`.
class _Server implements HttpClientAdapter {
  Map<String, dynamic> lastQuery = const {};
  Map<String, dynamic>? lastBody;
  String? lastPath;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.path.replaceFirst('/api/v1', '');
    final Object body;
    if (options.method == 'GET') {
      lastQuery = {...options.queryParameters};
      body = {
        'success': true,
        'data': <Object>[],
        'meta': {'total': 0},
      };
    } else {
      final data = options.data is Map
          ? jsonDecode(jsonEncode(options.data)) as Map<String, dynamic>
          : <String, dynamic>{};
      lastBody = data;
      lastPath = path;
      body = {
        'success': true,
        'data': {
          'id': 'u7',
          'lot_id': 'l62',
          'maker': 'YAMAHA',
          'model': 'U3H',
          'place': 'in_stock',
          'sale': 'available',
          'condition': data['condition'],
          'location_id': data['location_id'] ?? 'loc-main',
          'received_at': '2026-11-01',
        },
      };
    }
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
