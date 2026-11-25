import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../tokens/tokens.dart';

/// Một số phụ dưới khối tổng: giá trị đậm 15 trên, nhãn 12 xám dưới.
class OmniTotalStat {
  const OmniTotalStat({
    required this.value,
    required this.label,
    this.warning = false,
    this.active = false,
    this.onTap,
    this.flex = 1,
    this.key,
  });

  final String value;
  final String label;

  /// Tô giá trị màu cảnh báo (vd tồn lâu > 0).
  final bool warning;

  /// Đang là bộ lọc của màn: giá trị màu chính.
  final bool active;
  final VoidCallback? onTap;
  final int flex;
  final Key? key;
}

/// Khối tổng (spec phong cách iOS §3.4): thẻ trắng bo 16, nhãn 13 xám, số tiền
/// 30/800 — số lớn nhất màn, không bao giờ cắt (co lại thay vì `…`). Số phụ
/// ở dưới, cách bằng một đường kẻ.
class OmniTotalCard extends StatelessWidget {
  const OmniTotalCard({
    super.key,
    required this.label,
    required this.amount,
    this.trailingLabel,
    this.child,
    this.stats = const [],
    this.amountKey,
    this.onTap,
    this.semanticsLabel,
  });

  /// Chạm cả khối (vd mở Ghi thu — "tiền chạm để sửa"). Có [stats] chạm được
  /// riêng thì để null.
  final VoidCallback? onTap;
  final String? semanticsLabel;

  final String label;

  /// Chữ nhỏ bên phải hàng nhãn (vd "4 đơn", "2/5 cây xong").
  final String? trailingLabel;
  final String amount;
  final Key? amountKey;

  /// Thứ nằm ngay dưới số tiền (vd vạch tiến độ).
  final Widget? child;
  final List<OmniTotalStat> stats;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = TextStyle(
      fontSize: 13,
      height: 1.4,
      fontWeight: FontWeight.w500,
      color: scheme.onSurfaceVariant,
    );
    final card = Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: _body(context, scheme, muted)),
    );
    if (onTap == null && semanticsLabel == null) return card;
    return Semantics(button: onTap != null, label: semanticsLabel, child: card);
  }

  Widget _body(BuildContext context, ColorScheme scheme, TextStyle muted) =>
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: muted,
                  ),
                ),
                if (trailingLabel case final t?) ...[
                  const SizedBox(width: 12),
                  Text(t, maxLines: 1, style: muted),
                ],
              ],
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                amount,
                key: amountKey,
                maxLines: 1,
                softWrap: false,
                style: TextStyle(
                  fontSize: 30,
                  height: 1.25,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                  color: scheme.onSurface,
                  fontFeatures: OmniType.tabular,
                ),
              ),
            ),
            if (child case final c?) ...[const SizedBox(height: 12), c],
            if (stats.isNotEmpty) ...[
              const SizedBox(height: 12),
              Divider(
                height: 1,
                thickness: 1,
                color: scheme.outlineVariant.withValues(alpha: .7),
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < stats.length; i++) ...[
                    if (i > 0) const SizedBox(width: 12),
                    Expanded(
                      flex: stats[i].flex,
                      child: _Stat(stat: stats[i]),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      );
}

class _Stat extends StatelessWidget {
  const _Stat({required this.stat});
  final OmniTotalStat stat;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = stat.active
        ? scheme.primary
        : stat.warning
        ? OmniColors.warningTextOf(context)
        : scheme.onSurface;
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            stat.value,
            maxLines: 1,
            softWrap: false,
            style: TextStyle(
              fontSize: 15,
              height: 1.4,
              fontWeight: FontWeight.w700,
              color: color,
              fontFeatures: OmniType.tabular,
            ),
          ),
        ),
        Text(
          stat.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            height: 1.4,
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
    if (stat.onTap == null) {
      return Semantics(
        key: stat.key,
        label: '${stat.label}: ${stat.value}',
        excludeSemantics: true,
        child: body,
      );
    }
    return Semantics(
      key: stat.key,
      button: true,
      selected: stat.active,
      label: '${stat.label}: ${stat.value}',
      excludeSemantics: true,
      child: InkWell(
        onTap: stat.onTap,
        borderRadius: BorderRadius.circular(8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          // Căn trên: thẳng hàng với số phụ không chạm được bên cạnh.
          child: Align(alignment: Alignment.topLeft, child: body),
        ),
      ),
    );
  }
}

/// Dòng có số tiền (spec §3.4 "Danh sách"): hai hàng — tên 16/600 (tối đa 2
/// dòng) + số tiền 16/700 (không cắt) / dòng phụ 14 xám + nhãn trạng thái.
/// Đặt trong [OmniGroupSection] với `dividerIndent: 16` (hoặc 16 + đầu dòng).
class OmniMoneyRow extends StatelessWidget {
  const OmniMoneyRow({
    super.key,
    required this.title,
    this.amount,
    this.subtitle,
    this.status,
    this.leading,
    this.onTap,
    this.selected = false,
    this.semanticsLabel,
  });

  final String title;

  /// Số tiền bên phải tên. `null` thì [status] lên hàng tên.
  final String? amount;
  final Widget? subtitle;
  final Widget? status;
  final Widget? leading;
  final VoidCallback? onTap;

  /// Đang được chọn (chế độ chọn nhiều): nền xanh nhạt + dấu ✓ cuối dòng.
  final bool selected;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final titleText = Text(
      title,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 16,
        height: 1.4,
        fontWeight: FontWeight.w600,
        color: scheme.onSurface,
      ),
    );
    final top = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: titleText),
        if (amount case final a?) ...[
          const SizedBox(width: 12),
          Text(
            a,
            maxLines: 1,
            softWrap: false,
            style: TextStyle(
              fontSize: 16,
              height: 1.4,
              fontWeight: FontWeight.w700,
              color: scheme.onSurface,
              fontFeatures: OmniType.tabular,
            ),
          ),
        ] else if (status case final s?) ...[
          const SizedBox(width: 12),
          Padding(padding: const EdgeInsets.only(top: 1), child: s),
        ],
      ],
    );
    final hasSecond = subtitle != null || (amount != null && status != null);
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        top,
        if (hasSecond) ...[
          const SizedBox(height: 3),
          Row(
            children: [
              Expanded(
                child: DefaultTextStyle.merge(
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    color: scheme.onSurfaceVariant,
                    fontFeatures: OmniType.tabular,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  child: subtitle ?? const SizedBox.shrink(),
                ),
              ),
              if (amount != null && status != null) ...[
                const SizedBox(width: 12),
                status!,
              ],
            ],
          ),
        ],
      ],
    );
    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            if (leading case final l?) ...[l, const SizedBox(width: 12)],
            Expanded(child: content),
            if (selected) ...[
              const SizedBox(width: 10),
              Icon(LucideIcons.check, size: 20, color: scheme.primary),
            ],
          ],
        ),
      ),
    );
    return Semantics(
      button: onTap != null,
      selected: selected,
      label: semanticsLabel,
      child: ColoredBox(
        color: selected
            ? scheme.primary.withValues(
                alpha: Theme.of(context).brightness == Brightness.dark
                    ? .16
                    : .10,
              )
            : Colors.transparent,
        child: onTap == null ? row : InkWell(onTap: onTap, child: row),
      ),
    );
  }
}
