import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/core/module/module_registry.dart';
import 'package:omni_app/core/module/nav_destination.dart';
import 'package:omni_app/core/nav/tab_order.dart';
import 'package:omni_app/modules/customers/routes.dart';
import 'package:omni_app/modules/plans/routes.dart';
import 'package:shared_preferences/shared_preferences.dart';

ModuleNavEntry e(String route) => ModuleNavEntry(
  moduleId: route,
  label: route,
  icon: Icons.circle,
  selectedIcon: Icons.circle,
  routeName: route,
  area: NavArea.work,
  weight: NavWeight.primary,
);

void main() {
  test('xếp theo thiết kế, bỏ mục không thuộc thanh tab', () {
    final got = orderTabs([
      e(PlanRoutes.teams),
      e('opportunities.pipeline'),
      e('inbox.list'),
      e(CustomerRoutes.list),
      e(PlanRoutes.timeline),
    ]);
    expect(got.map((x) => x.routeName), [
      'inbox.list',
      CustomerRoutes.list,
      PlanRoutes.teams,
    ]);
  });

  test('Tổng quan đứng đầu khi được phép', () {
    expect(
      orderTabs([e('inbox.list'), e('dashboard.home')]).map((x) => x.routeName),
      ['dashboard.home', 'inbox.list'],
    );
  });

  test('chỉ có quyền Hộp thư thì chỉ một tab', () {
    expect(orderTabs([e('inbox.list')]).map((x) => x.routeName), [
      'inbox.list',
    ]);
  });

  test('khoá ghim cũ trong máy không còn ảnh hưởng', () async {
    SharedPreferences.setMockInitialValues({
      'nav_pinned_routes': [PlanRoutes.timeline],
    });
    final c = ProviderContainer(
      overrides: [
        primaryNavEntriesProvider.overrideWithValue([
          e(PlanRoutes.timeline),
          e('inbox.list'),
        ]),
      ],
    );
    addTearDown(c.dispose);
    expect(c.read(tabEntriesProvider).map((x) => x.routeName), ['inbox.list']);
  });

  group('tự chọn thanh menu', () {
    final all = [
      e('dashboard.home'),
      e('inbox.list'),
      e(CustomerRoutes.list),
      e(PlanRoutes.teams),
      e('finance.expenses'),
      e('notifications.centre'),
    ];

    test('giữ đúng thứ tự người dùng xếp, tối đa 4', () {
      final got = resolveTabs(
        saved: [
          'finance.expenses',
          'inbox.list',
          'notifications.centre',
          PlanRoutes.teams,
          'dashboard.home',
        ],
        allowed: all,
      );
      expect(got.map((x) => x.routeName), [
        'finance.expenses',
        'inbox.list',
        'notifications.centre',
        PlanRoutes.teams,
      ]);
    });

    test('mục bị thu quyền rơi khỏi thanh; mất hết thì về mặc định', () {
      expect(
        resolveTabs(
          saved: ['finance.expenses', 'inbox.list'],
          allowed: [e('inbox.list'), e('dashboard.home')],
        ).map((x) => x.routeName),
        ['inbox.list'],
      );
      expect(
        resolveTabs(
          saved: ['finance.expenses'],
          allowed: [e('inbox.list'), e('dashboard.home')],
        ).map((x) => x.routeName),
        ['dashboard.home', 'inbox.list'],
      );
    });

    test('lưu xong thanh đổi ngay và còn sau khi mở lại app', () async {
      SharedPreferences.setMockInitialValues({});
      ProviderContainer boot() => ProviderContainer(
        overrides: [
          primaryNavEntriesProvider.overrideWithValue(all.take(4).toList()),
          pinnableNavEntriesProvider.overrideWithValue(all),
        ],
      );

      final c = boot();
      addTearDown(c.dispose);
      await c.read(tabPinsProvider.future);
      expect(c.read(tabEntriesProvider).map((x) => x.routeName), tabRouteOrder);

      await c.read(tabPinsProvider.notifier).save([
        'finance.expenses',
        'inbox.list',
      ]);
      expect(c.read(tabEntriesProvider).map((x) => x.routeName), [
        'finance.expenses',
        'inbox.list',
      ]);

      final again = boot();
      addTearDown(again.dispose);
      await again.read(tabPinsProvider.future);
      expect(again.read(tabEntriesProvider).map((x) => x.routeName), [
        'finance.expenses',
        'inbox.list',
      ]);

      await again.read(tabPinsProvider.notifier).reset();
      expect(
        again.read(tabEntriesProvider).map((x) => x.routeName),
        tabRouteOrder,
      );
    });
  });
}
