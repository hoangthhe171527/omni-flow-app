import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../modules/customers/routes.dart';
import '../../modules/plans/routes.dart';
import '../module/module_registry.dart';
import '../module/nav_destination.dart';

/// Tối đa 4 tab, cộng "Tất cả" là 5 — giới hạn của một thanh dưới còn bấm
/// trúng bằng ngón cái.
const maxTabs = 4;

/// Thanh tab mặc định theo bản thiết kế đã duyệt: Tổng quan · Hộp thư · Khách ·
/// Việc (+ "Tất cả" do shell tự thêm). Dùng khi người dùng chưa tự chọn, hoặc
/// mọi mục đã chọn đều bị thu quyền.
const tabRouteOrder = <String>[
  'dashboard.home',
  'inbox.list',
  CustomerRoutes.list,
  PlanRoutes.teams,
];

/// Khoá mới: khoá ghim cũ (`nav_pinned_routes`, gỡ ngày 09/10) lưu lựa chọn
/// theo một thanh mặc định đã khác, không hồi sinh nó.
const _key = 'nav_tab_routes';

/// Tab thực sự hiện ra.
///
/// Theo ĐÚNG thứ tự người dùng xếp ([saved]), chỉ giữ mục còn được phép — quyền
/// có thể bị thu, module có thể bị gỡ sau khi đã chọn; một tab dẫn tới màn
/// "không có quyền" tệ hơn không có tab. Lọc lúc đọc chứ không lúc ghi để quyền
/// được trả lại thì tab cũng quay lại. Không còn gì thì về [tabRouteOrder].
List<ModuleNavEntry> resolveTabs({
  required List<String>? saved,
  required List<ModuleNavEntry> allowed,
}) {
  final byRoute = {for (final e in allowed) e.routeName: e};
  final picked = [
    for (final r in {...?saved}) ?byRoute[r],
  ].take(maxTabs).toList();
  if (picked.isNotEmpty) return picked;

  return [for (final r in tabRouteOrder) ?byRoute[r]];
}

/// Thanh mặc định khi chưa tự chọn (giữ cho test và lối vào cũ).
List<ModuleNavEntry> orderTabs(List<ModuleNavEntry> allowed) =>
    resolveTabs(saved: null, allowed: allowed);

/// Lựa chọn của người dùng, có thứ tự. `null` = chưa từng chọn.
///
/// Lưu tại máy, không lên server: điện thoại riêng của thợ và máy tính bảng
/// dùng chung ngoài xưởng có cấu hình khác nhau là đúng. Đọc lỗi (test không
/// giả lập kho, kho hỏng) thì coi như chưa chọn — thanh mặc định vẫn hiện.
class TabPins extends AsyncNotifier<List<String>?> {
  @override
  Future<List<String>?> build() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getStringList(_key);
  }

  /// Ghi cả danh sách (màn "Sửa menu" luôn gửi danh sách đang thấy, đã lọc
  /// quyền). Rỗng thì về mặc định — thanh không bao giờ chỉ còn "Tất cả".
  Future<void> save(List<String> routes) async {
    final next = routes.take(maxTabs).toList();
    state = AsyncData(next.isEmpty ? null : next);
    final prefs = await SharedPreferences.getInstance();
    if (next.isEmpty) {
      await prefs.remove(_key);
    } else {
      await prefs.setStringList(_key, next);
    }
  }

  Future<void> reset() => save(const []);
}

final tabPinsProvider = AsyncNotifierProvider<TabPins, List<String>?>(
  TabPins.new,
);

final tabEntriesProvider = Provider<List<ModuleNavEntry>>((ref) {
  final saved = ref.watch(tabPinsProvider).valueOrNull;
  if (saved == null) return orderTabs(ref.watch(primaryNavEntriesProvider));

  return resolveTabs(
    saved: saved,
    allowed: ref.watch(pinnableNavEntriesProvider),
  );
});
