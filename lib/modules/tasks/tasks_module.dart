import 'routes.dart';
import 'package:flutter/material.dart';

import '../../core/module/module_route.dart';
import '../../core/module/nav_destination.dart';
import '../../core/module/omni_module.dart';
import '../../security/guard/access_requirement.dart';
import 'application/tasks_providers.dart';
import 'domain/task_permissions.dart';
import 'presentation/create_task_page.dart';
import 'presentation/my_tasks_page.dart';
import 'presentation/task_detail_page.dart';

/// Work assigned to the signed-in person.
///
/// This takes a permanent tab rather than a slot in "Thêm" because for a
/// workshop worker it is the reason the app is open at all. The tab it takes is
/// the one Cơ hội used to hold — four is the ceiling, and a sales pipeline is
/// not what the floor needs at arm's reach.
class TasksModule extends OmniModule {
  const TasksModule();

  static const list = TaskRoutes.list;
  static const detail = TaskRoutes.detail;
  static const create = TaskRoutes.create;

  @override
  String get id => 'tasks';

  @override
  String get title => 'Công việc';

  @override
  List<String> get permissions => TaskPermissions.all;

  @override
  List<ModuleRoute> routes() => [
    ModuleRoute(
      path: '/tasks',
      name: list,
      access: const AccessRequirement.any(TaskPermissions.anyRead),
      builder: (_, _) => const MyTasksPage(),
    ),
    // ĐỨNG TRƯỚC '/tasks/:id': ngược lại thì "new" bị bắt làm một id công việc
    // và màn tạo không bao giờ mở được.
    ModuleRoute(
      path: '/tasks/new',
      name: create,
      rootNavigator: true,
      // Tạo việc là quyền GHI, không phải quyền riêng của người giao việc: §3
      // nói xưởng chạy pull-based, ai cũng ghi được việc mình nhìn thấy.
      access: const AccessRequirement.all([TaskPermissions.write]),
      builder: (_, state) {
        final args = state.extra is CreateTaskArgs
            ? state.extra! as CreateTaskArgs
            : const CreateTaskArgs();

        return CreateTaskPage(
          planId: args.planId,
          sectionId: args.sectionId,
          sections: args.sections,
        );
      },
    ),
    ModuleRoute(
      path: '/tasks/:id',
      name: detail,
      rootNavigator: true,
      access: const AccessRequirement.any(TaskPermissions.anyRead),
      builder: (_, state) =>
          TaskDetailPage(taskId: state.pathParameters['id']!),
    ),
  ];

  @override
  List<ModuleNavEntry> navEntries() => [
    ModuleNavEntry(
      moduleId: 'tasks',
      label: 'Việc của tôi',
      subtitle: 'Việc được giao cho bạn',
      icon: Icons.checklist_outlined,
      selectedIcon: Icons.checklist_rounded,
      routeName: list,
      area: NavArea.work,
      // Với thợ xưởng, đây LÀ trang chủ của họ.
      weight: NavWeight.primary,
      order: 10,
      access: const AccessRequirement.any(TaskPermissions.anyRead),
      // Chỉ việc trễ và việc hôm nay. Badge hiện 40 là giấy dán tường; hiện 3
      // là một lời nhắc.
      badge: taskBadgeProvider,
    ),
  ];
}
