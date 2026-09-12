import 'package:flutter/material.dart';

import '../../../../../design/tokens/tokens.dart';

/// Chip dữ kiện trên màn chi tiết: một biểu tượng (hoặc mặt người) + nhãn.
class TaskChip extends StatelessWidget {
  const TaskChip({
    super.key,
    this.icon,
    this.leading,
    required this.label,
    this.color,
  });

  final IconData? icon;

  /// Thay cho [icon] khi chip đại diện cho một NGƯỜI: mặt người thay biểu tượng.
  final Widget? leading;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tone = color ?? scheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: OmniSpacing.md,
        vertical: OmniSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: OmniRadius.chipAll,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leading != null)
            leading!
          else if (icon != null)
            Icon(icon, size: OmniIconSize.sm, color: tone),
          const SizedBox(width: OmniSpacing.xs),
          Text(label, style: OmniType.caption.copyWith(color: tone)),
        ],
      ),
    );
  }
}
