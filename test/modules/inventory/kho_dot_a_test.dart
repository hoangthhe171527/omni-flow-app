import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/modules/inventory/application/inventory_providers.dart';
import 'package:omni_app/modules/inventory/domain/inventory_models.dart';
import 'package:omni_app/modules/inventory/domain/inventory_permissions.dart';
import 'package:omni_app/modules/inventory/domain/receive.dart';
import 'package:omni_app/modules/inventory/presentation/lot_detail_page.dart';
import 'package:omni_app/modules/inventory/presentation/receive_page.dart';
import 'package:omni_app/modules/inventory/presentation/stock_page.dart';
import 'package:omni_app/modules/inventory/presentation/suppliers_page.dart';
import 'package:omni_app/modules/inventory/presentation/widgets/unit_extras.dart';
import 'package:omni_app/modules/inventory/presentation/widgets/unit_sheet.dart';
import 'package:omni_app/security/permissions/access_policy.dart';
import 'package:omni_app/security/session/session_controller.dart';

import 'fake_inventory_api.dart';

/// Kho chuẩn hóa Đợt A trên app (bản xem trước `kho-dot-a-app-body.html`):
/// phần mới chỉ hiện khi API có capability tương ứng; mỗi lần ghi gửi đúng
/// khoá và màn đọc lại thấy giá trị mới.
void main() {
  final today = DateTime(2026, 11, 10);

  const allOld = InventoryPerms(
    read: true,
    write: true,
    reserve: true,
    cost: true,
    pay: true,
    sell: true,
  );
  const allNew = InventoryPerms(
    read: true,
    write: true,
    reserve: true,
    cost: true,
    pay: true,
    sell: true,
    locations: true,
    suppliers: true,
    editSuppliers: true,
    claims: true,
    photos: true,
  );

  const locations = [
    StockLocation(id: 'main', name: 'Kho chính', isDefault: true, unitCount: 3),
    StockLocation(id: 'p1', name: 'Đại lý Sao Mai', kind: 'partner'),
  ];

  List<InventoryUnit> seed() => const [
    InventoryUnit(
      id: 'u1',
      lotId: 'l61',
      lotCode: 'Ep 61',
      maker: 'YAMAHA',
      model: 'U3H',
      serial: '2204585',
      listPrice: 32500000,
      place: UnitPlace.inStock,
      locationId: 'main',
      locationName: 'Kho chính',
      defectTags: [],
      photoCount: 1,
      coverUrl: 'https://x.test/c.jpg',
    ),
    InventoryUnit(
      id: 'u2',
      lotId: 'l57',
      lotCode: 'Ep 57',
      maker: 'KAWAI',
      model: 'BL71',
      serial: 'K909666',
      listPrice: 34000000,
      place: UnitPlace.inStock,
      locationId: 'p1',
      locationName: 'Đại lý Sao Mai',
      defectTags: [],
    ),
    InventoryUnit(
      id: 'u3',
      lotId: 'l11',
      lotCode: 'Hmn11',
      maker: 'KORG',
      model: 'LP380',
      serial: '3444944',
      listPrice: 7000000,
      place: UnitPlace.inStock,
      locationId: 'main',
      locationName: 'Kho chính',
      defectTags: ['Thiếu chân'],
    ),
  ];

  void phone(WidgetTester t) {
    t.view.physicalSize = const Size(390, 1600);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
  }

  Widget app(
    FakeInventoryApi api,
    InventoryPerms perms,
    Widget home, {
    List<Override> extra = const [],
  }) => ProviderScope(
    overrides: [
      inventoryApiProvider.overrideWithValue(api),
      inventoryPermsProvider.overrideWithValue(perms),
      inventoryTodayProvider.overrideWithValue(today),
      workshopPlansProvider.overrideWith((ref) async => const []),
      accessProvider.overrideWithValue(AccessPolicy(const {})),
      ...extra,
    ],
    child: MaterialApp(home: home),
  );

  group('Tồn kho', () {
    testWidgets('nhiều vị trí: lọc vị trí, chọn cây rồi chuyển, ảnh nhỏ', (
      t,
    ) async {
      phone(t);
      final api = FakeInventoryApi(
        units: seed(),
        multiLocation: true,
        locations: locations,
      );
      await t.pumpWidget(app(api, allNew, const StockPage()));
      await t.pumpAndSettle();

      expect(find.byType(InvUnitThumb), findsNWidgets(3));
      // Cây ở nơi khác vị trí mặc định ghi tên nơi đó ở dòng phụ.
      expect(find.text('Đại lý Sao Mai'), findsOneWidget);

      // Vị trí nằm trong sheet lọc (nút lọc cạnh ô tìm).
      await t.tap(find.byKey(const ValueKey('inv-filter')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('inv-filter-location')));
      await t.pumpAndSettle();
      await t.tap(find.text('Đại lý Sao Mai').last);
      await t.pumpAndSettle();
      expect(api.listCalls.last['location_id'], 'p1');
      expect(find.text('KAWAI BL71'), findsOneWidget);
      expect(find.text('YAMAHA U3H'), findsNothing);

      // Bỏ lọc, chọn hai cây ở Kho chính, chuyển sang Sao Mai.
      // Vị trí nằm trong sheet lọc (nút lọc cạnh ô tìm).
      await t.tap(find.byKey(const ValueKey('inv-filter')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('inv-filter-location')));
      await t.pumpAndSettle();
      await t.tap(find.text('Mọi vị trí'));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('inv-stock-multi')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('inv-unit-u1')));
      await t.tap(find.byKey(const ValueKey('inv-unit-u3')));
      await t.pumpAndSettle();
      expect(find.text('Chuyển vị trí · 2 cây'), findsOneWidget);
      // Có cả Bán: chuyển vị trí là nút phụ trong khay kính đáy.
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('inv-stock-dock')),
          matching: find.text('Chuyển vị trí · 2 cây'),
        ),
        findsOneWidget,
      );
      await t.tap(find.byKey(const ValueKey('inv-stock-move-picked')));
      await t.pumpAndSettle();
      expect(find.text('Chuyển 2 cây đến'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('inv-move-to-p1')));
      await t.pumpAndSettle();

      expect(api.moves.single, {
        'unit_ids': ['u1', 'u3'],
        'to_location_id': 'p1',
      });
      expect(find.text('Đã chuyển 2 cây đến Đại lý Sao Mai.'), findsOneWidget);
      // Đọc lại: danh sách tải lại, cả ba cây giờ ở Sao Mai.
      expect(find.text('Đại lý Sao Mai'), findsNWidgets(3));
    });

    testWidgets(
      'một vị trí / API cũ: không lọc vị trí, không chuyển, không ảnh',
      (t) async {
        phone(t);
        final api = FakeInventoryApi(units: seed(), locations: locations);
        await t.pumpWidget(app(api, allNew, const StockPage()));
        await t.pumpAndSettle();
        await t.tap(find.byKey(const ValueKey('inv-filter')));
        await t.pumpAndSettle();
        expect(find.byKey(const ValueKey('inv-filter-location')), findsNothing);
        // Đóng sheet lọc bằng cách chạm ra ngoài.
        await t.tapAt(const Offset(20, 20));
        await t.pumpAndSettle();
        expect(find.textContaining('Đại lý Sao Mai'), findsNothing);

        await t.pumpWidget(
          app(FakeInventoryApi(units: seed()), allOld, const StockPage()),
        );
        await t.pumpAndSettle();
        expect(find.byType(InvUnitThumb), findsNothing);
        await t.tap(find.byKey(const ValueKey('inv-stock-multi')));
        await t.pumpAndSettle();
        await t.tap(find.byKey(const ValueKey('inv-unit-u1')));
        await t.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('inv-stock-move-picked')),
          findsNothing,
        );
      },
    );
  });

  group('Chi tiết cây', () {
    Future<FakeInventoryApi> pumpSheet(
      WidgetTester t,
      InventoryPerms perms, {
      InventoryUnit? unit,
      List<Override> extra = const [],
    }) async {
      phone(t);
      final u = unit ?? seed().first;
      final api = FakeInventoryApi(
        units: [u, ...seed().skip(1)],
        multiLocation: true,
        locations: locations,
        tags: const ['Thiếu chân', 'Sụt phím', 'Xước vỏ'],
        photos: const {
          'u1': [
            UnitPhoto(id: 'p1', url: 'https://x.test/1.jpg', isCover: true),
            UnitPhoto(
              id: 'task:t1',
              url: 'https://x.test/t.jpg',
              fromTask: true,
              taskTitle: 'Lên dây',
            ),
          ],
        },
        ledger: const {
          'u1': [
            LedgerRow(
              id: 'm1',
              isWork: false,
              kind: 'receive',
              at: '2026-10-12',
              toName: 'Kho chính',
            ),
          ],
        },
      );
      await t.pumpWidget(
        app(
          api,
          perms,
          Scaffold(
            body: UnitSheet(unit: u, onChanged: (_) {}),
          ),
          extra: extra,
        ),
      );
      await t.pumpAndSettle();
      return api;
    }

    testWidgets('đủ capability: ảnh, nhãn lỗi, vị trí, thẻ kho', (t) async {
      final api = await pumpSheet(t, allNew);

      expect(find.byKey(const ValueKey('inv-unit-photos')), findsOneWidget);
      expect(find.text('1/20'), findsOneWidget);
      expect(find.byKey(const ValueKey('inv-photo-add')), findsOneWidget);
      expect(find.byKey(const ValueKey('inv-unit-location')), findsOneWidget);
      expect(find.text('Nhận vào Kho chính'), findsOneWidget);
      expect(find.text('12/10/2026'), findsOneWidget);

      await t.tap(find.byKey(const ValueKey('inv-defect-Sụt phím')));
      await t.pumpAndSettle();
      expect(api.updates.last.$2, {
        'defect_tags': ['Sụt phím'],
      });
      expect(find.text('Đã lưu nhãn lỗi.'), findsOneWidget);
      // Đọc lại: cây sau khi lưu có nhãn đang chọn.
      expect(api.units.first.defectTags, ['Sụt phím']);
    });

    testWidgets('thêm ảnh: chọn nhiều ảnh, tải lên files', (t) async {
      final api = await pumpSheet(
        t,
        allNew,
        extra: [
          unitPhotoPickerProvider.overrideWithValue(
            ({required camera, required max}) async => [
              (path: '/tmp/a.jpg', name: 'a.jpg'),
              (path: '/tmp/b.jpg', name: 'b.jpg'),
            ],
          ),
        ],
      );
      await t.tap(find.byKey(const ValueKey('inv-photo-add')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('inv-photo-gallery')));
      await t.pumpAndSettle();
      expect(api.uploads.single.$2.map((f) => f.name), ['a.jpg', 'b.jpg']);
      expect(find.text('Đã thêm 2 ảnh.'), findsOneWidget);
      expect(find.text('3/20'), findsOneWidget);
    });

    testWidgets('ảnh thợ chụp chỉ xem; ảnh kho xoá được', (t) async {
      final api = await pumpSheet(t, allNew);
      await t.tap(find.byKey(const ValueKey('inv-photo-task:t1')));
      await t.pumpAndSettle();
      expect(find.text('Thợ chụp · Lên dây'), findsOneWidget);
      expect(find.byKey(const ValueKey('inv-photo-delete')), findsNothing);
      await t.tap(find.byTooltip('Đóng'));
      await t.pumpAndSettle();

      await t.tap(find.byKey(const ValueKey('inv-photo-p1')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('inv-photo-delete')));
      await t.pumpAndSettle();
      await t.tap(find.text('Xoá').last);
      await t.pumpAndSettle();
      expect(api.deletedPhotos.single, ('u1', 'p1'));
      expect(find.text('0/20'), findsOneWidget);
    });

    testWidgets(
      'API cũ: không ảnh, không nhãn lỗi, không vị trí, không thẻ kho',
      (t) async {
        await pumpSheet(t, allOld);
        expect(find.byKey(const ValueKey('inv-unit-photos')), findsNothing);
        expect(find.byKey(const ValueKey('inv-unit-defects')), findsNothing);
        expect(find.byKey(const ValueKey('inv-unit-location')), findsNothing);
        expect(find.byKey(const ValueKey('inv-unit-ledger')), findsNothing);
        expect(find.byKey(const ValueKey('inv-unit-note')), findsNothing);
      },
    );

    testWidgets('cây đã vào đơn còn trong kho: Đã giao gửi place delivered', (
      t,
    ) async {
      final api = await pumpSheet(
        t,
        allNew,
        unit: const InventoryUnit(
          id: 'u1',
          lotId: 'l61',
          maker: 'YAMAHA',
          model: 'U3H',
          place: UnitPlace.inStock,
          sale: UnitSale.sold,
          customerName: 'Anh Phúc',
        ),
      );
      await t.tap(find.byKey(const ValueKey('inv-unit-deliver')));
      await t.pumpAndSettle();
      expect(api.updates.last.$2, {'place': 'delivered'});
    });
  });

  group('Nhận hàng', () {
    const lot = Lot(id: 'l62', code: 'Ep 62', units: 3);
    List<InventoryUnit> lotUnits() => const [
      InventoryUnit(
        id: 'a',
        lotId: 'l62',
        lineNo: 1,
        maker: 'YAMAHA',
        model: 'U3H',
        serial: '2531940',
      ),
      InventoryUnit(
        id: 'b',
        lotId: 'l62',
        lineNo: 2,
        maker: 'KAWAI',
        model: 'BL71',
        serial: 'K1',
      ),
      InventoryUnit(
        id: 'c',
        lotId: 'l62',
        lineNo: 3,
        maker: 'ROLAND',
        model: 'HP603',
        serial: 'Z7',
      ),
    ];

    testWidgets(
      'cây thiếu mặc định trừ tiền, đổi cách xử lý, nhận vào vị trí',
      (t) async {
        phone(t);
        final api = FakeInventoryApi(
          units: lotUnits(),
          lots: const [lot],
          multiLocation: true,
          locations: locations,
        );
        await t.pumpWidget(app(api, allNew, const ReceivePage(lotId: 'l62')));
        await t.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('inv-receive-location')),
          findsOneWidget,
        );
        await t.tap(find.byKey(const ValueKey('inv-receive-location')));
        await t.pumpAndSettle();
        await t.tap(find.text('Đại lý Sao Mai'));
        await t.pumpAndSettle();

        await t.tap(find.byKey(const ValueKey('inv-recv-missing-b')));
        await t.pumpAndSettle();
        expect(find.text('Nhà cung cấp trừ tiền'), findsOneWidget);
        await t.tap(find.byKey(const ValueKey('inv-recv-claim-b')));
        await t.pumpAndSettle();
        // Cây thiếu luôn có khoản đòi: không có "Chưa quyết".
        expect(find.text('Chưa quyết'), findsNothing);
        await t.tap(find.text('Bù ở lô sau'));
        await t.pumpAndSettle();

        // Cây lỗi + trừ tiền chưa nhập ¥: chặn trước, không gửi.
        await t.tap(find.byKey(const ValueKey('inv-recv-defect-c')));
        await t.pumpAndSettle();
        expect(find.text('Chưa quyết'), findsOneWidget);
        await t.tap(find.byKey(const ValueKey('inv-recv-claim-c')));
        await t.pumpAndSettle();
        await t.tap(find.text('Nhà cung cấp trừ tiền'));
        await t.pumpAndSettle();
        expect(find.byKey(const ValueKey('inv-recv-amount-c')), findsOneWidget);
        await t.tap(find.byKey(const ValueKey('inv-receive-finish')));
        await t.pumpAndSettle();
        expect(find.text('Nhập số ¥ được trừ cho cây lỗi.'), findsOneWidget);
        expect(api.receives, isEmpty);
        // Thông báo nổi che nút dưới: chờ nó tắt.
        await t.pump(const Duration(seconds: 5));
        await t.pumpAndSettle();

        // Bỏ trừ tiền: mình chịu.
        await t.tap(find.byKey(const ValueKey('inv-recv-claim-c')));
        await t.pumpAndSettle();
        await t.tap(find.text('Mình chịu'));
        await t.pumpAndSettle();
        await t.tap(find.byKey(const ValueKey('inv-receive-finish')));
        await t.pumpAndSettle();
        expect(api.receives.single['location_id'], 'p1');
        expect(api.receives.single['results'], [
          {'unit_id': 'b', 'result': 'missing', 'resolution': 'replace_later'},
          {'unit_id': 'c', 'result': 'defect', 'resolution': 'absorb'},
        ]);
      },
    );

    testWidgets('API cũ: không cách xử lý, không vị trí, không khoá lạ', (
      t,
    ) async {
      phone(t);
      final api = FakeInventoryApi(units: lotUnits(), lots: const [lot]);
      await t.pumpWidget(app(api, allOld, const ReceivePage(lotId: 'l62')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('inv-recv-missing-b')));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('inv-recv-claim-b')), findsNothing);
      expect(find.byKey(const ValueKey('inv-receive-location')), findsNothing);
      await t.tap(find.byKey(const ValueKey('inv-receive-finish')));
      await t.pumpAndSettle();
      expect(api.receives.single['location_id'], isNull);
      expect(api.receives.single['results'], [
        {'unit_id': 'b', 'result': 'missing'},
      ]);
    });
  });

  group('Chi tiết lô', () {
    const lot = Lot(
      id: 'l62',
      code: 'Ep 62',
      supplierId: 's1',
      supplierName: 'Epco',
      status: LotStatus.received,
      units: 2,
      expectedJpy: 1850000,
      debtBaseJpy: 1700000,
      prepaidJpy: 50000,
      claims: [
        LotClaim(
          id: 'c1',
          lotId: 'l62',
          unitId: 'b',
          resolution: ClaimResolution.deduct,
          debtCutJpy: 150000,
        ),
      ],
    );
    const units = [
      InventoryUnit(
        id: 'a',
        lotId: 'l62',
        lineNo: 1,
        maker: 'YAMAHA',
        model: 'U3H',
      ),
      InventoryUnit(
        id: 'b',
        lotId: 'l62',
        lineNo: 2,
        maker: 'KAWAI',
        model: 'BL71',
        serial: 'K1',
      ),
    ];

    testWidgets('nợ theo ¥, khoản đòi: đổi cách xử lý rồi đọc lại', (t) async {
      phone(t);
      final api = FakeInventoryApi(units: units, lots: const [lot]);
      await t.pumpWidget(app(api, allNew, const LotDetailPage(lotId: 'l62')));
      await t.pumpAndSettle();

      expect(find.text('1.850.000 ¥'), findsOneWidget);
      expect(find.text('1.700.000 ¥'), findsOneWidget);
      expect(find.text('50.000 ¥'), findsOneWidget);
      expect(find.text('#2 KAWAI BL71'), findsOneWidget);
      expect(find.textContaining('Nhà cung cấp trừ tiền'), findsOneWidget);
      expect(find.textContaining('Thiếu · K1 · trừ 150.000 ¥'), findsOneWidget);

      await t.tap(find.byKey(const ValueKey('inv-claim-row-c1')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('inv-claim-replace_later')));
      await t.tap(find.byKey(const ValueKey('inv-claim-settled')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('inv-claim-save')));
      await t.pumpAndSettle();

      expect(api.claimUpdates.single.$1, 'c1');
      expect(api.claimUpdates.single.$2, {
        'resolution': 'replace_later',
        'status': 'settled',
      });
      expect(find.text('Đã cập nhật khoản đòi.'), findsOneWidget);
      // Đọc lại: lô tải lại, dòng đổi theo.
      expect(find.textContaining('Bù ở lô sau'), findsOneWidget);
      expect(find.text('Xong'), findsOneWidget);
    });

    testWidgets('API cũ: không nhóm ¥, không khoản đòi', (t) async {
      phone(t);
      final api = FakeInventoryApi(units: units, lots: const [lot]);
      await t.pumpWidget(app(api, allOld, const LotDetailPage(lotId: 'l62')));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('inv-lot-yen')), findsNothing);
      expect(find.byKey(const ValueKey('inv-lot-claims')), findsNothing);
    });
  });

  group('Nhà cung cấp', () {
    const epco = SupplierDetail(
      id: 's1',
      code: 'Epco',
      name: 'Epco',
      phone: '+81 53 000 0101',
      bankAccounts: [BankAccount(bank: 'Shizuoka Bank', number: '0123456')],
      debtJpy: 6900000,
      overdueJpy: 1700000,
      openLots: 4,
      lots: [
        SupplierLot(id: 'l62', code: 'Ep 62', dueJpy: 1700000, overdue: true),
      ],
    );
    const dn = SupplierDetail(
      id: 's5',
      code: 'ĐN',
      name: 'Đồng Nai',
      foreign: false,
      currency: 'VND',
      debtJpy: 0,
      overdueJpy: 0,
      openLots: 0,
    );

    testWidgets('danh sách: tổng nợ, quá hạn, nợ từng nhà cung cấp', (t) async {
      phone(t);
      final api = FakeInventoryApi(supplierDetails: const [epco, dn]);
      await t.pumpWidget(app(api, allNew, const SuppliersPage()));
      await t.pumpAndSettle();

      expect(find.byKey(const ValueKey('inv-sup-summary')), findsOneWidget);
      expect(find.text('Nợ quá hạn'), findsOneWidget);
      expect(find.text('6.900.000 ¥'), findsNWidgets(2));
      expect(find.text('quá hạn 1.700.000 ¥'), findsOneWidget);
      expect(find.text('Nước ngoài · 4 lô còn nợ'), findsOneWidget);
      expect(find.text('Đồng Nai · Trong nước'), findsOneWidget);
    });

    testWidgets('không quyền thanh toán lô: không số nợ', (t) async {
      phone(t);
      const noDebt = SupplierDetail(id: 's1', code: 'Epco', name: 'Epco');
      final api = FakeInventoryApi(supplierDetails: const [noDebt]);
      await t.pumpWidget(
        app(
          api,
          const InventoryPerms(read: true, suppliers: true),
          const SuppliersPage(),
        ),
      );
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('inv-sup-summary')), findsNothing);
      expect(find.textContaining('¥'), findsNothing);
    });

    testWidgets('API thiếu capability: không gọi, không danh sách', (t) async {
      phone(t);
      final api = FakeInventoryApi(supplierDetails: const [epco]);
      await t.pumpWidget(app(api, allOld, const SuppliersPage()));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('inv-sup-list')), findsNothing);
    });

    testWidgets('chi tiết: công nợ, lô quá hạn; sửa hồ sơ rồi đọc lại', (
      t,
    ) async {
      phone(t);
      final api = FakeInventoryApi(supplierDetails: const [epco]);
      await t.pumpWidget(
        app(api, allNew, const SupplierDetailPage(supplierId: 's1')),
      );
      await t.pumpAndSettle();
      expect(find.text('Còn nợ'), findsOneWidget);
      expect(find.text('Ep 62'), findsOneWidget);
      expect(find.text('Quá hạn'), findsNWidgets(2));
      expect(find.text('0123456'), findsOneWidget);

      await t.tap(find.byKey(const ValueKey('inv-sup-edit')));
      await t.pumpAndSettle();
      await t.enterText(
        find.byKey(const ValueKey('inv-sup-name')),
        'Epco Hamamatsu',
      );
      await t.tap(find.byKey(const ValueKey('inv-sup-term')));
      await t.pumpAndSettle();
      await t.tap(find.text('Trả sau số ngày'));
      await t.pumpAndSettle();
      await t.enterText(find.byKey(const ValueKey('inv-sup-days')), '15');
      await t.tap(find.byKey(const ValueKey('inv-sup-save')));
      await t.pumpAndSettle();

      final body = api.supplierUpdates.single.$2;
      expect(body['name'], 'Epco Hamamatsu');
      expect(body['payment_term'], {'kind': 'days', 'days': 15});
      expect(body['bank_accounts'], [
        {'bank': 'Shizuoka Bank', 'number': '0123456', 'holder': null},
      ]);
      expect(find.text('Đã lưu hồ sơ.'), findsOneWidget);
      // Đọc lại từ màn: hồ sơ mới.
      expect(find.text('Epco Hamamatsu'), findsOneWidget);
      expect(find.text('Trả sau 15 ngày'), findsOneWidget);
    });

    testWidgets('không quyền sửa: không nút sửa', (t) async {
      phone(t);
      final api = FakeInventoryApi(supplierDetails: const [epco]);
      await t.pumpWidget(
        app(
          api,
          const InventoryPerms(read: true, suppliers: true, pay: true),
          const SupplierDetailPage(supplierId: 's1'),
        ),
      );
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('inv-sup-edit')), findsNothing);
    });
  });

  group('Quyền & capability', () {
    test('phần Đợt A theo capability riêng; sửa nhà cung cấp cần quyền', () {
      final policy = AccessPolicy({'inventory.read', 'inventory.suppliers'});
      final none = InventoryPerms.from(capable: true, policy: policy);
      expect([
        none.locations,
        none.suppliers,
        none.claims,
        none.photos,
      ], everyElement(isFalse));
      final caps = {
        'inventory.locations',
        'inventory.suppliers',
        'inventory.claims',
        'inventory.photos',
      };
      final p = InventoryPerms.from(
        capable: true,
        policy: policy,
        supports: caps.contains,
      );
      expect([
        p.locations,
        p.suppliers,
        p.claims,
        p.photos,
      ], everyElement(isTrue));
      expect(p.editSuppliers, isTrue);
      final reader = InventoryPerms.from(
        capable: true,
        policy: AccessPolicy({'inventory.read'}),
        supports: caps.contains,
      );
      expect(reader.suppliers, isTrue);
      expect(reader.editSuppliers, isFalse);
    });

    test('dòng nhận hàng: API cũ không gửi cách xử lý', () {
      const units = [InventoryUnit(id: 'a', lotId: 'l')];
      final lines = buildReceiveLines(
        units,
        result: (_) => ReceiveResult.defect,
        serials: const {},
        claims: const {},
        withClaims: false,
      );
      expect(lines.single.toPayload(), {'unit_id': 'a', 'result': 'defect'});
      expect(missingDeductAmount(lines), isFalse);
    });
  });
}
