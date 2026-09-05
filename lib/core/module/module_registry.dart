import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../security/session/session_controller.dart';
import 'module_route.dart';
import 'nav_destination.dart';
import 'omni_module.dart';

/// The app's module list. Overridden in `bootstrap.dart` with the real modules
/// so a test can boot a registry of one.
final modulesProvider = Provider<List<OmniModule>>((ref) {
  throw UnimplementedError('modulesProvider must be overridden');
});

/// Flattened routes from every module. The router consumes this and nothing else.
final moduleRoutesProvider = Provider<List<ModuleRoute>>((ref) {
  return [for (final module in ref.watch(modulesProvider)) ...module.routes()];
});

/// Every declared tab, permission-independent and stably ordered. The router
/// builds one navigation branch per entry, so the branch list never changes
/// underneath a running app — only which of them the user can see.
final declaredDestinationsProvider = Provider<List<ModuleDestination>>((ref) {
  final destinations = <ModuleDestination>[
    for (final module in ref.watch(modulesProvider)) ...module.destinations(),
  ]..sort((a, b) => a.order.compareTo(b.order));
  return destinations;
});

/// Tabs the current session may see. Recomputed automatically when permissions
/// change (tenant switch, or a role edit picked up by a context reload).
final visibleDestinationsProvider = Provider<List<ModuleDestination>>((ref) {
  final policy = ref.watch(accessProvider);
  return ref
      .watch(declaredDestinationsProvider)
      .where((destination) => destination.access.isSatisfiedBy(policy))
      .toList();
});

final declaredMenuEntriesProvider = Provider<List<ModuleMenuEntry>>((ref) {
  final entries = <ModuleMenuEntry>[
    for (final module in ref.watch(modulesProvider)) ...module.menuEntries(),
  ]..sort((a, b) => a.order.compareTo(b.order));
  return entries;
});

/// Entries for the "Thêm" screen, grouped by section.
final visibleMenuEntriesProvider = Provider<Map<String, List<ModuleMenuEntry>>>(
  (ref) {
    final policy = ref.watch(accessProvider);
    final grouped = <String, List<ModuleMenuEntry>>{};
    for (final entry in ref.watch(declaredMenuEntriesProvider)) {
      if (!entry.access.isSatisfiedBy(policy)) continue;
      grouped.putIfAbsent(entry.group, () => []).add(entry);
    }
    return grouped;
  },
);

/// Every permission slug the app knows about, by module. Powers the
/// "Quyền của tôi" diagnostics screen.
final declaredPermissionsProvider = Provider<Map<String, List<String>>>((ref) {
  return {
    for (final module in ref.watch(modulesProvider))
      module.title: module.permissions,
  };
});
