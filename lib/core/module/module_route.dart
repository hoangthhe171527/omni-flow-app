import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../security/guard/access_requirement.dart';

/// A route declared by a module, together with the permission it needs.
///
/// The permission travels *with* the route. The previous mobile app kept a
/// central `Map<path, rule>` plus `location.startsWith('/crm/customers/')`
/// prefix matching, which meant every new screen had to be remembered in a
/// second file — and a forgotten entry silently shipped an ungated screen.
class ModuleRoute {
  const ModuleRoute({
    required this.path,
    required this.name,
    required this.builder,
    this.access = const AccessRequirement.open(),
    this.children = const [],
    this.rootNavigator = false,
  });

  final String path;

  /// Unique across the app — used for `context.goNamed` / `pushNamed`.
  final String name;

  final Widget Function(BuildContext context, GoRouterState state) builder;

  final AccessRequirement access;

  final List<ModuleRoute> children;

  /// Push over the tab shell (full-screen detail, chat thread, forms) rather
  /// than inside the current tab.
  final bool rootNavigator;
}
