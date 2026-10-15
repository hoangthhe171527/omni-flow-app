import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:omni_app/app/shell/directory_page.dart';
import 'package:omni_app/core/module/module_registry.dart';
import 'package:omni_app/core/module/module_route.dart';
import 'package:omni_app/core/module/nav_destination.dart';
import 'package:omni_app/core/module/omni_module.dart';
import 'package:omni_app/core/storage/preferences_store.dart';
import 'package:omni_app/design/components/components.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/design/tokens/tokens.dart';
import 'package:omni_app/modules/settings/settings_module.dart';
import 'package:omni_app/security/permissions/access_policy.dart';
import 'package:omni_app/security/session/session.dart';
import 'package:omni_app/security/session/session_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _unread = Provider<int>((ref) => 12);
final _overdue = Provider<int>((ref) => 3);

ModuleNavEntry _entry(
  String label,
  NavArea area, {
  ProviderListenable<int>? badge,
  NavBadgeTone tone = NavBadgeTone.unread,
  NavBadgeDisplay display = NavBadgeDisplay.count,
  String? subtitle,
}) => ModuleNavEntry(
  moduleId: label,
  label: label,
  subtitle: subtitle,
  routeName: 'route.$label',
  icon: Icons.circle_outlined,
  selectedIcon: Icons.circle,
  area: area,
  badge: badge,
  badgeTone: tone,
  badgeDisplay: display,
);

class _FakeModule extends OmniModule {
  const _FakeModule();

  @override
  String get id => 'fake';

  @override
  String get title => 'Fake';

  @override
  List<ModuleRoute> routes() => const [];

  @override
  List<ModuleNavEntry> navEntries() => [
    _entry(
      'Việc của tôi',
      NavArea.work,
      badge: _overdue,
      tone: NavBadgeTone.alert,
    ),
    _entry(
      'Hộp thư',
      NavArea.communication,
      badge: _unread,
      display: NavBadgeDisplay.dot,
    ),
    _entry('Khách hàng', NavArea.sales),
    _entry('Nhân viên', NavArea.admin),
    _entry(
      'Quyền của tôi',
      NavArea.account,
      subtitle: 'Xem những gì bạn được phép làm',
    ),
  ];
}

class _NoAdminModule extends _FakeModule {
  const _NoAdminModule();

  @override
  List<ModuleNavEntry> navEntries() => [
    for (final e in super.navEntries())
      if (e.area != NavArea.admin) e,
  ];
}

class _FiveSalesModule extends OmniModule {
  const _FiveSalesModule();

  @override
  String get id => 'five-sales';

  @override
  String get title => 'Five sales';

  @override
  List<ModuleRoute> routes() => const [];

  @override
  List<ModuleNavEntry> navEntries() => [
    for (var index = 1; index <= 5; index++)
      _entry('Bán hàng $index', NavArea.sales),
  ];
}

const _session = Session(
  status: SessionStatus.authenticated,
  user: SessionUser(id: 'u', fullName: 'Trần Huy Hoàng', email: 'h@x.vn'),
  tenant: SessionTenant(id: 't-1', name: 'Xưởng đàn Hoàng Gia'),
  policy: AccessPolicy({}),
);

class _FakeSession extends SessionController {
  @override
  Session build() => _session;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Dòng việc được tách khỏi nhóm Công việc trong mục Tất cả', () {
    final sections = buildDirectorySections(
      {
        NavArea.work: [
          _entry('Việc', NavArea.work),
          _entry('Dòng việc', NavArea.work),
        ],
      },
      personal: const [],
      open: (_) {},
      query: '',
    );

