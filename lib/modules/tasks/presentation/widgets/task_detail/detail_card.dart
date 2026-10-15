import 'package:flutter/material.dart';

import '../../../../../design/tokens/tokens.dart';

/// Section chi tiết việc. Mặc định phẳng ở cấp trang; nơi dùng trong modal có
/// thể bật lại khung bằng [flat] = false.
class DetailCard extends StatelessWidget {
  const DetailCard({super.key, required this.children, this.flat = false});

  final List<Widget> children;
  final bool flat;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: flat ? null : BorderRadius.circular(8),
        border: flat ? null : Border.all(color: scheme.outlineVariant),
      ),
      clipBehavior: flat ? Clip.none : Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

/// Màu chữ phụ `#56637A` (tối: `onSurfaceVariant`).
Color detailSecondary(BuildContext context) => OmniColors.byBrightness(
  context,
  OmniColors.mutedForeground,
  Theme.of(context).colorScheme.onSurfaceVariant,
);

/// Đầu thẻ `.sh`: cao ≥48, đệm 0 4 0 12, biểu tượng 20 màu phụ, tên w600,
/// rồi [count] (13 w500 phụ) và các nút 44 ở [actions].
class DetailCardHeader extends StatelessWidget {
  const DetailCardHeader({
    super.key,
    required this.icon,
    required this.title,
    this.count,
    this.actions = const [],
  });

  final IconData icon;
  final String title;
  final String? count;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final secondary = detailSecondary(context);

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Padding(
        padding: EdgeInsets.fromLTRB(12, 0, actions.isEmpty ? 12 : 4, 0),
        child: Row(
          children: [
            Icon(icon, size: OmniIconSize.lg, color: secondary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: OmniType.bodySm.copyWith(
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                ),
              ),
            ),
            if (count case final value?)
              Text(
                value,
                style: OmniType.caption.copyWith(
                  fontWeight: FontWeight.w500,
                  color: secondary,
                ),
              ),
            ...actions,
          ],
        ),
      ),
    );
  }
}

/// Nút `.ib` 44 màu primary ở đầu thẻ.
class DetailHeaderButton extends StatelessWidget {
  const DetailHeaderButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    onPressed: onPressed,
    style: IconButton.styleFrom(
      minimumSize: const Size(44, 44),
      maximumSize: const Size(44, 44),
      padding: EdgeInsets.zero,
      foregroundColor: Theme.of(context).colorScheme.primary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
    ),
    icon: Icon(icon, size: OmniIconSize.lg),
  );
}

/// Dòng `.row` của thẻ: cao ≥48, đệm 0 6 0 12, nhãn trái rộng 104 chữ 14
/// màu phụ, vạch `#EEF1F5` phía trên khi [divider].
class DetailRow extends StatelessWidget {
  const DetailRow({
    super.key,
    required this.label,
    required this.child,
    this.divider = false,
    this.icon,
    this.iconColor,
  });

  final String label;
  final Widget child;
  final bool divider;

  /// Biểu tượng 16 trước nhãn (thẻ Trường tuỳ chỉnh: kiểu trường). Có thì
  /// cột nhãn rộng 116 thay vì 104, để chữ nhãn vẫn còn chỗ như cũ.
  final IconData? icon;

  /// Màu [icon]; null = màu chữ phụ như nhãn.
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final secondary = detailSecondary(context);
    final text = Text(label, style: OmniType.bodySm.copyWith(color: secondary));

    return Container(
      constraints: const BoxConstraints(minHeight: 48),
      padding: const EdgeInsets.fromLTRB(12, 0, 6, 0),
      decoration: BoxDecoration(
        border: divider
            ? Border(top: BorderSide(color: OmniColors.trackOf(context)))
            : null,
      ),
      child: Row(
        children: [
          SizedBox(
            width: icon == null ? 104 : 116,
            child: icon == null
                ? text
                : Row(
                    children: [
                      Icon(
                        icon,
                        size: OmniIconSize.sm,
                        color: iconColor ?? secondary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: text),
                    ],
                  ),
          ),
          const SizedBox(width: 10),
          Expanded(child: child),
        ],
      ),
    );
  }
}
