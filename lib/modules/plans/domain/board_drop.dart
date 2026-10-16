import 'dart:math' as math;

import '../../tasks/domain/task.dart';

/// `order` để gửi khi thả [moving] vào [column] tại chỗ chèn [index].
///
/// [column] là các thẻ cột đích KHÔNG gồm [moving]. Chỉ hàng xóm CÙNG nhóm
/// ghim với [moving] được tính: server xếp khối ghim riêng, nên một thẻ thường
/// thả ngay dưới khối ghim phải lấy `order` của thẻ thường đầu tiên − 1, không
/// phải trung bình với thẻ ghim.
///
/// null = không có hàng xóm hợp lệ (cột rỗng, hoặc chỉ có nhóm kia): chỉ gửi
/// `section_id`, để server tự xếp cuối.
///
/// Cũng null khi một hàng xóm dùng để tính CHƯA có `order` trên server
/// ([Task.hasOrder] false, như việc tạo từ app): Mongo xếp việc thiếu khoá
/// trước mọi số, nên coi nó là 0 rồi gửi 0 / −1 là thẻ nhảy chỗ khi tải lại.
double? boardDropOrder(List<Task> column, Task moving, int index) {
  Task? at(int i) =>
      i >= 0 && i < column.length && column[i].isPinned == moving.isPinned
      ? column[i]
      : null;

  final b = at(index - 1);
  final a = at(index);
  if ((b != null && !b.hasOrder) || (a != null && !a.hasOrder)) return null;
  final before = b?.order;
  final after = a?.order;
  if (before != null && after != null) return (before + after) / 2;
  if (after != null) return after - 1;
  if (before != null) return before + 1;

  return null;
}

/// Kẹp chỗ chèn [index] vào đúng vùng ghim của thẻ đang kéo trong [target]
/// (không gồm thẻ ấy; server xếp khối ghim lên đầu): thẻ ghim không xuống
/// dưới thẻ thường đầu tiên, thẻ thường không lên trên thẻ ghim cuối. Khớp
/// `clampToPinZone` của web — ô chỗ trống hiện đúng chỗ thẻ sẽ nằm, và
/// [boardDropOrder] luôn có hàng xóm cùng vùng.
int clampToPinZone(List<Task> target, bool movingPinned, int index) {
  final pinned = target.where((t) => t.isPinned).length;

  return movingPinned ? math.min(index, pinned) : math.max(index, pinned);
}

/// Chỗ chèn theo con trỏ: số thẻ có tâm nằm TRÊN [pointerY].
int dropIndexFor(List<double> cardCentersY, double pointerY) =>
    cardCentersY.where((c) => c < pointerY).length;

/// Chỗ chèn có vùng đệm [band]: chỉ rời [current] khi con trỏ vượt tâm thẻ
/// thêm ít nhất [band] theo chiều đi, để rung tay vài px không lật ô chỗ trống.
///
/// [current] null (chưa có chỗ chèn trong cột này) thì như [dropIndexFor].
/// Nhảy xa qua nhiều thẻ một lượt thì tới thẳng chỉ số đúng.
int dropIndexWithHysteresis(
  List<double> centers,
  double pointerY,
  int? current, {
  double band = 12,
}) {
  if (current == null) return dropIndexFor(centers, pointerY);
  final down = centers.where((c) => c + band < pointerY).length;
  final up = centers.where((c) => c - band < pointerY).length;
  if (current < down) return down;
  if (current > up) return up;

  return current;
}

/// Chỗ chèn trong cột đích ĐẦY ĐỦ [full] (không gồm thẻ đang kéo), khi người
/// dùng chỉ thấy [visible] (đang lọc / tìm) và chọn chỗ chèn [index] trong đó.
///
/// Chèn NGAY SAU thẻ thấy được phía trên (giữa nó và thẻ kế tiếp trong cột đầy
/// đủ), nên không nhảy qua thẻ ẩn nằm ngay sau đó. Ở đầu cột ([index] = 0) thì
/// chèn ngay TRƯỚC thẻ thấy được đầu tiên; không thấy thẻ nào thì xuống cuối.
int fullInsertIndex(List<Task> full, List<Task> visible, int index) {
  if (visible.isEmpty) return full.length;
  if (index > 0) {
    final above = visible[(index - 1).clamp(0, visible.length - 1)];
    final i = full.indexWhere((t) => t.id == above.id);

    return i < 0 ? full.length : i + 1;
  }
  final i = full.indexWhere((t) => t.id == visible.first.id);

  return i < 0 ? 0 : i;
}