    expect(sections.map((section) => section.label), [
      'Công việc',
      'Dòng việc',
    ]);
    expect(sections.first.tiles.map((tile) => tile.label), ['Việc']);
    expect(sections.last.tiles.map((tile) => tile.label), ['Dòng việc']);
  });

  Future<void> pump(
    WidgetTester tester, {
    OmniModule module = const _FakeModule(),
    bool reducedMotion = false,
    bool settle = true,
    Size size = const Size(390, 1600),
    double textScale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const DirectoryPage()),
        GoRoute(
          path: '/account',
          name: SettingsModule.account,
          builder: (_, _) => const Text('ACCOUNT'),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          modulesProvider.overrideWithValue([module]),
          sharedPreferencesProvider.overrideWithValue(prefs),
          sessionControllerProvider.overrideWith(_FakeSession.new),
        ],
        child: MaterialApp.router(
          theme: OmniTheme.light(),
          routerConfig: router,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              disableAnimations: reducedMotion,
              textScaler: TextScaler.linear(textScale),
            ),
            child: child!,
          ),
        ),
      ),
    );
    if (settle) await tester.pumpAndSettle();
  }

  testWidgets('nhóm theo bản mẫu: Bán hàng gộp Trao đổi + Bán hàng', (t) async {
    await pump(t);
    final labels = t
        .widgetList<Text>(
          find.descendant(
            of: find.byWidgetPredicate(
              (w) => w is Semantics && w.properties.header == true,
            ),
            matching: find.byType(Text),
          ),
        )
        .map((e) => e.data)
        .toList();
    expect(labels, ['Bán hàng', 'Công việc', 'Đội & quản trị', 'Cá nhân']);
  });

  testWidgets('lưới 4 cột: 4 ô Cá nhân nằm cùng một hàng', (t) async {
    await pump(t);
    final ys = [
      'Quyền của tôi',
      'Tài khoản',
      'Giao diện',
      'Hỗ trợ',
    ].map((l) => t.getCenter(find.text(l)).dy).toSet();
    expect(ys.length, 1);
  });

  testWidgets('màn hẹp tự giảm còn 3 cột và không tràn', (t) async {
    await pump(t, size: const Size(320, 1600));

    final personalCenters = [
      'Quyền của tôi',
      'Tài khoản',
      'Giao diện',
    ].map((label) => t.getCenter(find.text(label)).dy).toSet();
    expect(personalCenters, hasLength(1));
    expect(
      t.getCenter(find.text('Hỗ trợ')).dy,
      greaterThan(personalCenters.single),
    );
    expect(t.takeException(), isNull);
  });

  testWidgets('cỡ chữ lớn tự giảm cột, nhãn tối đa hai dòng', (t) async {
    await pump(t, textScale: 1.6);

    final personalCenters = [
      'Quyền của tôi',
      'Tài khoản',
      'Giao diện',
    ].map((label) => t.getCenter(find.text(label)).dy).toSet();
    expect(personalCenters, hasLength(1));
    expect(
      t.getCenter(find.text('Hỗ trợ')).dy,
      greaterThan(personalCenters.single),
    );
    expect(t.widget<Text>(find.text('Quyền của tôi')).maxLines, 2);
    expect(t.takeException(), isNull);
  });

  testWidgets('hàng cuối thiếu ô chỉ dựng số tile thật và ôm đúng hai hàng', (
    t,
  ) async {
    await pump(t, module: const _FiveSalesModule());

    final gridFinder = find.byKey(const Key('directory-tile-grid-0'));
    final grid = t.widget<Wrap>(gridFinder);
    expect(grid.children, hasLength(5));

    final firstRow = [
      'Bán hàng 1',
      'Bán hàng 2',
      'Bán hàng 3',
      'Bán hàng 4',
    ].map((label) => t.getCenter(find.text(label)).dy).toSet();
    expect(firstRow, hasLength(1));
    expect(
      t.getCenter(find.text('Bán hàng 5')).dy,
      greaterThan(firstRow.single),
    );

    final firstTile = find
        .ancestor(of: find.text('Bán hàng 1'), matching: find.byType(SizedBox))
        .first;
    expect(
      t.getSize(gridFinder).height,
      moreOrLessEquals(t.getSize(firstTile).height * 2 + grid.runSpacing),
    );
  });

  testWidgets('toàn bộ ô là vùng chạm lớn hơn 44dp và badge không lệch icon', (
    t,
  ) async {
    await pump(t);

    final inboxInk = find
        .ancestor(of: find.text('Hộp thư'), matching: find.byType(InkWell))
        .first;
    final inboxSize = t.getSize(inboxInk);
    expect(inboxSize.width, greaterThanOrEqualTo(44));
    expect(inboxSize.height, greaterThanOrEqualTo(44));

    final iconCenters = ['Hộp thư', 'Khách hàng'].map((label) {
      final tile = find
          .ancestor(of: find.text(label), matching: find.byType(InkWell))
          .first;
      return t
          .getCenter(
            find.descendant(of: tile, matching: find.byType(Icon)).first,
          )
          .dy;
    }).toSet();
    expect(iconCenters, hasLength(1));
  });

  testWidgets('ô có màu theo nhóm (tím cho Quản trị, sáng)', (t) async {
    await pump(t);
    final box = t.widget<Container>(
      find
          .ancestor(
            of: find.byIcon(Icons.circle_outlined).at(3), // 'Nhân viên'
            matching: find.byType(Container),
          )
          .first,
    );
    expect(
      (box.decoration! as BoxDecoration).color,
      OmniFeatureTones.light(OmniHue.violet).background,
    );
  });

  testWidgets('huy hiệu: tin chưa đọc là chấm, việc trễ vẫn là số đỏ', (
    t,
  ) async {
    await pump(t);
    final overdue = t.widget<OmniCountBadge>(find.byType(OmniCountBadge));

    expect(find.byType(OmniUnreadDot), findsOneWidget);
    expect(overdue.color, OmniColors.dangerSurface);
    expect(overdue.count, 3);
  });

  testWidgets('không còn thẻ hồ sơ / không gian / đăng xuất / xoá tài khoản', (
    t,
  ) async {
    await pump(t);
    expect(find.text('Trần Huy Hoàng'), findsNothing);
    expect(find.text('Không gian làm việc'), findsNothing);
    expect(find.text('Đăng xuất'), findsNothing);
    expect(find.text('Xóa tài khoản'), findsNothing);
  });

  testWidgets('tìm không dấu "tai khoan" chỉ còn nhóm Cá nhân', (t) async {
    await pump(t);
    await t.enterText(find.byType(TextField), 'tai khoan');
    await t.pump(const Duration(milliseconds: 400)); // debounce của ô tìm
    await t.pumpAndSettle();
    expect(find.text('Tài khoản'), findsOneWidget);
    expect(find.text('Bán hàng'), findsNothing);
  });

  testWidgets('không khớp → Không tìm thấy tính năng “…”', (t) async {
    await pump(t);
    await t.enterText(find.byType(TextField), 'zzz');
    await t.pump(const Duration(milliseconds: 400)); // debounce của ô tìm
    await t.pumpAndSettle();
    expect(find.text('Không tìm thấy tính năng “zzz”'), findsOneWidget);
  });

  testWidgets('Tài khoản mở route settings.account', (t) async {
    await pump(t);
    await t.tap(find.text('Tài khoản'));
    await t.pumpAndSettle();
    expect(find.text('ACCOUNT'), findsOneWidget);
  });

  testWidgets('ô là nút ngữ nghĩa có onTap, hộp thư chỉ nói có tin chưa đọc', (
    t,
  ) async {
    final handle = t.ensureSemantics();
    await pump(t);
    final node = t.getSemantics(
      find.bySemanticsLabel('Hộp thư, có tin chưa đọc'),
    );
    expect(node.label, 'Hộp thư, có tin chưa đọc');
    expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    handle.dispose();
  });

  testWidgets('module không khai mục nào cho khu Quản trị → không có nhóm đó', (
    t,
  ) async {
    await pump(t, module: const _NoAdminModule());
    expect(find.text('Đội & quản trị'), findsNothing);
  });

  testWidgets('giảm chuyển động: không còn khung hoạt ảnh sau một pump', (
    t,
  ) async {
    await pump(t, reducedMotion: true, settle: false);
    await t.pump();
    expect(t.hasRunningAnimations, isFalse);
  });

  testWidgets('gõ tìm không phát lại hoạt ảnh hiện ô', (t) async {
    await pump(t);
    await t.enterText(find.byType(TextField), 'hop');
    await t.pump(const Duration(milliseconds: 400));
    await t.pump(const Duration(milliseconds: 16));
    final fade = t.widget<FadeTransition>(
      find
          .ancestor(
            of: find.text('Hộp thư'),
            matching: find.byType(FadeTransition),
          )
          .first,
    );
    expect(fade.opacity.value, 1.0);
  });

  _searchFieldTests();

  test('hueOfArea theo bản mẫu', () {
    expect(hueOfArea(NavArea.communication), OmniHue.teal);
    expect(hueOfArea(NavArea.sales), OmniHue.orange);
    expect(hueOfArea(NavArea.work), OmniHue.blue);
    expect(hueOfArea(NavArea.admin), OmniHue.violet);
    expect(hueOfArea(NavArea.account), OmniHue.neutral);
  });
}

void _searchFieldTests() {
  for (final (width, scale) in [(360.0, 1.0), (360.0, 1.3)]) {
    testWidgets('ô tìm cao 44, gõ chữ không tràn ($width, x$scale)', (t) async {
      t.view.physicalSize = Size(width, 800);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await t.pumpWidget(
        ProviderScope(
          overrides: [
            modulesProvider.overrideWithValue(const [_FakeModule()]),
            sharedPreferencesProvider.overrideWithValue(prefs),
            sessionControllerProvider.overrideWith(_FakeSession.new),
          ],
          child: MaterialApp.router(
            theme: OmniTheme.light(),
            routerConfig: GoRouter(
              routes: [
                GoRoute(path: '/', builder: (_, _) => const DirectoryPage()),
              ],
            ),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(t.getSize(find.byType(TextField)).height, 44);
      await t.enterText(find.byType(TextField), 'Việc của tôi');
      await t.pump(const Duration(milliseconds: 400));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    });
  }
}
