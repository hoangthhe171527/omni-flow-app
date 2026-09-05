import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../module/module_registry.dart';
import '../module/nav_destination.dart';

const _key = 'nav_pinned_routes';

/// Tối đa 4 tab, cộng "Tất cả" là 5 — giới hạn của một thanh dưới còn bấm được
/// bằng ngón cái.
const maxPinnedTabs = 4;

/// Giao giữa pin đã lưu và mục hiện được phép.
///
/// Lọc LÚC ĐỌC chứ không lúc ghi: quyền có thể bị thu hồi, module có thể bị gỡ,
/// và cả hai đều xảy ra sau khi người dùng đã ghim. Một tab dẫn tới màn báo
/// "không có quyền" tệ hơn là không có tab.
///
/// Thứ tự lấy theo [allowed] chứ không theo [saved]: người dùng chọn CÁI NÀO,
/// hệ thống xếp thứ tự. Bỏ phần xếp đi là bỏ được kéo-thả, mà kéo-thả thì luật
/// accessibility bắt phải kèm một cách thay thế không cần kéo.
List<String> resolvePins({
  required List<String> saved,
  required List<String> allowed,
}) {
  final wanted = saved.toSet();

  return allowed.where(wanted.contains).take(maxPinnedTabs).toList();
}

class PinnedTabs extends AsyncNotifier<List<String>> {
  @override
  Future<List<String>> build() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getStringList(_key) ?? const [];
  }

  /// Bật/tắt một mục. Bỏ qua khi đã đủ 4 và đang cố thêm mục thứ 5 — màn chọn
  /// tab tắt hẳn ô chưa chọn lúc đó, nên đây chỉ là lưới an toàn.
  Future<void> toggle(String routeName) async {
    final current = [...?state.valueOrNull];

    if (current.contains(routeName)) {
      current.remove(routeName);
    } else {
      if (current.length >= maxPinnedTabs) return;
      current.add(routeName);
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, current);
    state = AsyncData(current);
  }

  /// Về mặc định suy ra từ quyền.
  Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    state = const AsyncData([]);
  }
}

/// Lưu tại máy, không lên server: điện thoại riêng của thợ và máy tính bảng
/// dùng chung ngoài xưởng nên có cấu hình khác nhau là đúng.
final pinnedTabsProvider = AsyncNotifierProvider<PinnedTabs, List<String>>(
  PinnedTabs.new,
);

/// Tab thực sự hiện trên thanh dưới.
///
/// Pin của người dùng nếu có; nếu không thì 4 mục primary đầu tiên theo thứ tự
/// nhóm chức năng. Người chưa bao giờ mở màn chọn tab — tức gần như mọi thợ
/// xưởng — vẫn nhận đúng thứ mình cần ngay lần mở app đầu tiên.
final tabEntriesProvider = Provider<List<ModuleNavEntry>>((ref) {
  final primary = ref.watch(primaryNavEntriesProvider);
  final saved = ref.watch(pinnedTabsProvider).valueOrNull ?? const <String>[];

  final pinned = resolvePins(
    saved: saved,
    allowed: primary.map((e) => e.routeName).toList(),
  );

  if (pinned.isEmpty) return primary.take(maxPinnedTabs).toList();

  return primary.where((e) => pinned.contains(e.routeName)).toList();
});
