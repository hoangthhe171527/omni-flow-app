import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/bootstrap.dart';
import 'package:omni_app/core/module/module_registry.dart';
import 'package:omni_app/modules/customers/domain/customer_permissions.dart';
import 'package:omni_app/modules/inbox/domain/inbox_permissions.dart';
import 'package:omni_app/security/permissions/access_policy.dart';
import 'package:omni_app/security/session/session.dart';
import 'package:omni_app/security/session/session_controller.dart';

/// The navigation these tests assert on is the whole point of the module
/// contract: what a user sees is derived from their permissions, never from a
/// role branch in the shell.
ProviderContainer _containerFor(Set<String> permissions) {
  return ProviderContainer(
    overrides: [
      modulesProvider.overrideWithValue(appModules),
      sessionProvider.overrideWithValue(
        Session(
          status: SessionStatus.authenticated,
          policy: AccessPolicy(permissions),
        ),
      ),
    ],
  );
}

void main() {
  test('a session with no permissions gets no tabs', () {
    final container = _containerFor({});
    addTearDown(container.dispose);

    expect(container.read(visibleDestinationsProvider), isEmpty);
  });

  test('an inbox-only rep sees only the inbox tab', () {
    final container = _containerFor({InboxPermissions.readOwn});
    addTearDown(container.dispose);

    final labels =
        container.read(visibleDestinationsProvider).map((d) => d.label).toList();
    expect(labels, ['Hộp thư']);
  });

  test('destinations stay in declared order as permissions widen', () {
    final container = _containerFor({
      InboxPermissions.read,
      CustomerPermissions.read,
      'crm.sales_opportunities.read',
    });
    addTearDown(container.dispose);

    final labels =
        container.read(visibleDestinationsProvider).map((d) => d.label).toList();
    expect(labels, ['Hộp thư', 'Khách hàng', 'Cơ hội']);
  });

  test('the route table is permission-independent', () {
    // Routes must exist for everyone; the AccessBoundary decides what renders.
    // If routes were filtered too, a deep link to a forbidden screen would 404
    // instead of explaining what permission is missing.
    final none = _containerFor({});
    final all = _containerFor({
      InboxPermissions.read,
      CustomerPermissions.read,
    });
    addTearDown(none.dispose);
    addTearDown(all.dispose);

    expect(
      none.read(moduleRoutesProvider).length,
      all.read(moduleRoutesProvider).length,
    );
  });

  test('menu entries are gated the same way as tabs', () {
    final withTeam = _containerFor({'membership.members.read'});
    final withoutTeam = _containerFor({});
    addTearDown(withTeam.dispose);
    addTearDown(withoutTeam.dispose);

    expect(withTeam.read(visibleMenuEntriesProvider)['Quản trị'], isNotNull);
    expect(withoutTeam.read(visibleMenuEntriesProvider)['Quản trị'], isNull);
  });

  test('route names are unique across modules', () {
    final container = _containerFor({});
    addTearDown(container.dispose);

    final names = container.read(moduleRoutesProvider).map((r) => r.name).toList();
    expect(names.toSet().length, names.length);
  });
}
