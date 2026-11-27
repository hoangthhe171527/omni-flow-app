import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/module/module_registry.dart';
import '../../core/storage/preferences_store.dart';
import '../../core/storage/storage_keys.dart';
import '../../core/module/module_route.dart';
import '../../core/module/nav_destination.dart';
import '../../security/session/session_controller.dart';
import 'app_manifest.dart';

/// Khung ứng dụng của app điện thoại (omni-flow `docs/KE_HOACH_TACH_UNG_DUNG.md`
/// §4, quyết định 2026-11-11): chia các mục người dùng thấy được vào ứng dụng
/// theo bản khai báo của API. Cùng luật với web `src/config/app-shell.ts`.

/// Màn của app cho một khoá mục trong bản khai báo.
///
/// Mục đã là [ModuleNavEntry] chỉ cần tên route — nhãn, icon, quyền, cờ, huy
/// hiệu lấy từ mục đó. Màn chưa có mục điều hướng (màn con của Kho) khai thêm
/// nhãn và icon; quyền lấy từ chính [ModuleRoute].
class AppItemSpec {
  const AppItemSpec(
    this.routeName, {
    this.label,
    this.icon,
    this.selectedIcon,
    this.capabilities = const [],
    this.shellOnly = false,
  });

  final String routeName;
  final String? label;
  final IconData? icon;
  final IconData? selectedIcon;

  /// Khả năng API phải có (`Session.apiSupports`) — thiếu thì mục ẩn.
  final List<String> capabilities;

  /// Lối vào thứ hai của màn thuộc ứng dụng khác (`sales_stock`): không đủ để
  /// một ứng dụng hiện ra.
  final bool shellOnly;
}

const _inventory = 'inventory';

/// Khoá bản khai báo → màn của app. Khoá không có ở đây (Báo giá, Tài liệu,
/// Lịch nhắc…) là màn app chưa có: bỏ qua, không vẽ. Tên route chép chuỗi để
/// tầng app không phải import route của từng module.
const appItemSpecs = <String, AppItemSpec>{
  // Bàn làm việc
  'dashboard': AppItemSpec('dashboard.home'),
  'sales_actions': AppItemSpec('tasks.list'),
  'notifications': AppItemSpec('notifications.centre'),
  // Bán hàng
  'inbox': AppItemSpec('inbox.list'),
  'customers': AppItemSpec('customers.list'),
  'opportunities': AppItemSpec('opportunities.pipeline'),
  // Đơn hàng theo cây (TNP_DON_HANG_THEO_CAY §6): danh sách, tạo đơn, ghi thu.
  'orders': AppItemSpec('inventory.orders'),
  'sales_stock': AppItemSpec(
    'inventory.stock',
    capabilities: [_inventory],
    shellOnly: true,
  ),
  // Kho
  'inventory_lots': AppItemSpec('inventory.lots', capabilities: [_inventory]),
  'inventory_stock': AppItemSpec('inventory.stock', capabilities: [_inventory]),
  'inventory_suppliers': AppItemSpec(
    'inventory.suppliers',
    label: 'Nhà cung cấp',
    icon: LucideIcons.store,
    selectedIcon: LucideIcons.store,
    capabilities: [_inventory, 'inventory.suppliers'],
  ),
  'inventory_reservations': AppItemSpec(
    'inventory.reservations',
    label: 'Đang giữ',
    icon: LucideIcons.bookmark,
    selectedIcon: LucideIcons.bookmark,
    capabilities: [_inventory, 'inventory.reservations'],
  ),
  'inventory_catalog': AppItemSpec(
    'inventory.catalog',
    label: 'Danh mục hàng',
    icon: LucideIcons.shapes,
    selectedIcon: LucideIcons.shapes,
    capabilities: [_inventory, 'inventory.products'],
  ),
  'inventory_delivered': AppItemSpec(
    'inventory.delivered',
    label: 'Hàng đã giao',
    icon: LucideIcons.clipboardCheck,
    selectedIcon: LucideIcons.clipboardCheck,
    capabilities: [_inventory, 'inventory.returns'],
  ),
  'inventory_counts': AppItemSpec(
    'inventory.counts',
    label: 'Kiểm kê',
    icon: LucideIcons.clipboardCheck,
    selectedIcon: LucideIcons.clipboardCheck,
    capabilities: [_inventory, 'inventory.counts'],
  ),
  // Công việc
  'projects': AppItemSpec('plans.teams'),
  'work_reports': AppItemSpec('plans.timeline'),
  'archived_tasks': AppItemSpec('plans.archived'),
  // Tài chính
  'finance_expenses': AppItemSpec('finance.expenses'),
  'finance_summary': AppItemSpec('finance.summary'),
  'finance_catalog': AppItemSpec('finance.catalog'),
  // Hệ thống
  'channels': AppItemSpec('channels.list'),
  'staff': AppItemSpec('team.list'),
  // Nhân sự (nhan-su-kpi/00 §8). `hr_payroll`, `hr_staff`, `hr_settings` là
  // màn web — app bỏ qua.
  'hr_clock': AppItemSpec('hr.clock'),
  'hr_timesheet': AppItemSpec('hr.timesheet'),
  'hr_requests': AppItemSpec('hr.requests'),
  'hr_kpi': AppItemSpec('hr.kpi'),
  'hr_payslip': AppItemSpec('hr.payslip'),
  'hr_workshop_today': AppItemSpec('hr.workshop'),
  'hr_approvals': AppItemSpec('hr.approvals'),
};

