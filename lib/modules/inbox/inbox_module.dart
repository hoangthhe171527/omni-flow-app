import 'package:flutter/material.dart';

import '../../core/module/module_route.dart';
import '../../core/module/nav_destination.dart';
import '../../core/module/omni_module.dart';
import '../../security/guard/access_requirement.dart';
import 'application/inbox_providers.dart';
import 'domain/inbox_permissions.dart';
import 'presentation/inbox_page.dart';
import 'presentation/thread_page.dart';

/// The omnichannel inbox: Zalo OA and personal, Facebook Page and personal,
/// TikTok, Instagram, WhatsApp and website chat in one list.
class InboxModule extends OmniModule {
  const InboxModule();

  static const list = 'inbox.list';
  static const thread = 'inbox.thread';

  @override
  String get id => 'inbox';

  @override
  String get title => 'Hộp thư';

  @override
  List<String> get permissions => InboxPermissions.all;

  @override
  List<ModuleRoute> routes() => [
    ModuleRoute(
      path: '/inbox',
      name: list,
      access: const AccessRequirement.any(InboxPermissions.anyRead),
      builder: (_, _) => const InboxPage(),
    ),
    ModuleRoute(
      path: '/inbox/:id',
      name: thread,
      // Full-screen over the shell: a chat wants the whole viewport, and a
      // notification tap should land here without a tab bar underneath.
      rootNavigator: true,
      access: const AccessRequirement.any(InboxPermissions.anyRead),
      builder: (_, state) =>
          ThreadPage(conversationId: state.pathParameters['id']!),
    ),
  ];

  @override
  List<ModuleNavEntry> navEntries() => [
    ModuleNavEntry(
      moduleId: id,
      label: 'Hộp thư',
      subtitle: 'Tin nhắn khách hàng',
      icon: Icons.forum_outlined,
      selectedIcon: Icons.forum_rounded,
      routeName: list,
      area: NavArea.communication,
      weight: NavWeight.primary,
      order: 10,
      access: const AccessRequirement.any(InboxPermissions.anyRead),
      badge: inboxUnreadBadgeProvider,
    ),
  ];
}
