import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../security/guard/access_requirement.dart';

/// A tab a module contributes to the bottom bar.
///
/// The destination declares the permission it needs; the registry does the
/// filtering. The shell renders whatever survives — it has no list of roles, no
/// `if (isAdmin)`, and no knowledge of which module is which. That is precisely
/// what keeps the shell from turning back into the role-branching god-widget it
/// was in the previous app.
class ModuleDestination {
  const ModuleDestination({
    required this.moduleId,
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.routeName,
    required this.order,
    this.access = const AccessRequirement.open(),
    this.badge,
  });

  final String moduleId;
  final String label;
  final IconData icon;
  final IconData selectedIcon;

  /// Name of the [ModuleRoute] this tab shows. Also the branch key in the router.
  final String routeName;

  /// Sort key across all modules. Lower comes first. Leave gaps (10, 20, 30…)
  /// so a module can be slotted between two others without renumbering.
  final int order;

  final AccessRequirement access;

  /// Optional unread/pending count rendered on the tab. A provider rather than a
  /// value so the shell can watch it without knowing what it counts.
  final ProviderListenable<int>? badge;
}

/// An entry a module contributes to the "Thêm" screen — everything that doesn't
/// deserve a permanent tab: settings, members, roles, audit, channels.
class ModuleMenuEntry {
  const ModuleMenuEntry({
    required this.moduleId,
    required this.label,
    required this.icon,
    required this.routeName,
    required this.group,
    this.subtitle,
    this.order = 100,
    this.access = const AccessRequirement.open(),
  });

  final String moduleId;
  final String label;
  final String? subtitle;
  final IconData icon;
  final String routeName;

  /// Section header on the "Thêm" screen: "Bán hàng", "Quản trị", "Tài khoản".
  final String group;
  final int order;
  final AccessRequirement access;
}