/// Nhãn ngắn trên thanh tab (rà soát 12/11/2026): ô tab rộng ~70px chỉ vừa
/// ~9 ký tự ở cỡ chữ của thanh. Nhãn dài từng bị FittedBox thu nhỏ → một thanh
/// ba cỡ chữ. Tên đầy đủ vẫn dùng cho tiêu đề màn, sheet "Thêm" và nhãn đọc
/// màn hình. Test `tab_labels_test.dart` ghim mọi nhãn tab ≤ [maxTabLabelLength].
const tabLabels = <String, String>{
  'inventory.lots': 'Sắp về',
  'inventory.suppliers': 'NCC',
  'inventory.catalog': 'Danh mục',
  'inventory.delivered': 'Đã giao',
  'finance.expenses': 'Sổ chi',
  'finance.summary': 'Tổng hợp',
  'finance.catalog': 'Danh mục',
  'channels.list': 'Kênh',
  'tasks.list': 'Việc',
  'plans.archived': 'Lưu trữ',
  'settings.notifications': 'Thông báo',
  'settings.permissions': 'Quyền',
  // Nhân sự (spec 03 §5.1): "Chấm công", "Công", "Đơn từ", "Lương".
  'hr.clock': 'Chấm công',
  'hr.timesheet': 'Công',
  'hr.requests': 'Đơn từ',
  'hr.payslip': 'Lương',
  'hr.kpi': 'Thưởng',
  'hr.workshop': 'Xưởng',
  'hr.approvals': 'Duyệt',
};

const maxTabLabelLength = 9;

/// Nhãn của một mục trên thanh tab / thanh bên.
String tabLabelOf(ModuleNavEntry entry) =>
    tabLabels[entry.routeName] ?? entry.label;

/// Khoá của Bàn làm việc — trang mở đầu, không phải ứng dụng trong bản khai báo.
const homeAppKey = 'home';

/// Số mục trên thanh dưới của một ứng dụng; còn lại vào "Thêm".
const appTabCount = 4;

class ShellItem {
  const ShellItem({
    required this.key,
    required this.entry,
    this.shellOnly = false,
  });

  final String key;

  /// Nhãn, icon, quyền, huy hiệu và route ([ModuleNavEntry.routeName] là tên
  /// route GỐC của màn).
  final ModuleNavEntry entry;
  final bool shellOnly;
}

class ShellApp {
  const ShellApp({
    required this.key,
    required this.name,
    required this.icon,
    required this.items,
    this.reports = const [],
  });

  final String key;
  final String name;
  final IconData icon;

  /// Mục chính theo thứ tự bản khai báo.
  final List<ShellItem> items;

  /// Mục `group: reports` — chỉ trong "Thêm", dưới nhãn "Báo cáo".
  final List<ShellItem> reports;

  /// Thanh dưới có tối đa [appTabCount] + 1 chỗ (4 mục + nút "Thêm"). Nếu
  /// tổng số mục ≤ [appTabCount] + 1 (tức phần tràn chỉ có 0 hoặc 1 mục) thì
  /// hiện thẳng tất cả lên thanh, không sinh nút "Thêm" chỉ để chứa 1 mục.
  bool get _fitsInBar => all.length <= appTabCount + 1;

  List<ShellItem> get tabs =>
      _fitsInBar ? all : items.take(appTabCount).toList();

  /// "Thêm": mục chính còn lại (chỉ có khi menu dài hơn [appTabCount]).
  List<ShellItem> get more =>
      _fitsInBar ? const [] : items.skip(appTabCount).toList();

  bool get hasMore => !_fitsInBar && (more.isNotEmpty || reports.isNotEmpty);

  List<ShellItem> get all => [...items, ...reports];

  /// Trang mở ra khi bấm ô của ứng dụng.
  ShellItem? get first => all.isEmpty ? null : all.first;

  bool contains(String routeName) =>
      all.any((i) => i.entry.routeName == routeName);

