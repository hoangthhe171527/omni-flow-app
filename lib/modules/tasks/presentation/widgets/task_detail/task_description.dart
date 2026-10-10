import 'package:flutter/material.dart';

import '../../../../../design/tokens/tokens.dart';

/// Thẻ mô tả (`TaskDetail.dc.html`): bo 8, đệm 10/12, chữ 14 cao 1.5.
/// Người giao việc chạm để sửa — kể cả khi còn trống ("Thêm mô tả").
/// Tiêu đề "MÔ TẢ" do màn đặt ngoài thẻ.
class TaskDescription extends StatelessWidget {
  const TaskDescription({super.key, required this.text, this.onEdit});

  final String text;

  /// Null = chỉ đọc.
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final body = Theme.of(context).textTheme.bodyMedium;
    final empty = text.trim().isEmpty;

    final content = Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 44),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      alignment: Alignment.centerLeft,
      child: Text(
        empty ? 'Thêm mô tả' : text,
        style: body?.copyWith(
          height: 1.5,
          color: empty
              ? scheme.onSurfaceVariant
              : OmniColors.byBrightness(
                  context,
                  OmniColors.secondaryForeground,
                  scheme.onSurface,
                ),
        ),
      ),
    );

    return Material(
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: onEdit == null ? content : InkWell(onTap: onEdit, child: content),
    );
  }
}
