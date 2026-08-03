import 'package:flutter/material.dart';

import '../../core/module/module_route.dart';
import '../../core/module/nav_destination.dart';
import '../../core/module/omni_module.dart';
import '../../security/guard/access_requirement.dart';
import 'domain/team_permissions.dart';
import 'presentation/team_page.dart';

/// The tenant's people. Earns no tab — it is consulted, not worked in — so it
/// contributes a "Thêm" entry, and exposes its roster to other modules through
/// `team.dart`.
class TeamModule extends OmniModule {
  const TeamModule();

  static const list = 'team.list';

  @override
  String get id => 'team';

  @override
  String get title => 'Nhân viên';

  @override
  List<String> get permissions => TeamPermissions.all;

  @override
  List<ModuleRoute> routes() => [
        ModuleRoute(
          path: '/team',
          name: list,
          rootNavigator: true,
          access: const AccessRequirement.any([TeamPermissions.membersRead]),
          builder: (_, _) => const TeamPage(),
        ),
      ];

  @override
  List<ModuleMenuEntry> menuEntries() => const [
        ModuleMenuEntry(
          moduleId: 'team',
          label: 'Nhân viên',
          subtitle: 'Danh sách thành viên trong workspace',
          icon: Icons.group_outlined,
          routeName: list,
          group: 'Quản trị',
          order: 10,
          access: AccessRequirement.any([TeamPermissions.membersRead]),
        ),
      ];
}
