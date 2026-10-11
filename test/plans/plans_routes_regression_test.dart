import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/modules/plans/plans_module.dart';
import 'package:omni_app/modules/plans/routes.dart';
import 'package:omni_app/modules/tasks/routes.dart';
import 'package:omni_app/modules/tasks/tasks_module.dart';

/// Tab Việc viết lại không được làm rơi đường vào nào: bảng kế hoạch, Dòng
/// việc, tab gốc, và các màn của module Việc (Việc của tôi, tìm, việc theo
/// người, deep link `/tasks/:id`).
void main() {
  test('plans: /teams, /timeline, /plans/:id vẫn khai báo đúng tên', () {
    final routes = {
      for (final r in const PlansModule().routes()) r.name: r.path,
    };
    expect(routes[PlanRoutes.teams], '/teams');
    expect(routes[PlanRoutes.timeline], '/timeline');
    expect(routes[PlanRoutes.board], '/plans/:id');
  });

  test('tasks: Việc của tôi, tìm, theo người, chi tiết vẫn khai báo', () {
    final routes = {
      for (final r in const TasksModule().routes()) r.name: r.path,
    };
    expect(routes[TaskRoutes.list], '/tasks');
    expect(routes[TaskRoutes.search], '/tasks/search');
    expect(routes[TaskRoutes.workload], '/tasks/by/:userId');
    expect(routes[TaskRoutes.detail], '/tasks/:id');
  });

  test('tab Việc vẫn trỏ về /teams', () {
    final entries = const PlansModule().navEntries();
    expect(entries.where((e) => e.label == 'Việc').map((e) => e.routeName), [
      PlanRoutes.teams,
    ]);
  });
}
