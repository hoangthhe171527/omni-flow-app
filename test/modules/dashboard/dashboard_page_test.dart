import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:omni_app/bootstrap.dart';
import 'package:omni_app/core/module/module_registry.dart';
import 'package:omni_app/core/network/api_envelope.dart';
import 'package:omni_app/core/nav/tab_order.dart';
import 'package:omni_app/design/components/omni_top_bar.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/modules/dashboard/application/dashboard_providers.dart';
import 'package:omni_app/modules/dashboard/dashboard_routes.dart';
import 'package:omni_app/modules/dashboard/data/dashboard_api.dart';
import 'package:omni_app/modules/dashboard/domain/revenue_period.dart';
import 'package:omni_app/modules/dashboard/domain/revenue_series.dart';
import 'package:omni_app/modules/dashboard/presentation/dashboard_page.dart';
import 'package:omni_app/modules/inbox/domain/conversation.dart';
import 'package:omni_app/modules/settings/application/appearance_providers.dart';
import 'package:omni_app/modules/tasks/domain/task.dart';
import 'package:omni_app/security/permissions/access_policy.dart';
import 'package:omni_app/security/session/session.dart';
import 'package:omni_app/security/session/session_controller.dart';

import '../../support/fixed_background.dart';

class FakeDashboardApi implements DashboardApi {
  int calls = 0;

  @override
  Future<RevenueSeries?> revenueSeries(RevenueRange r, {DateTime? now}) async {
    calls++;
    return null;
  }
}

class Counts {
  final api = FakeDashboardApi();
  int tasks = 0;
  int awaiting = 0;
}

Future<Counts> pumpPage(
  WidgetTester t,
  Set<String> perms, {
  bool dark = false,
  Map<String, bool> features = const {},
}) async {
  t.view.physicalSize = const Size(390, 844);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final c = Counts();
  await t.pumpWidget(
    ProviderScope(
      overrides: [
        sessionProvider.overrideWithValue(
          Session(
            status: SessionStatus.authenticated,
            policy: AccessPolicy(perms),
            features: features,
          ),
        ),
        accessProvider.overrideWithValue(AccessPolicy(perms)),
        backgroundProvider.overrideWith(FixedBackground.new),
        dashboardApiProvider.overrideWithValue(c.api),
        dashboardMyTasksProvider.overrideWith((_) async {
          c.tasks++;
          return Paged<Task>(
            items: const [],
            pagination: const ApiPagination(
              currentPage: 1,
              lastPage: 1,
              perPage: 5,
              total: 0,
            ),
          );
        }),
        dashboardAwaitingReplyProvider.overrideWith((_) async {
          c.awaiting++;
          return const CursorPaged<Conversation>.empty();
        }),
      ],
      child: MaterialApp(
        theme: dark ? OmniTheme.dark() : OmniTheme.light(),
        home: const DashboardPage(),
      ),
    ),
  );
  await t.pumpAndSettle();
  return c;
}

List<String> tabsFor(Set<String> perms) {
  final c = ProviderContainer(
    overrides: [
      modulesProvider.overrideWithValue(appModules),
      sessionProvider.overrideWithValue(
        Session(
          status: SessionStatus.authenticated,
          policy: AccessPolicy(perms),
        ),
      ),
    ],
  );
  addTearDown(c.dispose);
  return c.read(tabEntriesProvider).map((e) => e.routeName).toList();
}

