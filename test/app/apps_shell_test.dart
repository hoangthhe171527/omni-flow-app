import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/app/apps/app_manifest.dart';
import 'package:omni_app/app/apps/app_shell_layout.dart';
import 'package:omni_app/app/router/app_router.dart';
import 'package:omni_app/core/module/module_registry.dart';
import 'package:omni_app/core/module/module_route.dart';
import 'package:omni_app/core/module/nav_destination.dart';
import 'package:omni_app/core/module/omni_module.dart';
import 'package:omni_app/design/components/components.dart';
import 'package:omni_app/security/guard/access_requirement.dart';
import 'package:omni_app/security/permissions/access_policy.dart';
import 'package:omni_app/security/session/session.dart';
import 'package:omni_app/security/session/session_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Khung ứng dụng (cờ `app_shell`): màn Chọn ứng dụng sau khi chọn công ty,
/// thanh dưới theo ứng dụng. Cờ tắt hoặc API cũ thì app y như trước.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  const allCaps = {
    appsManifestCapability,
    'inventory',
    'inventory.suppliers',
    'inventory.reservations',
    'inventory.products',
    'inventory.returns',
    'inventory.counts',
  };
  const admin = {'dashboard.read', 'tasks.read', 'inventory.read'};

  Session session({
    Set<String> permissions = admin,
    bool shell = true,
    Set<String> caps = allCaps,
  }) => Session(
    status: SessionStatus.authenticated,
    tenant: const SessionTenant(id: 't1', name: 'Công ty Sao Mai'),
    policy: AccessPolicy(permissions),
    features: {appShellFeature: shell},
    apiCapabilities: caps,
  );

  ProviderContainer containerFor(Session s, {AppManifest? manifest}) =>
      ProviderContainer(
        overrides: [
          modulesProvider.overrideWithValue(const [_FakeModule()]),
          sessionProvider.overrideWithValue(s),
          appManifestProvider.overrideWith(
            (ref) async =>
                sessionWantsAppShell(s) ? manifest ?? _manifest : null,
          ),
        ],
      );

  /// SplashPage quay spinner không ngừng — bơm khoảng cố định thay vì settle.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
  }

  Future<String> boot(WidgetTester tester, ProviderContainer c) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await c.read(appManifestProvider.future);
    final router = c.read(routerProvider);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp.router(
          routerConfig: router,
          debugShowCheckedModeBanner: false,
        ),
      ),
    );
    await settle(tester);
    return router.routerDelegate.currentConfiguration.uri.toString();
  }

  group('bố cục từ bản khai báo', () {
    test('Kho: 4 mục đầu theo bản khai báo, còn lại vào Thêm', () {
      final c = containerFor(session());
      addTearDown(c.dispose);
      return c.read(appManifestProvider.future).then((_) {
        final layout = c.read(appShellLayoutProvider)!;
        expect(layout.entries.map((a) => a.key), ['home', 'stock']);
        final stock = layout.byKey('stock')!;
        expect(stock.tabs.map((i) => i.key), [
          'inventory_lots',
          'inventory_stock',
          'inventory_suppliers',
          'inventory_reservations',
        ]);
        expect(stock.more.map((i) => i.key), [
          'inventory_catalog',
          'inventory_delivered',
          'inventory_counts',
        ]);
        expect(stock.hasMore, isTrue);
        // Bán hàng chỉ có "Tồn kho" (lối vào thứ hai) — không đủ để hiện ô.
        expect(layout.byKey('sales'), isNull);
      });
    });

    test('API thiếu khả năng của màn thì mục đó không vẽ', () async {
      final c = containerFor(
        session(caps: {appsManifestCapability, 'inventory'}),
      );
      addTearDown(c.dispose);
      await c.read(appManifestProvider.future);
      final stock = c.read(appShellLayoutProvider)!.byKey('stock')!;
      expect(stock.all.map((i) => i.key), [
        'inventory_lots',
        'inventory_stock',
      ]);
      expect(stock.hasMore, isFalse);
    });

    test('ứng dụng công ty tắt thì không có ô', () async {
      final c = containerFor(
        session(),
        manifest: AppManifest.fromJson({
          ..._manifestJson,
          'apps': [
            for (final a in _manifestJson['apps'] as List)
              {...a as Map<String, dynamic>, 'enabled': a['key'] != 'stock'},
          ],
        }),
      );
      addTearDown(c.dispose);
      await c.read(appManifestProvider.future);
      expect(c.read(appShellLayoutProvider)!.entries.map((a) => a.key), [
        'home',
      ]);
    });

    test(
      'vai không cho dùng Bàn làm việc (home_enabled: false) thì không có ô đó',
      () async {
        final c = containerFor(
          session(),
          manifest: AppManifest.fromJson({
            ..._manifestJson,
            'home_enabled': false,
          }),
        );
        addTearDown(c.dispose);
        await c.read(appManifestProvider.future);
        expect(c.read(appShellLayoutProvider)!.entries.map((a) => a.key), [
          'stock',
        ]);
      },
    );

    test('vào thẳng: cờ bật thì landing là /apps, tắt hoặc API cũ như cũ', () {
      String landing(Session s) {
        final c = containerFor(s);
        addTearDown(c.dispose);
        return landingPath(c.read(Provider<Ref>((ref) => ref)));
      }

      expect(landing(session()), '/apps');
      expect(landing(session(shell: false)), '/home');
      expect(landing(session(caps: {'inventory'})), '/home');
    });
  });

  group('luồng thật qua router', () {
    testWidgets('nhiều ô: ra màn Chọn ứng dụng; vào Kho thấy 4 mục + Thêm', (
      tester,
    ) async {
      final c = containerFor(session());
      addTearDown(c.dispose);

      expect(await boot(tester, c), '/apps');
      expect(find.text('Bàn làm việc'), findsOneWidget);
      expect(find.text('Kho'), findsOneWidget);
      expect(find.text('Công ty Sao Mai'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('app-tile-stock')));
      await settle(tester);

      expect(find.text('page Hàng sắp về'), findsOneWidget);
      for (final label in [
        // Nhãn ngắn trên thanh tab (rà soát 12/11) — tên đầy đủ ở tiêu đề.
        'Sắp về',
        'Tồn kho',
        'NCC',
        'Đang giữ',
        'Thêm',
      ]) {
        expect(find.text(label), findsWidgets, reason: label);
      }
      // Thanh dưới tự chọn cũ ("Tất cả") không dùng khi khung bật.
      expect(find.text('Tất cả'), findsNothing);
      expect(find.byKey(const ValueKey('app-switch-button')), findsOneWidget);

      // Mục thứ 3 là màn con (branch bản sao) — vẫn nằm trong khung.
      await tester.tap(find.text('NCC'));
      await settle(tester);
      expect(find.text('page Nhà cung cấp'), findsOneWidget);
      expect(find.text('Thêm'), findsOneWidget);

      // Thêm: sheet nhóm lồng chứa các mục còn lại.
      await tester.tap(find.text('Thêm'));
      await settle(tester);
      expect(find.byKey(const ValueKey('app-more-inventory_counts')), findsOne);
      await tester.tap(find.byKey(const ValueKey('app-more-inventory_counts')));
      await settle(tester);
      expect(find.text('page Kiểm kê'), findsOneWidget);

      // Nút ô lưới về màn Chọn ứng dụng.
      await tester.tap(find.byKey(const ValueKey('app-switch-button')));
      await settle(tester);
      expect(find.byKey(const ValueKey('app-tile-home')), findsOneWidget);
    });

    testWidgets('một ô: vào thẳng ô đó, không có nút ô lưới', (tester) async {
      final c = containerFor(session(permissions: {'inventory.read'}));
      addTearDown(c.dispose);

      expect(await boot(tester, c), '/inventory/lots');
      expect(find.text('page Hàng sắp về'), findsOneWidget);
      expect(find.text('Thêm'), findsOneWidget);
      expect(find.byKey(const ValueKey('app-switch-button')), findsNothing);
    });

    testWidgets('cờ tắt: như cũ — vào tab đầu, có "Tất cả"', (tester) async {
      final c = containerFor(session(shell: false));
      addTearDown(c.dispose);

      expect(await boot(tester, c), '/home');
      expect(find.text('Tất cả'), findsOneWidget);
      expect(find.byKey(const ValueKey('app-switch-button')), findsNothing);
    });

    testWidgets('API thiếu capability apps.manifest: như cũ', (tester) async {
      final c = containerFor(
        session(caps: allCaps.difference({appsManifestCapability})),
      );
      addTearDown(c.dispose);

      expect(await boot(tester, c), '/home');
      expect(find.text('Tất cả'), findsOneWidget);
    });

    testWidgets('bản khai báo nói tắt (shell: false) thì /apps trả về như cũ', (
      tester,
    ) async {
      final c = containerFor(
        session(),
        manifest: AppManifest.fromJson({..._manifestJson, 'shell': false}),
      );
      addTearDown(c.dispose);

      expect(await boot(tester, c), '/home');
      expect(find.text('Tất cả'), findsOneWidget);
    });
  });
}

