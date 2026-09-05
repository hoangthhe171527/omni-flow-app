import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/bootstrap.dart';
import 'package:omni_app/core/module/module_registry.dart';
import 'package:omni_app/core/module/nav_destination.dart';
import 'package:omni_app/modules/customers/domain/customer_permissions.dart';
import 'package:omni_app/modules/inbox/domain/inbox_permissions.dart';
import 'package:omni_app/modules/tasks/domain/task_permissions.dart';
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

    expect(container.read(primaryNavEntriesProvider), isEmpty);
  });

  test('an inbox-only rep sees only the inbox tab', () {
    final container = _containerFor({InboxPermissions.readOwn});
    addTearDown(container.dispose);

    final labels = container
        .read(primaryNavEntriesProvider)
        .map((e) => e.label)
        .toList();
    expect(labels, ['Hộp thư']);
  });

  test('tab xếp theo nhóm chức năng khi quyền mở rộng', () {
    final container = _containerFor({
      InboxPermissions.read,
      TaskPermissions.read,
      CustomerPermissions.read,
    });
    addTearDown(container.dispose);

    final labels = container
        .read(primaryNavEntriesProvider)
        .map((e) => e.label)
        .toList();

    // work → communication → sales. Thiên về xưởng có chủ đích: người giữ đủ
    // quyền thấy "Việc của tôi" trước "Hộp thư". Đổi lại là đổi thứ tự các
    // hằng trong enum NavArea — một dòng, một chỗ.
    expect(labels, ['Việc của tôi', 'Hộp thư', 'Khách hàng']);
  });

  test('người chỉ có quyền bán hàng vẫn được tab của mình', () {
    // Trước đây Cơ hội bị đẩy xuống "Thêm" bằng tay để nhường tab cho Tasks —
    // một quyết định viết cứng trong file của module Cơ hội, và nó sai với
    // người mà bán hàng LÀ công việc.
    //
    // Giờ vị trí do quyền quyết: người chỉ có quyền bán hàng thấy Cơ hội trên
    // tab, còn thợ xưởng không có quyền đó thì không thấy. Không ai phải sửa
    // file của module khác nữa.
    final container = _containerFor({'crm.sales_opportunities.read'});
    addTearDown(container.dispose);

    expect(container.read(primaryNavEntriesProvider).map((e) => e.label), [
      'Cơ hội',
    ]);
    expect(
      container
          .read(directoryGroupsProvider)[NavArea.sales]
          ?.map((e) => e.label),
      contains('Cơ hội'),
    );
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

  test('mục trong danh bạ bị chặn theo quyền y như tab', () {
    // Danh bạ không phải chỗ trút những thứ không lọt vào tab. Nó chịu đúng
    // một luật lọc như thanh dưới.
    final withTeam = _containerFor({'membership.members.read'});
    final withoutTeam = _containerFor({});
    addTearDown(withTeam.dispose);
    addTearDown(withoutTeam.dispose);

    expect(withTeam.read(directoryGroupsProvider)[NavArea.admin], isNotNull);
    expect(withoutTeam.read(directoryGroupsProvider)[NavArea.admin], isNull);
  });

  test('route names are unique across modules', () {
    final container = _containerFor({});
    addTearDown(container.dispose);

    final names = container
        .read(moduleRoutesProvider)
        .map((r) => r.name)
        .toList();
    expect(names.toSet().length, names.length);
  });
}
