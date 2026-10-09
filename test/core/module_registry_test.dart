import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/bootstrap.dart';
import 'package:omni_app/core/module/module_registry.dart';
import 'package:omni_app/core/module/module_route.dart';
import 'package:omni_app/core/module/nav_destination.dart';
import 'package:omni_app/core/module/omni_module.dart';
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
    //
    // "Việc" (mục teams) đứng ngay sau "Việc của tôi" vì cùng NavArea.work và order 20 so
    // với 10: thợ mở hàng đợi của mình trước, toàn cảnh xưởng sau.
    // Ba mục của NavArea.work đứng trước, theo order 10/20/30: thợ mở hàng
    // đợi của mình trước, toàn cảnh xưởng sau, rồi mới tới dòng thời gian.
    expect(labels, ['Việc của tôi', 'Việc', 'Dòng việc', 'Hộp thư', 'Khách']);
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

  // Đợt 7 P5 (MS-I33): module bị tắt ở workspace thì menu ẩn, dù đủ quyền.
  group('cờ tính năng', () {
    test('mục có feature bị tắt thì ẩn; mục không khai feature thì giữ', () {
      final container = ProviderContainer(
        overrides: [
          modulesProvider.overrideWithValue(const [_FlagModule()]),
          sessionProvider.overrideWithValue(
            const Session(
              status: SessionStatus.authenticated,
              policy: AccessPolicy({'inbox.read'}),
              features: {'inbox': false},
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(visibleNavEntriesProvider).map((e) => e.label), [
        'Nhân viên',
      ]);
      // Branch của router KHÔNG co theo cờ (như theo quyền).
      expect(container.read(declaredNavEntriesProvider), hasLength(2));
    });

    test('module thật khai đúng khoá: tắt inbox/tasks thì mất các tab đó', () {
      final container = ProviderContainer(
        overrides: [
          modulesProvider.overrideWithValue(appModules),
          sessionProvider.overrideWithValue(
            Session(
              status: SessionStatus.authenticated,
              policy: AccessPolicy({
                InboxPermissions.read,
                TaskPermissions.read,
                CustomerPermissions.read,
              }),
              features: const {'inbox': false, 'tasks': false},
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(primaryNavEntriesProvider).map((e) => e.label), [
        'Khách',
      ]);
    });

    test('tắt customers, opportunities, channels thì mất các mục đó', () {
      final permissions = {
        InboxPermissions.read,
        CustomerPermissions.read,
        'crm.sales_opportunities.read',
        'channels.read',
        'membership.members.read',
      };
      Set<String> labels(Map<String, bool> features) {
        final container = ProviderContainer(
          overrides: [
            modulesProvider.overrideWithValue(appModules),
            sessionProvider.overrideWithValue(
              Session(
                status: SessionStatus.authenticated,
                policy: AccessPolicy(permissions),
                features: features,
              ),
            ),
          ],
        );
        addTearDown(container.dispose);
        return container
            .read(visibleNavEntriesProvider)
            .map((e) => e.moduleId)
            .toSet();
      }

      final on = labels(const {});
      final off = labels(const {
        'customers': false,
        'opportunities': false,
        'channels': false,
      });

      expect(on, containsAll(['customers', 'opportunities', 'channels']));
      expect(off, isNot(contains('customers')));
      expect(off, isNot(contains('opportunities')));
      expect(off, isNot(contains('channels')));
      // Không ẩn Nhân viên/Cài đặt theo cờ.
      expect(off, containsAll(['team', 'settings']));
    });
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

class _FlagModule extends OmniModule {
  const _FlagModule();

  @override
  String get id => 'flag';

  @override
  String get title => 'Flag';

  @override
  List<ModuleRoute> routes() => const [];

  @override
  List<ModuleNavEntry> navEntries() => const [
    ModuleNavEntry(
      moduleId: 'inbox',
      label: 'Hộp thư',
      icon: Icons.inbox,
      selectedIcon: Icons.inbox,
      routeName: 'flag-inbox',
      area: NavArea.communication,
      feature: 'inbox',
    ),
    ModuleNavEntry(
      moduleId: 'team',
      label: 'Nhân viên',
      icon: Icons.people,
      selectedIcon: Icons.people,
      routeName: 'flag-team',
      area: NavArea.admin,
    ),
  ];
}
