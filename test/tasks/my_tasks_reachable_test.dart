import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/bootstrap.dart';
import 'package:omni_app/core/module/module_registry.dart';
import 'package:omni_app/core/module/nav_destination.dart';
import 'package:omni_app/core/nav/tab_order.dart';
import 'package:omni_app/modules/plans/routes.dart';
import 'package:omni_app/modules/tasks/routes.dart';
import 'package:omni_app/modules/tasks/tasks_module.dart';
import 'package:omni_app/security/permissions/access_policy.dart';
import 'package:omni_app/security/session/session.dart';
import 'package:omni_app/security/session/session_controller.dart';

/// "Việc của tôi" không còn là tab nhưng phải còn đường vào — với người thợ
/// đây là lý do app được mở, nên mất đường vào là mất trang chủ của họ.
void main() {
  ProviderContainer workerContainer() {
    final c = ProviderContainer(
      overrides: [
        modulesProvider.overrideWithValue(appModules),
        sessionProvider.overrideWithValue(
          Session(
            status: SessionStatus.authenticated,
            policy: AccessPolicy({'tasks.read', 'tasks.write'}),
          ),
        ),
      ],
    );
    addTearDown(c.dispose);

    return c;
  }

  test(
    'Việc của tôi nằm trong Tất cả (nhóm Công việc), không nằm trên thanh tab',
    () {
      final c = workerContainer();
      final tabs = c.read(tabEntriesProvider).map((e) => e.routeName);
      expect(tabs, isNot(contains(TaskRoutes.list)));
      expect(tabs, contains(PlanRoutes.teams));
      final work = c
          .read(directoryGroupsProvider)[NavArea.work]!
          .map((e) => e.routeName);
      expect(work, containsAll([TaskRoutes.list, PlanRoutes.timeline]));
    },
  );

  test('route /tasks, /tasks/search, /tasks/:id vẫn khai báo', () {
    final paths = const TasksModule().routes().map((r) => r.path);
    expect(
      paths,
      containsAll([
        '/tasks',
        '/tasks/search',
        '/tasks/by/:userId',
        '/tasks/:id',
      ]),
    );
  });
}
