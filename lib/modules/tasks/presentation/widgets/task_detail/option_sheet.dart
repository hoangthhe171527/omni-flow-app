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
  builder: (ctx) {
    final text = Theme.of(ctx).textTheme;
    final scheme = Theme.of(ctx).colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            if (items.isEmpty && emptyMessage != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  emptyMessage,
                  style: text.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            for (var i = 0; i < items.length; i++)
              InkWell(
                onTap: () => Navigator.of(ctx).pop(i),
                child: Container(
                  height: 46,
                  decoration: BoxDecoration(
                    border: i == 0
                        ? null
                        : Border(
                            top: BorderSide(color: OmniColors.trackOf(ctx)),
                          ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: items[i].color,
                          borderRadius: BorderRadius.circular(
                            items[i].round ? 4 : 2,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          items[i].label,
                          style: text.bodyLarge?.copyWith(
                            fontWeight: i == selected
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                      ),
                      if (i == selected)
                        Icon(
                          Icons.check_rounded,
                          size: 18,
                          color: scheme.primary,
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  },
);
