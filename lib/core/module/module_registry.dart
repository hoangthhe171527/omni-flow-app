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

/// Mọi mục đã khai báo, không lọc quyền, thứ tự ổn định.
///
/// Router dựng branch từ danh sách này, nên nó KHÔNG được co giãn theo quyền —
/// cấu trúc branch đổi dưới chân người dùng là mọi tab mất vị trí cuộn và form
/// đang gõ dở.
///
/// Sắp theo (nhóm, order trong nhóm): nhóm quyết trước, nên `order` chỉ cần
/// đúng trong phạm vi module tự biết.
final declaredNavEntriesProvider = Provider<List<ModuleNavEntry>>((ref) {
  final entries =
      <ModuleNavEntry>[
        for (final module in ref.watch(modulesProvider)) ...module.navEntries(),
      ]..sort((a, b) {
        final byArea = a.area.index.compareTo(b.area.index);

        return byArea != 0 ? byArea : a.order.compareTo(b.order);
      });

  return entries;
});

/// Mục thành branch của shell — mọi mục primary, KHÔNG lọc quyền.
///
/// Router và shell cùng đọc provider này để đánh chỉ số branch. Hai nơi tự lọc
/// lấy là hai nơi có thể lệch nhau, và lệch chỉ số branch nghĩa là bấm tab này
/// ra màn kia.
final branchNavEntriesProvider = Provider<List<ModuleNavEntry>>((ref) {
  return ref
      .watch(declaredNavEntriesProvider)
      .where((entry) => entry.weight == NavWeight.primary)
      .toList();
});

/// Mục phiên hiện tại được phép thấy. Tính lại khi quyền đổi (chuyển tenant,
/// hoặc vai trò được sửa và nạp lại).
final visibleNavEntriesProvider = Provider<List<ModuleNavEntry>>((ref) {
  final policy = ref.watch(accessProvider);

  return ref
      .watch(declaredNavEntriesProvider)
      .where((entry) => entry.access.isSatisfiedBy(policy))
      .toList();
});

/// Mục đủ tư cách lên tab với quyền hiện tại, đã sắp theo thứ tự ưu tiên.
final primaryNavEntriesProvider = Provider<List<ModuleNavEntry>>((ref) {
  return ref
      .watch(visibleNavEntriesProvider)
      .where((entry) => entry.weight == NavWeight.primary)
      .toList();
});

/// Danh bạ "Tất cả", gom theo nhóm. Nhóm không còn mục nào thì biến mất hẳn —
/// một tiêu đề nhóm trống trông như lỗi tải dữ liệu.
final directoryGroupsProvider = Provider<Map<NavArea, List<ModuleNavEntry>>>((
  ref,
) {
  final grouped = <NavArea, List<ModuleNavEntry>>{};
  for (final entry in ref.watch(visibleNavEntriesProvider)) {
    grouped.putIfAbsent(entry.area, () => []).add(entry);
  }

  return grouped;
});

/// Every permission slug the app knows about, by module. Powers the
/// "Quyền của tôi" diagnostics screen.
final declaredPermissionsProvider = Provider<Map<String, List<String>>>((ref) {
  return {
    for (final module in ref.watch(modulesProvider))
      module.title: module.permissions,
  };
});