  /// Ứng dụng chỉ mở được khi có ít nhất một mục thấy được MÀ mục đó đòi quyền
  /// và không phải lối vào thứ hai (luật `opensApp` của web): người chỉ có
  /// quyền Kho không thấy Bán hàng chỉ vì "Tồn kho", không thấy Bàn làm việc
  /// chỉ vì "Thông báo".
  bool get opens => all.any((i) => !i.shellOnly && !i.entry.access.isOpen);
}

class AppShellLayout {
  const AppShellLayout({required this.home, required this.apps});

  final ShellApp home;

  /// Ứng dụng bật và mở được, theo `order`.
  final List<ShellApp> apps;

  /// Các ô của màn Chọn ứng dụng, Bàn làm việc đứng đầu.
  List<ShellApp> get entries => home.opens ? [home, ...apps] : apps;

  ShellApp? byKey(String? key) {
    for (final app in entries) {
      if (app.key == key) return app;
    }
    return null;
  }

  /// Ứng dụng đang mở: ứng dụng vừa chọn nếu nó chứa màn đang xem; không thì
  /// ứng dụng đầu tiên chứa màn đó (ưu tiên nơi màn là mục chính, không phải
  /// lối vào thứ hai); không màn nào khớp thì ứng dụng vừa chọn / ô đầu.
  ShellApp? resolve({required String? currentKey, String? routeName}) {
    final current = byKey(currentKey);
    if (routeName == null) return current ?? _firstOrNull(entries);
    if (current != null && current.contains(routeName)) return current;
    for (final app in entries) {
      if (app.all.any((i) => i.entry.routeName == routeName && !i.shellOnly)) {
        return app;
      }
    }
    for (final app in entries) {
      if (app.contains(routeName)) return app;
    }
    return current ?? _firstOrNull(entries);
  }
}

ShellApp? _firstOrNull(List<ShellApp> list) => list.isEmpty ? null : list.first;

IconData appIconOf(String key) => switch (key) {
  homeAppKey => LucideIcons.monitor,
  'sales' => LucideIcons.shoppingBag,
  'stock' => LucideIcons.package,
  'work' => LucideIcons.squareKanban,
  'finance' => LucideIcons.wallet,
  'hr' => LucideIcons.idCard,
  'system' => LucideIcons.settings,
  _ => LucideIcons.layoutGrid,
};

/// Dựng khung từ bản khai báo + mục điều hướng — hàm thuần để kiểm.
///
/// - [declared]: mọi mục module khai báo (không lọc); [visible]: mục phiên
///   được thấy (quyền + cờ tính năng). [routes]: route theo tên, cho màn chưa
///   có mục điều hướng. [allowed] kiểm quyền của route đó; [supports] kiểm
///   khả năng API.
/// - Mục module khai báo mà bản khai báo không xếp vào đâu (app đi trước API)
///   không biến mất: vào Bàn làm việc, sau các mục `home` (như web).
AppShellLayout buildAppShellLayout({
  required AppManifest manifest,
  required List<ModuleNavEntry> declared,
  required List<ModuleNavEntry> visible,
  required Map<String, ModuleRoute> routes,
  required bool Function(ModuleRoute route) allowed,
  required bool Function(String capability) supports,
}) {
  final declaredByRoute = {for (final e in declared) e.routeName: e};
  final visibleRoutes = {for (final e in visible) e.routeName};

  ShellItem? itemFor(String key) {
    final spec = appItemSpecs[key];
    if (spec == null) return null;
    if (!spec.capabilities.every(supports)) return null;
    final declaredEntry = declaredByRoute[spec.routeName];
    if (declaredEntry != null) {
      if (!visibleRoutes.contains(spec.routeName)) return null;
      return ShellItem(
        key: key,
        entry: declaredEntry,
        shellOnly: spec.shellOnly,
      );
    }
    final route = routes[spec.routeName];
    if (route == null || !allowed(route)) return null;
    return ShellItem(
      key: key,
      shellOnly: spec.shellOnly,
      entry: ModuleNavEntry(
        moduleId: 'apps',
        label: spec.label ?? key,
        icon: spec.icon ?? LucideIcons.circle,
        selectedIcon: spec.selectedIcon ?? spec.icon ?? LucideIcons.circle,
        routeName: spec.routeName,
        area: NavArea.work,
        access: route.access,
      ),
    );
  }

  List<ShellItem> pick(Iterable<String> keys) => [
    for (final k in keys) ?itemFor(k),
  ];

  // Màn mà bản khai báo đã xếp chỗ — kể cả trong ứng dụng công ty tắt (tắt
  // thì ẩn theo ứng dụng, không trôi về Bàn làm việc).
  final placed = <String>{
    for (final k in [
      ...manifest.home,
      for (final a in manifest.apps)
        for (final i in a.items) i.key,
    ])
      ?appItemSpecs[k]?.routeName,
  };

  final apps = [
    for (final app in [...manifest.apps]..sort((a, b) => a.order - b.order))
      if (app.enabled)
        ShellApp(
          key: app.key,
          name: app.name,
          icon: appIconOf(app.key),
          items: pick([
            for (final i in app.items)
              if (!i.isReport && !i.isSettings) i.key,
          ]),
          reports: pick([
            for (final i in app.items)
              if (i.isReport) i.key,
          ]),
        ),
  ].where((a) => a.opens).toList();

  final home = ShellApp(
    key: homeAppKey,
    name: 'Bàn làm việc',
    icon: appIconOf(homeAppKey),
    items: manifest.homeEnabled
        ? [
            ...pick(manifest.home),
            for (final e in visible)
              if (isTabEligible(e) && !placed.contains(e.routeName))
                ShellItem(key: e.routeName, entry: e),
          ]
        : const [],
  );

  return AppShellLayout(home: home, apps: apps);
}

