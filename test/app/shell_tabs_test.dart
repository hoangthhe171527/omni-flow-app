import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/app/shell/app_shell.dart';
import 'package:omni_app/bootstrap.dart';
import 'package:omni_app/core/module/module_registry.dart';
import 'package:omni_app/core/nav/pinned_tabs.dart';
import 'package:omni_app/security/permissions/access_policy.dart';
import 'package:omni_app/security/session/session.dart';
import 'package:omni_app/security/session/session_controller.dart';

/// `AppShell` cần một `StatefulNavigationShell` thật, thứ chỉ go_router dựng
/// được, nên không dựng widget đó ở đây. Kiểm phần tính toán — thứ thật sự có
/// thể sai — ở tầng provider.
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
  test('trần tab là 4, cộng "Tất cả" là 5', () {
    // 5 là giới hạn một thanh dưới còn bấm được bằng ngón cái.
    expect(AppShell.maxTabs, 4);
    expect(
      maxPinnedTabs,
      AppShell.maxTabs,
      reason: 'lệch nhau là người dùng ghim được 5 mục rồi chỉ thấy 4',
    );
  });

  test('mọi tab đều tìm thấy chính mình trong danh sách branch', () {
    // Nếu một tab không tìm thấy chính mình, indexOf trả -1 và bấm vào nó sẽ
    // nhảy sang branch cuối — bấm "Khách hàng" ra màn "Tất cả".
    final container = _containerFor({
      'tasks.read',
      'inbox.read',
      'crm.customers.read',
      'crm.sales_opportunities.read',
    });
    addTearDown(container.dispose);

    final branches = container.read(branchNavEntriesProvider);

    for (final tab in container.read(primaryNavEntriesProvider)) {
      expect(branches.indexOf(tab), isNonNegative, reason: tab.label);
    }
  });

  test('chỉ số branch không đổi khi quyền đổi', () {
    // Đây là điều giữ cho vị trí cuộn và form đang gõ dở của từng tab sống sót.
    final worker = _containerFor({'tasks.read'});
    final manager = _containerFor({
      'tasks.read',
      'inbox.read',
      'crm.customers.read',
    });
    addTearDown(worker.dispose);
    addTearDown(manager.dispose);

    expect(
      worker.read(branchNavEntriesProvider).map((e) => e.routeName),
      manager.read(branchNavEntriesProvider).map((e) => e.routeName),
    );
  });

  test('người không có quyền nào không có tab nào', () {
    final container = _containerFor({});
    addTearDown(container.dispose);

    expect(container.read(primaryNavEntriesProvider), isEmpty);
    // Nhưng branch vẫn còn nguyên — nếu không, cấu trúc router sẽ đổi theo
    // quyền và mọi chỉ số lệch đi.
    expect(container.read(branchNavEntriesProvider), isNotEmpty);
  });
}
