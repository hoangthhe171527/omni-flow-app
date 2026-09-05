import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/module/module_route.dart';
import '../../core/module/nav_destination.dart';
import '../../core/module/omni_module.dart';
import '../tasks/tasks_module.dart';
import 'presentation/notifications_page.dart';

/// The bell.
///
/// No tab of its own: notifications are a place you go after something tells
/// you to, not one of the four things you switch between. It is reached from
/// the bell on "Việc của tôi" and from "Thêm".
///
/// Every signed-in user has one, so there is no permission on it — the API
/// returns only the caller's own rows.
class NotificationsModule extends OmniModule {
  const NotificationsModule();

  static const centre = 'notifications.centre';

  @override
  String get id => 'notifications';

  @override
  String get title => 'Thông báo';

  @override
  List<ModuleRoute> routes() => [
    ModuleRoute(
      path: '/notifications',
      name: centre,
      rootNavigator: true,
      builder: (context, _) => NotificationsPage(
        // The bell knows a task id; the tasks module owns what to do with it.
        // Passing the callback rather than importing a page keeps the two
        // modules from depending on each other's presentation layer.
        onOpenTask: (taskId) => context.pushNamed(
          TasksModule.detail,
          pathParameters: {'id': taskId},
        ),
      ),
    ),
  ];

  @override
  List<ModuleMenuEntry> menuEntries() => const [
    ModuleMenuEntry(
      moduleId: 'notifications',
      label: 'Thông báo',
      subtitle: 'Việc được giao, việc đã xong',
      icon: Icons.notifications_none_rounded,
      routeName: centre,
      group: 'Tài khoản',
      order: 10,
    ),
  ];
}
