import 'package:flutter/material.dart';

import '../../../../design/tokens/tokens.dart';

/// Tám chấm chọn nền cho kế hoạch, cuộn ngang. Dùng chung cho tạo kế hoạch
/// và sửa kế hoạch.
///
/// Mỗi ô vẽ 36 nhưng vùng chạm 44×44 (khe giữa hai ô giữ 12 như cũ: 4 + 4
/// từ vùng chạm, cộng 4).
class CoverPicker extends StatelessWidget {
  const CoverPicker({super.key, required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: OmniCovers.names.length,
        separatorBuilder: (_, _) => const SizedBox(width: OmniSpacing.xs),
        itemBuilder: (context, i) {
          final name = OmniCovers.names[i];
          final selected = name == value;

          return Semantics(
            button: true,
            selected: selected,
            label: 'Nền ${i + 1}',
            child: GestureDetector(
              key: ValueKey('cover:$name'),
              behavior: HitTestBehavior.opaque,
              onTap: () => onChanged(name),
              child: SizedBox(
                width: 44,
                height: 44,
                child: Center(
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      borderRadius: OmniRadius.smAll,
                      gradient: OmniCovers.gradientOf(name),
                      // Vành đôi (khe trắng + vành màu chính) thay vì dấu
                      // tích: một dấu tích trên ô 36dp che mất chính cái màu
                      // người ta đang so sánh.
                      boxShadow: selected
                          ? [
                              BoxShadow(color: scheme.primary, spreadRadius: 4),
                              BoxShadow(color: scheme.surface, spreadRadius: 2),
                            ]
                          : null,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
