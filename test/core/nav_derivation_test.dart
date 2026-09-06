import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/core/module/module_registry.dart';
import 'package:omni_app/core/module/module_route.dart';
import 'package:omni_app/core/module/nav_destination.dart';
import 'package:omni_app/core/module/omni_module.dart';
import 'package:omni_app/security/guard/access_requirement.dart';
import 'package:omni_app/security/permissions/access_policy.dart';
import 'package:omni_app/security/session/session.dart';
import 'package:omni_app/security/session/session_controller.dart';

/// Vị trí một mục điều hướng là KẾT QUẢ TÍNH RA, không phải thứ module khai
/// báo. Module chỉ nói mình là loại việc gì; quyền của người dùng quyết định
/// phần còn lại.
class _FakeModule extends OmniModule {
  const _FakeModule(this._entries);

  final List<ModuleNavEntry> _entries;

  @override
  String get id => 'fake';

  @override
  String get title => 'Fake';

  @override
  List<ModuleRoute> routes() => const [];

  @override
  List<ModuleNavEntry> navEntries() => _entries;
}

ModuleNavEntry _entry({
  required String label,
  required NavArea area,
  NavWeight weight = NavWeight.primary,
  int order = 10,
  String permission = '',
}) => ModuleNavEntry(
  moduleId: label,
  label: label,
  routeName: 'route.$label',
  icon: Icons.circle_outlined,
  selectedIcon: Icons.circle,
  area: area,
  weight: weight,
  order: order,
  access: permission.isEmpty
      ? const AccessRequirement.open()
      : AccessRequirement.any([permission]),
);

ProviderContainer _containerFor(
  Set<String> permissions,
  List<ModuleNavEntry> entries,
) {
  return ProviderContainer(
    overrides: [
      modulesProvider.overrideWithValue([_FakeModule(entries)]),
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
  final all = [
    _entry(label: 'Việc', area: NavArea.work, permission: 'tasks.read'),
    _entry(
      label: 'Hộp thư',
      area: NavArea.communication,
      permission: 'inbox.read',
    ),
    _entry(
      label: 'Thông báo',
      area: NavArea.communication,
      weight: NavWeight.secondary,
      order: 20,
    ),
    _entry(
      label: 'Kênh',
      area: NavArea.communication,
      weight: NavWeight.secondary,
      order: 30,
      permission: 'channels.read',
    ),
    _entry(
      label: 'Khách',
      area: NavArea.sales,
      permission: 'crm.customers.read',
    ),
    _entry(
      label: 'Cơ hội',
      area: NavArea.sales,
      order: 20,
      permission: 'crm.sales_opportunities.read',
    ),
  ];

  test('thợ xưởng chỉ thấy việc của mình', () {
    final c = _containerFor({'tasks.read'}, all);
    addTearDown(c.dispose);

    expect(c.read(primaryNavEntriesProvider).map((e) => e.label), ['Việc']);
  });

  test('sales thấy ba mục, không thấy việc', () {
    final c = _containerFor({
      'inbox.read',
      'crm.customers.read',
      'crm.sales_opportunities.read',
    }, all);
    addTearDown(c.dispose);

    expect(c.read(primaryNavEntriesProvider).map((e) => e.label), [
      'Hộp thư',
      'Khách',
      'Cơ hội',
    ]);
  });

  test('người đủ quyền nhận thứ tự nhóm chức năng', () {
    final c = _containerFor({
      'tasks.read',
      'inbox.read',
      'channels.read',
      'crm.customers.read',
      'crm.sales_opportunities.read',
    }, all);
    addTearDown(c.dispose);

    // work → communication → sales. "Kênh" và "Thông báo" là secondary nên
    // không tranh tab, dù chúng đứng trong nhóm sớm hơn "Khách".
    expect(c.read(primaryNavEntriesProvider).map((e) => e.label), [
      'Việc',
      'Hộp thư',
      'Khách',
      'Cơ hội',
    ]);
  });

  test('mục secondary không bao giờ tranh tab', () {
    // Đây là toàn bộ lý do NavWeight tồn tại: "Kết nối kênh" cài một lần rồi
    // cả năm không mở, nhưng nó đứng trong nhóm communication nên xếp hạng
    // thuần theo nhóm sẽ đẩy nó lên tab, chiếm chỗ của "Khách hàng".
    final c = _containerFor({'channels.read'}, all);
    addTearDown(c.dispose);

    expect(c.read(primaryNavEntriesProvider), isEmpty);
    expect(
      c
          .read(directoryGroupsProvider)[NavArea.communication]!
          .map((e) => e.label),
      contains('Kênh'),
    );
  });

  test('danh bạ chứa cả primary lẫn secondary, gom theo nhóm', () {
    final c = _containerFor({'tasks.read', 'inbox.read'}, all);
    addTearDown(c.dispose);

    final groups = c.read(directoryGroupsProvider);

    expect(groups[NavArea.work]!.map((e) => e.label), ['Việc']);
    expect(groups[NavArea.communication]!.map((e) => e.label), [
      'Hộp thư',
      'Thông báo',
    ]);
    expect(
      groups.containsKey(NavArea.sales),
      isFalse,
      reason: 'nhóm rỗng thì không hiện tiêu đề nhóm',
    );
  });

  test('danh sách khai báo không phụ thuộc quyền', () {
    // Router dựng branch từ danh sách này. Nếu nó co giãn theo quyền, cấu trúc
    // branch đổi dưới chân người dùng và mọi tab mất vị trí cuộn.
    final none = _containerFor({}, all);
    final some = _containerFor({'tasks.read'}, all);
    addTearDown(none.dispose);
    addTearDown(some.dispose);

    expect(
      none.read(declaredNavEntriesProvider).length,
      some.read(declaredNavEntriesProvider).length,
    );
    expect(
      none.read(branchNavEntriesProvider).length,
      some.read(branchNavEntriesProvider).length,
    );
  });

  test('branch chỉ gồm mục primary', () {
    final c = _containerFor({}, all);
    addTearDown(c.dispose);

    expect(c.read(branchNavEntriesProvider).map((e) => e.label), [
      'Việc',
      'Hộp thư',
      'Khách',
      'Cơ hội',
    ]);
  });

  test('order chỉ so trong cùng nhóm, không phải số toàn cục', () {
    // "Khách" order 10 ở nhóm sales vẫn xếp sau "Thông báo" order 20 ở nhóm
    // communication — vì nhóm quyết trước. Đó là điều khiến module không phải
    // đàm phán một con số chung với module khác.
    final c = _containerFor({'inbox.read', 'crm.customers.read'}, all);
    addTearDown(c.dispose);

    final labels = c.read(visibleNavEntriesProvider).map((e) => e.label);

    expect(labels, ['Hộp thư', 'Thông báo', 'Khách']);
  });
}