final _manifestJson = <String, dynamic>{
  'shell': true,
  'home': ['dashboard', 'sales_actions', 'reminders', 'notifications'],
  'apps': [
    {
      'key': 'sales',
      'name': 'Bán hàng',
      'order': 0,
      'enabled': true,
      'items': [
        {'key': 'inbox', 'group': null},
        {'key': 'sales_stock', 'group': null},
        {'key': 'reports', 'group': 'reports'},
      ],
    },
    {
      'key': 'stock',
      'name': 'Kho',
      'order': 1,
      'enabled': true,
      'items': [
        for (final k in [
          'inventory_lots',
          'inventory_stock',
          'inventory_suppliers',
          'inventory_reservations',
          'inventory_catalog',
          'inventory_delivered',
          'inventory_counts',
          'inventory_accounting',
        ])
          {'key': k, 'group': null},
      ],
    },
    {
      'key': 'system',
      'name': 'Hệ thống',
      'order': 2,
      'enabled': true,
      'items': [
        {'key': 'channels', 'group': null},
      ],
    },
  ],
};

final _manifest = AppManifest.fromJson(_manifestJson);

Widget _page(String title) => Scaffold(
  appBar: OmniTopBar(semanticsTitle: title),
  body: Center(child: Text('page $title')),
);

