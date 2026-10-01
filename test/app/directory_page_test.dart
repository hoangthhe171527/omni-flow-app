import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/app/shell/directory_page.dart';
import 'package:omni_app/core/module/module_registry.dart';
import 'package:omni_app/core/module/module_route.dart';
import 'package:omni_app/core/module/nav_destination.dart';
import 'package:omni_app/core/module/omni_module.dart';
import 'package:omni_app/core/nav/pinned_tabs.dart';
import 'package:omni_app/core/storage/preferences_store.dart';
import 'package:omni_app/design/components/components.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/design/tokens/tokens.dart';
import 'package:omni_app/modules/auth/application/login_controller.dart';
import 'package:omni_app/security/permissions/access_policy.dart';
import 'package:omni_app/security/session/auth_gateway.dart';
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
    _entry('Hộp thư', NavArea.communication, badge: _unread),
    _entry('Khách hàng', NavArea.sales),
    _entry('Nhân viên', NavArea.admin),
    _entry(
      'Quyền của tôi',
      NavArea.account,
      subtitle: 'Xem những gì bạn được phép làm',
    ),
  ];
}

const _session = Session(
  status: SessionStatus.authenticated,
  user: SessionUser(id: 'u', fullName: 'Trần Huy Hoàng', email: 'h@x.vn'),
  tenant: SessionTenant(id: 't-1', name: 'Xưởng đàn Hoàng Gia'),
  policy: AccessPolicy({}),
);

class _FakeSession extends SessionController {
  int chooseCalls = 0;

  @override
  Session build() => _session;

  @override
  void chooseWorkspace() => chooseCalls++;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<_FakeSession> pump(WidgetTester tester, {int tenantCount = 1}) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final controller = _FakeSession();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          modulesProvider.overrideWithValue(const [_FakeModule()]),
          sharedPreferencesProvider.overrideWithValue(prefs),
          sessionControllerProvider.overrideWith(() => controller),
          pinnedTabsProvider.overrideWith(_NoPins.new),
          tenantOptionsProvider.overrideWith(
            (ref) async => [
              for (var i = 0; i < tenantCount; i++)
                TenantOption(id: 't-$i', name: 'Không gian $i'),
            ],
          ),
        ],
        child: MaterialApp(
          theme: OmniTheme.light(),
          home: const DirectoryPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return controller;
  }

  testWidgets('thẻ hồ sơ và không gian làm việc ở đầu màn', (tester) async {
    await pump(tester);

    expect(find.text('Trần Huy Hoàng'), findsOneWidget);
    expect(find.text('Xưởng đàn Hoàng Gia'), findsOneWidget);
  });

  testWidgets('nhóm theo khu, Bán hàng và Quản trị chung một lưới', (
    tester,
  ) async {
    await pump(tester);

    expect(find.text('Công việc'), findsOneWidget);
    expect(find.text('Trao đổi'), findsOneWidget);
    expect(find.text('Bán hàng · Quản trị'), findsOneWidget);
    expect(find.text('Cá nhân'), findsOneWidget);
    expect(find.text('Pháp lý & hỗ trợ'), findsOneWidget);
    // Mục khu Tài khoản nằm trong "Cá nhân", có dòng phụ.
    expect(find.text('Xem những gì bạn được phép làm'), findsOneWidget);
  });

  testWidgets('tin chưa đọc là huy hiệu vàng, việc trễ là huy hiệu đỏ', (
    tester,
  ) async {
    await pump(tester);

    final badges = tester
        .widgetList<OmniCountBadge>(find.byType(OmniCountBadge))
        .toList();
    final unread = badges.singleWhere((b) => b.count == 12);
    final overdue = badges.singleWhere((b) => b.count == 3);

    expect(unread.color, OmniColors.sun);
    expect(unread.foreground, OmniColors.ink);
    expect(overdue.color, OmniColors.dangerSurface);
  });

  testWidgets('chỉ một không gian thì KHÔNG có nút Đổi', (tester) async {
    await pump(tester);

    expect(find.widgetWithText(TextButton, 'Đổi'), findsNothing);
  });

  testWidgets('nhiều không gian: nút Đổi đưa về màn chọn', (tester) async {
    final controller = await pump(tester, tenantCount: 2);

    await tester.tap(find.widgetWithText(TextButton, 'Đổi'));
    await tester.pump();

    expect(controller.chooseCalls, 1);
  });

  testWidgets('tìm kiếm lọc ô, nhóm trống biến mất cả tiêu đề', (tester) async {
    await pump(tester);

    await tester.enterText(find.byType(TextField), 'hop thu');
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Hộp thư'), findsOneWidget);
    expect(find.text('Khách hàng'), findsNothing);
    expect(find.text('Công việc'), findsNothing);
  });

  testWidgets('chọn giao diện bằng ba nút có nhãn đọc được', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(tester);

    expect(find.bySemanticsLabel('Theo hệ thống'), findsOneWidget);
    expect(find.bySemanticsLabel('Sáng'), findsOneWidget);
    expect(find.bySemanticsLabel('Tối'), findsOneWidget);
    handle.dispose();
  });
}

class _NoPins extends PinnedTabs {
  @override
  Future<List<String>> build() async => const [];
}
