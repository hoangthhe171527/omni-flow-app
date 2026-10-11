import 'package:flutter/material.dart';

import '../../../../../design/tokens/tokens.dart';
import '../../../domain/task_label.dart';

/// Dải nhãn của chi tiết việc (`TaskDetail.dc.html` `.lab`): chip cao 28,
/// bo 4, chữ 13 w600 trên màu nhãn, cách 6; cuối dải là nút + 28 trong vùng
/// chạm 44 ("Thêm nhãn").
///
/// Mã không có trong danh mục (người không có `system_options.read`, hoặc
/// nhãn đã bị tắt) vẫn hiện bằng chữ mã trên màu `fallback`: một nhãn biến
/// mất khỏi việc là mất dữ liệu trước mắt người dùng.
class LabelStrip extends StatelessWidget {
  const LabelStrip({
    super.key,
    required this.codes,
    required this.catalog,
    this.onAdd,
  });

  final List<String> codes;
  final List<TaskLabel> catalog;

  /// null = không có nút +.
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final byCode = {for (final l in catalog) l.code: l};

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final code in codes) _Chip(code: code, label: byCode[code]),
        if (onAdd != null) _AddButton(onTap: onAdd!),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.code, required this.label});

  final String code;
  final TaskLabel? label;

  @override
  Widget build(BuildContext context) {
    final color = OmniLabelColors.parseHex(label?.color);

    return Container(
      key: ValueKey('label-chip-$code'),
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 10),

      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      // widthFactor 1: chip ôm chữ (Container có alignment thì giãn hết dòng).
      child: Align(
        widthFactor: 1,
        child: Text(
          label?.label ?? code,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: OmniType.overline.copyWith(
            color: OmniLabelColors.textOn(color),
          ),
        ),
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      label: 'Thêm nhãn',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: SizedBox.square(
          dimension: 44,
          child: Center(
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: OmniColors.trackOf(context),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Icon(
                Icons.add_rounded,
                size: OmniIconSize.sm,
                color: OmniColors.byBrightness(
                  context,
                  OmniColors.mutedForeground,
                  scheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
