// Ảnh chụp màn THẬT các màn Kho sau rà soát 12/11 (artifact ra-soat-app-mobile)
// — soát bằng mắt, không phải bài kiểm hồi quy (tag `screenshots`). Chạy tay:
//
//   flutter test test/_screenshots/ra_soat_kho_golden_test.dart \
//     --run-skipped --update-goldens
@Tags(['screenshots'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:omni_app/core/nav/shell_bar_inset.dart';
import 'package:omni_app/core/nav/shell_tab_routes.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/modules/inventory/application/inventory_providers.dart';
import 'package:omni_app/modules/inventory/domain/inventory_models.dart';
import 'package:omni_app/modules/inventory/domain/inventory_permissions.dart';
import 'package:omni_app/modules/inventory/presentation/lot_detail_page.dart';
import 'package:omni_app/modules/inventory/presentation/lots_page.dart';
import 'package:omni_app/modules/inventory/presentation/stock_page.dart';
import 'package:omni_app/modules/settings/application/appearance_providers.dart';

import '../modules/inventory/fake_inventory_api.dart';
import '../support/fixed_background.dart';

Future<void> _loadAppFont() async {
  final loader = FontLoader('Be Vietnam Pro');
  for (final f in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold']) {
    final bytes = File('assets/fonts/BeVietnamPro-$f.ttf').readAsBytesSync();
    loader.addFont(Future.value(ByteData.view(bytes.buffer)));
  }
  await loader.load();
  final icons = File(
    'D:/_tools/flutter/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
  );
  if (icons.existsSync()) {
    final iconLoader = FontLoader('MaterialIcons');
    final bytes = icons.readAsBytesSync();
    iconLoader.addFont(Future.value(ByteData.view(bytes.buffer)));
    await iconLoader.load();
  }
}

const _all = InventoryPerms(
  read: true,
  write: true,
  reserve: true,
  cost: true,
  pay: true,
  sell: true,
);

final _today = DateTime(2026, 11, 12);

List<InventoryUnit> _units() => const [
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
    maker: 'YAMAHA',
    model: 'U1H',
    serial: '4410023',
    category: 'Piano Upright cũ',
    listPrice: 28900000,
    costVnd: 19046036,
    place: UnitPlace.inStock,
    receivedAt: '2026-05-02',
  ),
  InventoryUnit(
    id: 's3',
    lotId: 'l62',
    lotCode: 'Hmn 12',
    maker: 'KAWAI',
    model: 'CA48A',
    serial: 'K880102',
    category: 'Piano điện cũ',
    listPrice: 17500000,
    costVnd: 11131571,
    condition: UnitCondition.defective,
    place: UnitPlace.inStock,
    receivedAt: '2026-10-20',
  ),
  InventoryUnit(
    id: 's4',
    lotId: 'l62',
    lotCode: 'Hmn 12',
    maker: 'ROLAND',
    model: 'HP704',
    serial: 'R2230981',
    category: 'Piano điện cũ',
    listPrice: 21000000,
    costVnd: 14000000,
    place: UnitPlace.inStock,
    receivedAt: '2026-10-20',
  ),
];

const _lots = [
  Lot(
    id: 'l64',
    code: 'Ep 64',
    supplierName: 'Cty TNHH Gỗ Việt',
    status: LotStatus.inTransit,
    units: 0,
    plannedCount: 24,
    eta: '2026-11-18',
  ),
  Lot(
    id: 'l63',
    code: 'Hmn 13',
    supplierName: 'Hamano Gakki',
    status: LotStatus.ordered,
    plannedCount: 40,
    eta: '2026-11-22',
  ),
  Lot(
    id: 'l61',
    code: 'Ep 61',
    supplierName: 'Cty TNHH Gỗ Việt',
    status: LotStatus.received,
    units: 31,
    inStock: 12,
    receivedAt: '2026-08-17',
  ),
];

/// Khung giống app thật: thanh tab kính 66 + vùng an toàn 34 (iPhone) vẽ đè
/// ở đáy, và khung ứng dụng Kho mở sẵn các màn ở thanh dưới.
Widget _framed(Widget page, {bool appShell = true}) => Builder(
  builder: (context) {
    final body = ShellBarInset(height: ShellBarInset.barHeight, child: page);
    return Stack(
      children: [
        Positioned.fill(
          child: appShell
              ? ShellTabRoutes(
                  routes: const {
                    'inventory.lots',
                    'inventory.stock',
                    'inventory.suppliers',
                    'inventory.reservations',
                    'inventory.catalog',
                    'inventory.delivered',
                    'inventory.counts',
                  },
                  child: body,
                )
              : body,
        ),
        // Thanh tab giả (chỉ để soát chỗ che), đúng chỗ thanh thật.
        Positioned(
          left: 12,
          right: 12,
          bottom: 34,
          height: ShellBarInset.pillHeight,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(33),
                border: Border.all(color: const Color(0x22000000)),
              ),
              child: const Center(
                child: Text(
                  'Sắp về   Tồn kho   NCC   Đang giữ   Thêm',
                  style: TextStyle(fontSize: 11),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  },
);

void main() {
  setUpAll(() async {
    await _loadAppFont();
    await initializeDateFormatting('vi_VN');
  });

  Future<void> shoot(
    WidgetTester t,
    Widget home,
    String name, {
    Future<void> Function()? act,
  }) async {
    t.view.physicalSize = const Size(780, 1688);
    t.view.devicePixelRatio = 2.0;
    t.view.viewPadding = const FakeViewPadding(top: 94, bottom: 68);
    t.view.padding = const FakeViewPadding(top: 94, bottom: 68);
    addTearDown(t.view.reset);
    final api = FakeInventoryApi(units: _units(), lots: _lots);
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          backgroundProvider.overrideWith(() => FixedBackground(null)),
          inventoryApiProvider.overrideWithValue(api),
          inventoryPermsProvider.overrideWithValue(_all),
          inventoryTodayProvider.overrideWithValue(_today),
          workshopPlansProvider.overrideWith((ref) async => const []),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: OmniTheme.light(TargetPlatform.iOS),
          locale: const Locale('vi'),
          home: home,
        ),
      ),
    );
    await t.pumpAndSettle();
    if (act != null) await act();
    await t.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/rskho-$name.png'),
    );
  }

  testWidgets(
    'ton kho',
    (t) => shoot(t, _framed(const StockPage()), 'ton-kho'),
  );

  testWidgets(
    'ton kho giao dien cu',
    (t) => shoot(t, _framed(const StockPage(), appShell: false), 'ton-kho-cu'),
  );

  testWidgets(
    'ton kho chon nhieu',
    (t) => shoot(
      t,
      _framed(const StockPage()),
      'ton-kho-chon',
      act: () async {
        await t.tap(find.byKey(const ValueKey('inv-stock-multi')));
        await t.pumpAndSettle();
        await t.tap(find.text('YAMAHA U3H'));
        await t.pumpAndSettle();
        await t.tap(find.text('YAMAHA U1H'));
      },
    ),
  );

  testWidgets('sap ve', (t) => shoot(t, _framed(const LotsPage()), 'sap-ve'));

  testWidgets(
    'chi tiet lo',
    (t) => shoot(t, const LotDetailPage(lotId: 'l64'), 'chi-tiet-lo'),
  );
}
