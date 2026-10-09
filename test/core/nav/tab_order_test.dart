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
}
