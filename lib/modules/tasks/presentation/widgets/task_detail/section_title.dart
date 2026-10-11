import 'package:flutter/material.dart';

import '../../../../../design/tokens/tokens.dart';

/// Tiêu đề khối của màn chi tiết: HOA 12 w600 giãn 0.5, màu phụ
/// ("ĐIỀU PHỐI", "MÔ TẢ"). Truyền chữ đã viết hoa — không `toUpperCase` ở đây
/// để chữ trên màn và chữ trong test là một.
class DetailSectionTitle extends StatelessWidget {
  const DetailSectionTitle(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label,
        style: OmniType.micro.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
          color: OmniColors.byBrightness(
            context,
            OmniColors.mutedForeground,
            scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
