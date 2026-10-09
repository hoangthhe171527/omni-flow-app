import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/app/router/app_router.dart';
import 'package:omni_app/bootstrap.dart';
import 'package:omni_app/core/module/module_registry.dart';
import 'package:omni_app/security/permissions/access_policy.dart';
import 'package:omni_app/security/session/session.dart';
import 'package:omni_app/security/session/session_controller.dart';

String _landing(Set<String> permissions) {
  final c = ProviderContainer(
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
  addTearDown(c.dispose);

  return landingPath(c.read(Provider<Ref>((ref) => ref)));
}

void main() {
  test('chỉ có mục không thuộc thanh tab thì vào /more', () {
    expect(_landing({'crm.sales_opportunities.read'}), '/more');
  });

  test('có Hộp thư và Việc thì vào Hộp thư', () {
    final path = _landing({'tasks.read', 'inbox.read'});
    expect(path, isNot('/more'));
    expect(path, contains('inbox'));
  });
}
