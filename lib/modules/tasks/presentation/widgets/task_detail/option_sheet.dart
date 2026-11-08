import 'package:flutter/material.dart';

import '../../../../../design/components/components.dart';
import '../../../../../design/tokens/tokens.dart';

/// Một dòng của [showOptionSheet]: ô màu (vuông bo 2, hoặc chấm tròn) + nhãn.
class OptionItem {
  const OptionItem({
    required this.label,
    required this.color,
    this.round = false,
  });

  final String label;
  final Color color;

  /// Chấm tròn (mức ưu tiên) thay cho ô vuông bo 2 (nhóm việc).
  final bool round;
}

/// Bảng chọn một mục trong danh sách ngắn (`TaskDetail.dc.html`): "Chuyển nhóm
/// việc", "Mức ưu tiên". Trả về CHỈ SỐ mục được chọn, null khi đóng không chọn.
///
/// Mục đang chọn có dấu ✓ nhưng vẫn bấm được và trả về chính nó — khoá lại
/// buộc người dùng đoán vì sao một dòng không phản hồi; nơi gọi tự bỏ qua.
/// [emptyMessage] thay cho danh sách khi [items] rỗng.
Future<int?> showOptionSheet(
  BuildContext context, {
  required String title,
  required List<OptionItem> items,
  int? selected,
  String? emptyMessage,
}) => showOmniSheet<int>(
  context: context,
  // Sheet liquid chuẩn: đầu sheet có lề, các mục trong một nhóm lồng.
  builder: (ctx) => OmniSheetBody(
    semanticsLabel: title,
    header: OmniSheetHeader(title: title),
    children: [
      if (items.isEmpty && emptyMessage != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
          child: Text(
            emptyMessage,
            style: OmniType.body.copyWith(
              color: Theme.of(ctx).colorScheme.onSurfaceVariant,
            ),
          ),
        )
      else
        OmniGroupSection(
          dividerIndent: 38,
          children: [
            for (var i = 0; i < items.length; i++)
              OmniGroupRow(
                title: items[i].label,
                selected: i == selected,
                // Danh sách chọn, không phải điều hướng: không mũi tên ›.
                chevron: false,
                leading: SizedBox(
                  width: 12,
                  child: Center(
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: items[i].color,
                        borderRadius: BorderRadius.circular(
                          items[i].round ? 4 : 2,
                        ),
                      ),
                    ),
                  ),
                ),
                onTap: () => Navigator.of(ctx).pop(i),
              ),
          ],
        ),
    ],
  ),
);