void main() {
  setUpAll(() => initializeDateFormatting('vi_VN'));

  group('tab', () {
    test('đủ quyền → tab đầu là Tổng quan', () {
      final tabs = tabsFor({
        'crm.sales_overview.read',
        'tasks.read',
        'inbox.read',
        'crm.customers.read',
      });
      expect(tabs.first, DashboardRoutes.home);
      final c = ProviderContainer(
        overrides: [modulesProvider.overrideWithValue(appModules)],
      );
      addTearDown(c.dispose);
      final entry = c
          .read(declaredNavEntriesProvider)
          .firstWhere((e) => e.routeName == DashboardRoutes.home);
      expect(entry.label, 'Tổng quan');
      expect(
        c
            .read(moduleRoutesProvider)
            .firstWhere((r) => r.name == DashboardRoutes.home)
            .path,
        '/home',
      );
    });

    test('chỉ tasks.read → vẫn có tab Tổng quan', () {
      expect(tabsFor({'tasks.read'}), contains(DashboardRoutes.home));
    });

    test('không quyền nào trong anyRead → không có tab', () {
      final tabs = tabsFor({'crm.customers.read'});
      expect(tabs, isNot(contains(DashboardRoutes.home)));
      expect(tabs.first, isNot(DashboardRoutes.home));
    });
  });

  for (final dark in [false, true]) {
    final mode = dark ? 'tối' : 'sáng';

    testWidgets('đủ quyền ($mode): top bar, không ô tìm, không "Cần chú ý"', (
      t,
    ) async {
      final c = await pumpPage(t, {
        'crm.sales_overview.read',
        'tasks.read',
        'inbox.read',
      }, dark: dark);
      expect(find.byType(OmniTopBar), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(find.textContaining('Cần chú ý'), findsNothing);
      expect(find.text('Việc của tôi'), findsOneWidget);
      expect(find.text('Chờ phản hồi'), findsOneWidget);
      expect(c.api.calls, 1);
      expect(t.takeException(), isNull);
    });
  }

  testWidgets('chỉ tasks.read → chỉ Việc của tôi, không gọi doanh thu', (
    t,
  ) async {
    final c = await pumpPage(t, {'tasks.read'});
    expect(find.text('Việc của tôi'), findsOneWidget);
    expect(find.text('Chờ phản hồi'), findsNothing);
    expect(find.text('Doanh thu'), findsNothing);
    expect(c.api.calls, 0);
  });

  testWidgets('chỉ inbox.read.own → chỉ Chờ phản hồi', (t) async {
    final c = await pumpPage(t, {'inbox.read.own'});
    expect(find.text('Chờ phản hồi'), findsOneWidget);
    expect(find.text('Việc của tôi'), findsNothing);
    expect(c.api.calls, 0);
  });

  group('cờ tính năng tắt → thẻ ẩn, không gọi mạng', () {
    const all = {'crm.sales_overview.read', 'tasks.read', 'inbox.read'};

    testWidgets('tasks tắt', (t) async {
      final c = await pumpPage(t, all, features: {'tasks': false});
      expect(find.text('Việc của tôi'), findsNothing);
      expect(find.text('Chờ phản hồi'), findsOneWidget);
      expect([c.api.calls, c.tasks, c.awaiting], [1, 0, 1]);
    });

    testWidgets('inbox tắt', (t) async {
      final c = await pumpPage(t, all, features: {'inbox': false});
      expect(find.text('Chờ phản hồi'), findsNothing);
      expect(find.text('Việc của tôi'), findsOneWidget);
      expect([c.api.calls, c.tasks, c.awaiting], [1, 1, 0]);
    });

    testWidgets('crm_overview tắt', (t) async {
      final c = await pumpPage(t, all, features: {'crm_overview': false});
      expect([c.api.calls, c.tasks, c.awaiting], [0, 1, 1]);
      expect(find.text(DashboardPage.emptyMessage), findsNothing);
    });

    testWidgets('tắt hết → trạng thái trống; kéo tải lại không gọi gì', (
      t,
    ) async {
      final c = await pumpPage(
        t,
        all,
        features: {'tasks': false, 'inbox': false, 'crm_overview': false},
      );
      expect(find.text(DashboardPage.emptyMessage), findsOneWidget);
      expect(find.text('Việc của tôi'), findsNothing);
      expect(find.text('Chờ phản hồi'), findsNothing);
      await t.fling(find.byType(ListView), const Offset(0, 400), 1000);
      await t.pumpAndSettle();
      expect([c.api.calls, c.tasks, c.awaiting], [0, 0, 0]);
    });
  });

  testWidgets('kéo xuống tải lại cả ba nguồn', (t) async {
    final c = await pumpPage(t, {
      'crm.sales_overview.read',
      'tasks.read',
      'inbox.read',
    });
    expect([c.api.calls, c.tasks, c.awaiting], [1, 1, 1]);
    await t.fling(find.byType(ListView), const Offset(0, 400), 1000);
    await t.pumpAndSettle();
    expect([c.api.calls, c.tasks, c.awaiting], [2, 2, 2]);
  });
}
