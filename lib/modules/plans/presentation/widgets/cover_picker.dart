import 'package:flutter/material.dart';

import '../../../../design/tokens/tokens.dart';

/// Tám chấm chọn nền cho thẻ dự án, cuộn ngang.
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
        separatorBuilder: (_, _) => const SizedBox(width: OmniSpacing.md),
        itemBuilder: (context, i) {
          final name = OmniCovers.names[i];
          final selected = name == value;

          return Center(
            child: GestureDetector(
              key: ValueKey('cover:$name'),
              onTap: () => onChanged(name),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: OmniCovers.gradientOf(name),
                  // Vành sáng thay vì dấu tích: một dấu tích trên chấm 36dp
                  // che mất chính cái màu người ta đang so sánh.
                  border: selected
                      ? Border.all(color: scheme.onSurface, width: 3)
                      : null,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
