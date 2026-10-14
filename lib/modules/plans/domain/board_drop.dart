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
double? boardDropOrder(List<Task> column, Task moving, int index) {
  double? at(int i) =>
      i >= 0 && i < column.length && column[i].isPinned == moving.isPinned
      ? column[i].order
      : null;

  final before = at(index - 1);
  final after = at(index);
  if (before != null && after != null) return (before + after) / 2;
  if (after != null) return after - 1;
  if (before != null) return before + 1;

  return null;
}

/// Chỗ chèn theo con trỏ: số thẻ có tâm nằm TRÊN [pointerY].
int dropIndexFor(List<double> cardCentersY, double pointerY) =>
    cardCentersY.where((c) => c < pointerY).length;

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