/// Khung của phiên hiện tại; `null` = như cũ (cờ tắt, API cũ, đang tải, lỗi).
final appShellLayoutProvider = Provider<AppShellLayout?>((ref) {
  final manifest = ref.watch(appManifestProvider).valueOrNull;
  if (manifest == null || !manifest.shell) return null;
  final session = ref.watch(sessionProvider);
  return buildAppShellLayout(
    manifest: manifest,
    declared: ref.watch(declaredNavEntriesProvider),
    visible: ref.watch(visibleNavEntriesProvider),
    routes: {for (final r in ref.watch(moduleRoutesProvider)) r.name: r},
    allowed: (route) => route.access.isSatisfiedBy(session.policy),
    supports: session.apiSupports,
  );
});

/// Ứng dụng người dùng vừa chọn trong phiên này; đổi công ty là về trống.
/// Lần mở app sau dùng [LastAppStore] (vào thẳng lại ứng dụng dùng lần trước).
final currentAppKeyProvider = StateProvider<String?>((ref) {
  ref.watch(sessionProvider.select((s) => s.tenant?.id));
  return null;
});

/// Nhớ ứng dụng mở lần cuối theo người dùng + công ty (duyệt 27/11/2026: sau
/// đăng nhập vào lại ứng dụng dùng lần trước; chưa từng mở thì màn Ứng dụng).
class LastAppStore {
  LastAppStore(this._prefs, this._userId, this._tenantId);

  /// Lấy khi cần (chưa có người dùng + công ty thì không đụng tới bộ nhớ).
  final PreferencesStore Function() _prefs;
  final String? _userId;
  final String? _tenantId;

  String? get _key => (_userId == null || _tenantId == null)
      ? null
      : '${StorageKeys.lastApp}.$_userId.$_tenantId';

  String? read() {
    final key = _key;
    return key == null ? null : _prefs().getString(key);
  }

  Future<void> write(String appKey) async {
    final key = _key;
    if (key == null) return;
    await _prefs().setString(key, appKey);
  }
}

final lastAppStoreProvider = Provider<LastAppStore>((ref) {
  final session = ref.watch(sessionProvider);
  return LastAppStore(
    () => ref.read(preferencesStoreProvider),
    session.user?.id,
    session.tenant?.id,
  );
});

/// Tiền tố đường dẫn của bản sao route làm gốc thanh dưới (xem
/// [appTabCloneRoutesProvider]).
const appTabPathPrefix = '/a';

String appTabCloneName(String routeName) => 'apps.tab.$routeName';

/// Màn của bản khai báo chưa là branch (màn con của Kho mở toàn màn): router
/// dựng thêm một branch cho mỗi màn, gốc là BẢN SAO route với tên/đường dẫn
/// riêng ([appTabCloneName], [appTabPathPrefix]). Route gốc giữ nguyên nên khi
/// cờ tắt mọi lối vào cũ (nút trên Tồn kho, Hàng sắp về) y như trước.
///
/// Tính từ bảng tĩnh và danh sách route — không theo phiên — để cấu trúc
/// router không đổi khi quyền hay cờ đổi.
final appTabCloneRoutesProvider = Provider<List<String>>((ref) {
  final branchNames = {
    for (final e in ref.watch(branchNavEntriesProvider)) e.routeName,
  };
  final routeNames = {for (final r in ref.watch(moduleRoutesProvider)) r.name};
  return [
    for (final name in {for (final s in appItemSpecs.values) s.routeName})
      if (!branchNames.contains(name) && routeNames.contains(name)) name,
  ];
});

/// Tên route để `goNamed` tới màn [routeName] trong khung ứng dụng: bản sao
/// nếu màn cần branch riêng, không thì chính nó.
String appTabRouteName(String routeName, List<String> clones) =>
    clones.contains(routeName) ? appTabCloneName(routeName) : routeName;
