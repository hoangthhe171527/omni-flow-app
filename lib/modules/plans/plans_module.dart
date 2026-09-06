import 'package:flutter/material.dart';

import '../../core/module/module_route.dart';
import '../../core/module/nav_destination.dart';
import '../../core/module/omni_module.dart';
import '../../security/guard/access_requirement.dart';
import '../tasks/domain/task_permissions.dart';
import 'presentation/plan_board_page.dart';
import 'presentation/teams_page.dart';

/// Tầng trên của cây công việc: Team → Kế hoạch → Nhóm việc → Công việc.
///
/// Đứng riêng khỏi [TasksModule] vì hai màn trả lời hai câu hỏi khác nhau.
/// "Việc của tôi" là hàng đợi của một người; "Teams" là toàn cảnh của xưởng.
/// Gộp chúng lại là bắt người thợ đi qua một cái cây để tới danh sách của mình.
///
/// Dùng chung quyền của module Tasks: kế hoạch LÀ `project` bên API, và nó nằm
/// sau `tasks.read`/`tasks.write` ở đó. Đặt ra một bộ quyền thứ hai cho cùng
/// một tài nguyên là cách hai bộ trôi khỏi nhau.
class PlansModule extends OmniModule {
  const PlansModule();

  static const teams = 'plans.teams';
  static const board = 'plans.board';

  @override
  String get id => 'plans';

  @override
  String get title => 'Kế hoạch';

  @override
  List<String> get permissions => TaskPermissions.all;

  @override
  List<ModuleRoute> routes() => [
    ModuleRoute(
      path: '/teams',
      name: teams,
      access: const AccessRequirement.any(TaskPermissions.anyRead),
      builder: (_, _) => const TeamsPage(),
    ),
    ModuleRoute(
      path: '/plans/:id',
      name: board,
      rootNavigator: true,
      access: const AccessRequirement.any(TaskPermissions.anyRead),
      builder: (_, state) => PlanBoardPage(planId: state.pathParameters['id']!),
    ),
  ];

  @override
  List<ModuleNavEntry> navEntries() => const [
    ModuleNavEntry(
      moduleId: 'plans',
      label: 'Teams',
      subtitle: 'Kế hoạch và công đoạn của xưởng',
      icon: Icons.workspaces_outline,
      selectedIcon: Icons.workspaces_rounded,
      routeName: teams,
      area: NavArea.work,
      weight: NavWeight.primary,
      // Sau "Việc của tôi" (10). Thợ mở hàng đợi của mình trước, toàn cảnh sau.
      order: 20,
      access: AccessRequirement.any(TaskPermissions.anyRead),
    ),
  ];
}
