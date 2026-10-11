import 'package:flutter/material.dart';

import 'menu_sheet.dart';

/// Mục của menu việc (`TaskMenu.dc.html`).
///
/// Nhóm 2 (Người theo dõi, Nhắc việc, Sao chép công việc, Sao chép liên kết,
/// Khoá công việc) chưa có khoá API nên KHÔNG có mục nào ở đây.
enum TaskMenuAction { labels, rename, move, archive, unarchive, delete }

/// Ba nhóm của menu việc theo quyền; nhóm rỗng bị bỏ. Rỗng hết = ẩn ⋯.
///
/// - Nhóm 1: "Nhãn màu" (ghi việc + đọc được danh mục nhãn), "Đổi tên việc"
///   (người giao việc — năng lực giữ từ ⋯ cũ, bản mẫu không có).
/// - Nhóm 2: "Chuyển sang nhóm / kế hoạch khác" (người giao việc).
/// - Nhóm 3: "Lưu trữ" / "Bỏ lưu trữ", "Xoá công việc" (người giao việc).
List<List<TaskMenuAction>> taskMenuGroups({
  required bool canLabels,
  required bool isAssigner,
  required bool archived,
}) => [
  [if (canLabels) TaskMenuAction.labels, if (isAssigner) TaskMenuAction.rename],
  [if (isAssigner) TaskMenuAction.move],
  [
    if (isAssigner)
      archived ? TaskMenuAction.unarchive : TaskMenuAction.archive,
    if (isAssigner) TaskMenuAction.delete,
  ],
].where((g) => g.isNotEmpty).toList();

/// Mở menu việc; trả mục đã chọn hoặc null khi đóng.
Future<TaskMenuAction?> showTaskMenuSheet(
  BuildContext context, {
  required List<List<TaskMenuAction>> groups,
}) => showDetailMenuSheet<TaskMenuAction>(
  context,
  semanticsLabel: 'Tuỳ chọn công việc',
  groups: [
    for (final g in groups) [for (final a in g) _item(a)],
  ],
);

DetailMenuItem<TaskMenuAction> _item(TaskMenuAction a) => switch (a) {
  TaskMenuAction.labels => DetailMenuItem(
    value: a,
    icon: Icons.sell_outlined,
    label: 'Nhãn màu',
  ),
  TaskMenuAction.rename => DetailMenuItem(
    value: a,
    icon: Icons.edit_outlined,
    label: 'Đổi tên việc',
  ),
  TaskMenuAction.move => DetailMenuItem(
    value: a,
    icon: Icons.arrow_forward_rounded,
    label: 'Chuyển sang nhóm / kế hoạch khác',
  ),
  TaskMenuAction.archive => DetailMenuItem(
    value: a,
    icon: Icons.archive_outlined,
    label: 'Lưu trữ',
  ),
  TaskMenuAction.unarchive => DetailMenuItem(
    value: a,
    icon: Icons.unarchive_outlined,
    label: 'Bỏ lưu trữ',
  ),
  TaskMenuAction.delete => DetailMenuItem(
    value: a,
    icon: Icons.delete_outline,
    label: 'Xoá công việc',
    danger: true,
  ),
};
