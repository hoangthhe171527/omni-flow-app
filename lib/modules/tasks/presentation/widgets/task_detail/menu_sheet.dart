import 'package:flutter/material.dart';

import '../../../../../design/components/components.dart';
import '../../../../../design/tokens/tokens.dart';

/// Một mục `.op` của sheet chia nhóm.
class DetailMenuItem<T> {
  const DetailMenuItem({
    required this.value,
    required this.icon,
    required this.label,
    this.danger = false,
    this.trailing,
  });

  final T value;
  final IconData icon;
  final String label;

  /// Đỏ `#B42318` (Xoá).
  final bool danger;

  /// Chữ nhỏ bên phải (số đếm).
  final String? trailing;
}

/// Sheet chia nhóm của chi tiết việc (`TaskDetail.dc.html` `isMenu`): mỗi nhóm
/// là một `OmniGroupSection` (thẻ trắng bo 18, vạch thụt), dòng icon một tông,
/// Xoá đỏ. Trả `value` của mục đã chọn.
///
/// Nhóm rỗng bị bỏ; [title] (16 w600) là dòng đầu khi có.
Future<T?> showDetailMenuSheet<T>(
  BuildContext context, {
  required String semanticsLabel,
  required List<List<DetailMenuItem<T>>> groups,
  String? title,
}) => showOmniViecSheet<T>(
  context: context,
  builder: (_) => DetailMenuSheet<T>(
    semanticsLabel: semanticsLabel,
    title: title,
    groups: [
      for (final g in groups)
        if (g.isNotEmpty) g,
    ],
  ),
);

/// Biến thể menu nhanh neo vào nút ⋮. Dùng cho một thực thể cụ thể ngay trên
/// màn (ví dụ việc con); các sheet form/lịch/xác nhận vẫn mở riêng sau khi
/// người dùng chọn hành động.
Future<T?> showDetailAnchoredMenu<T>(
  BuildContext context, {
  required Rect anchor,
  required String semanticsLabel,
  required List<List<DetailMenuItem<T>>> groups,
  String? title,
  Key? menuKey,
}) {
  final visible = [
    for (final group in groups)
      if (group.isNotEmpty) group,
  ];
  return showOmniAnchoredMenu<T>(
    context: context,
    anchor: anchor,
    width: 288,
    menuKey: menuKey,
    semanticsLabel: semanticsLabel,
    builder: (menuContext) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (title case final text?)
          Container(
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            alignment: Alignment.centerLeft,
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: OmniType.bodyStrong.copyWith(
                color: Theme.of(menuContext).colorScheme.onSurface,
              ),
            ),
          ),
        for (var groupIndex = 0; groupIndex < visible.length; groupIndex++)
          for (
            var itemIndex = 0;
            itemIndex < visible[groupIndex].length;
            itemIndex++
          )
            OmniAnchoredMenuItem(
              icon: visible[groupIndex][itemIndex].icon,
              label: visible[groupIndex][itemIndex].label,
              divider:
                  (title != null && groupIndex == 0 && itemIndex == 0) ||
                  (groupIndex > 0 && itemIndex == 0),
              destructive: visible[groupIndex][itemIndex].danger,
              trailing: visible[groupIndex][itemIndex].trailing == null
                  ? null
                  : Text(
                      visible[groupIndex][itemIndex].trailing!,
                      style: OmniType.caption.copyWith(
                        color: Theme.of(
                          menuContext,
                        ).colorScheme.onSurfaceVariant,
                      ),
                    ),
              onTap: () => Navigator.of(
                menuContext,
              ).pop(visible[groupIndex][itemIndex].value),
            ),
      ],
    ),
  );
}

class DetailMenuSheet<T> extends StatelessWidget {
  const DetailMenuSheet({
    super.key,
    required this.semanticsLabel,
    required this.groups,
    this.title,
  });

  final String semanticsLabel;
  final String? title;
  final List<List<DetailMenuItem<T>>> groups;

  @override
  Widget build(BuildContext context) {
    return OmniSheetBody(
      semanticsLabel: semanticsLabel,
      header: title == null
          ? const SizedBox(height: 14)
          : OmniSheetHeader(title: title!),
      children: [
        for (var g = 0; g < groups.length; g++)
          OmniGroupSection(
            key: Key('detail-menu-group-$g'),
            children: [
              for (final item in groups[g])
                OmniGroupRow(
                  icon: item.icon,
                  title: item.label,
                  value: item.trailing,
                  destructive: item.danger,
                  onTap: () => Navigator.of(context).pop(item.value),
                ),
            ],
          ),
      ],
    );
  }
}
