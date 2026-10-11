import 'package:flutter/material.dart';

import 'menu_sheet.dart';

/// Mục của menu việc (`TaskMenu.dc.html`).
///
/// Mục Nhóm 2 (Người theo dõi, Ghim, Khoá) chỉ có khi API gửi khoá tương ứng
/// (`ApiCapability.taskFollow` / `taskPin` / `taskLock` trong phiên). Nhắc việc,
/// Sao chép công việc, Sao chép liên kết thuộc Task 11.
enum TaskMenuAction {
  labels,
  followers,
  pin,
  unpin,
  rename,
  move,
  lock,
  unlock,
  archive,
  unarchive,
  delete,
}

/// Ba nhóm của menu việc theo quyền; nhóm rỗng bị bỏ. Rỗng hết = ẩn ⋯.
///
/// - Nhóm 1: "Nhãn màu" ([canLabels]), "Người theo dõi" ([canFollow]),
///   "Ghim lên đầu cột" / "Bỏ ghim" ([canPin], [pinned]), "Đổi tên việc"
///   (người giao việc — năng lực giữ từ ⋯ cũ, bản mẫu không có).
/// - Nhóm 2: "Chuyển sang nhóm / kế hoạch khác" (người giao việc).
/// - Nhóm 3: "Khoá công việc" / "Mở khoá" ([canLock]), "Lưu trữ" / "Bỏ lưu
///   trữ", "Xoá công việc" (người giao việc).
///
/// Việc đã khoá ([locked]): server trả 423 cho mọi lượt sửa, nên chỉ còn
/// những mục server vẫn cho (Người theo dõi) và "Mở khoá".
List<List<TaskMenuAction>> taskMenuGroups({
  required bool canLabels,
  required bool isAssigner,
  required bool archived,
  bool canFollow = false,
  bool canPin = false,
  bool pinned = false,
  bool canLock = false,
  bool locked = false,
}) {
  final edit = !locked;

  return [
    [
      if (canLabels && edit) TaskMenuAction.labels,
      if (canFollow) TaskMenuAction.followers,
      if (canPin && edit) pinned ? TaskMenuAction.unpin : TaskMenuAction.pin,
      if (isAssigner && edit) TaskMenuAction.rename,
    ],
    [if (isAssigner && edit) TaskMenuAction.move],
    [
      if (canLock) locked ? TaskMenuAction.unlock : TaskMenuAction.lock,
      if (isAssigner && edit)
        archived ? TaskMenuAction.unarchive : TaskMenuAction.archive,
      if (isAssigner && edit) TaskMenuAction.delete,
    ],
  ].where((g) => g.isNotEmpty).toList();
}

/// Mở menu việc; trả mục đã chọn hoặc null khi đóng. [followerCount] là số
/// bên phải "Người theo dõi".
Future<TaskMenuAction?> showTaskMenuSheet(
  BuildContext context, {
  required List<List<TaskMenuAction>> groups,
  int followerCount = 0,
}) => showDetailMenuSheet<TaskMenuAction>(
  context,
  semanticsLabel: 'Tuỳ chọn công việc',
  groups: [
    for (final g in groups) [for (final a in g) _item(a, followerCount)],
  ],
);

DetailMenuItem<TaskMenuAction> _item(TaskMenuAction a, int followers) =>
    switch (a) {
      TaskMenuAction.labels => DetailMenuItem(
        value: a,
        icon: Icons.sell_outlined,
        label: 'Nhãn màu',
      ),
      TaskMenuAction.followers => DetailMenuItem(
        value: a,
        icon: Icons.visibility_outlined,
        label: 'Người theo dõi',
        trailing: '$followers',
      ),
      TaskMenuAction.pin => DetailMenuItem(
        value: a,
        icon: Icons.push_pin_outlined,
        label: 'Ghim lên đầu cột',
      ),
      TaskMenuAction.unpin => DetailMenuItem(
        value: a,
        icon: Icons.push_pin_rounded,
        label: 'Bỏ ghim',
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
      TaskMenuAction.lock => DetailMenuItem(
        value: a,
        icon: Icons.lock_outline_rounded,
        label: 'Khoá công việc',
      ),
      TaskMenuAction.unlock => DetailMenuItem(
        value: a,
        icon: Icons.lock_open_outlined,
        label: 'Mở khoá',
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
