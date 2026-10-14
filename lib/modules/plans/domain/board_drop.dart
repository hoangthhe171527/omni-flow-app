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