const _inv = AccessRequirement.all(['inventory.read']);

/// Router thật, trang giả: đủ route để dựng Bàn làm việc và Kho.
class _FakeModule extends OmniModule {
  const _FakeModule();

  @override
  String get id => 'fake';

  @override
  String get title => 'Fake';

  ModuleRoute _r(
    String path,
    String name,
    String title, {
    AccessRequirement access = _inv,
    bool root = false,
  }) => ModuleRoute(
    path: path,
    name: name,
    access: access,
    rootNavigator: root,
    builder: (_, _) => _page(title),
  );

  @override
  List<ModuleRoute> routes() => [
    _r(
      '/home',
      'dashboard.home',
      'Tổng quan',
      access: const AccessRequirement.any(['dashboard.read']),
    ),
    _r(
      '/tasks',
      'tasks.list',
      'Việc của tôi',
      access: const AccessRequirement.any(['tasks.read']),
    ),
    _r('/inventory/lots', 'inventory.lots', 'Hàng sắp về'),
    _r('/inventory/stock', 'inventory.stock', 'Tồn kho'),
    _r(
      '/inventory/suppliers',
      'inventory.suppliers',
      'Nhà cung cấp',
      root: true,
    ),
    _r(
      '/inventory/reservations',
      'inventory.reservations',
      'Đang giữ',
      root: true,
    ),
    _r('/inventory/catalog', 'inventory.catalog', 'Danh mục hàng', root: true),
    _r(
      '/inventory/delivered',
      'inventory.delivered',
      'Hàng đã giao',
      root: true,
    ),
    _r('/inventory/counts', 'inventory.counts', 'Kiểm kê', root: true),
  ];

  ModuleNavEntry _e(
    String route,
    String label,
    List<String> perms, {
    NavWeight weight = NavWeight.secondary,
    NavArea area = NavArea.sales,
    int order = 100,
  }) => ModuleNavEntry(
    moduleId: id,
    label: label,
    icon: Icons.circle_outlined,
    selectedIcon: Icons.circle,
    routeName: route,
    area: area,
    weight: weight,
    order: order,
    access: AccessRequirement.any(perms),
  );

  @override
  List<ModuleNavEntry> navEntries() => [
    _e(
      'dashboard.home',
      'Tổng quan',
      ['dashboard.read'],
      weight: NavWeight.primary,
      area: NavArea.work,
      order: 0,
    ),
    _e(
      'tasks.list',
      'Việc của tôi',
      ['tasks.read'],
      weight: NavWeight.primary,
      area: NavArea.work,
      order: 1,
    ),
    _e('inventory.stock', 'Tồn kho', ['inventory.read'], order: 40),
    _e('inventory.lots', 'Hàng sắp về', ['inventory.read'], order: 41),
  ];
}
