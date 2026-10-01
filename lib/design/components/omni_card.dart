import 'package:flutter/material.dart';

import '../tokens/tokens.dart';

/// The single surface primitive. Hairline border, near-invisible shadow —
/// hierarchy comes from spacing, not elevation.
class OmniCard extends StatelessWidget {
  const OmniCard({
    super.key,
    required this.child,
    this.padding = OmniSpacing.card,
    this.onTap,
    this.borderColor,
    this.background,
    this.leadingEdge,
  });

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final Color? borderColor;
  final Color? background;

  /// A 3px coloured strip on the leading edge — how a conversation row encodes
  /// its platform without spending horizontal space.
  final Color? leadingEdge;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    Widget content = Padding(padding: padding, child: child);

    if (leadingEdge != null) {
      content = Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(width: 3, color: leadingEdge),
          Expanded(child: content),
        ],
      );
    }

    return Material(
      color: background ?? scheme.surface,
      borderRadius: OmniRadius.xlAll,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: OmniRadius.xlAll,
            // Viền TRANG TRÍ (outlineVariant, #E3E8EF): thẻ trắng trên nền xám
            // đã tự tách khỏi nền. Viền tương tác 3:1 dành cho ô nhập, nút.
            border: Border.all(color: borderColor ?? scheme.outlineVariant),
          ),
          child: content,
        ),
      ),
    );
  }
}

class OmniSectionHeader extends StatelessWidget {
  const OmniSectionHeader({
    super.key,
    required this.title,
    this.action,
    this.onAction,
    this.padding = const EdgeInsets.only(
      left: OmniSpacing.lg,
      right: OmniSpacing.lg,
      top: OmniSpacing.xxl,
      bottom: OmniSpacing.md,
    ),
  });

  final String title;
  final String? action;
  final VoidCallback? onAction;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: Text(
              title.toUpperCase(),
              // 12/700, giãn chữ .08em — nhãn nhóm của mọi màn trong bộ Orbit.
              style: OmniType.overline.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: 0.96,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          if (action != null)
            GestureDetector(
              onTap: onAction,
              child: Row(
                children: [
                  Icon(
                    Icons.add_rounded,
                    size: OmniIconSize.sm,
                    color: scheme.primary,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    action!,
                    style: OmniType.micro.copyWith(color: scheme.primary),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// One KPI tile — pipeline value, open opportunities, conversation count.
/// Ô số liệu nhỏ: nhãn 12 chữ phụ, số 17/700 (`MCustomerDetail.dc.html`).
class OmniStatTile extends StatelessWidget {
  const OmniStatTile({
    super.key,
    required this.label,
    required this.value,
    this.tone,
    this.caption,
  });

  final String label;
  final String value;
  final Color? tone;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return OmniCard(
      padding: const EdgeInsets.all(OmniSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: OmniType.micro.copyWith(
              fontWeight: FontWeight.w400,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: OmniType.money.copyWith(color: tone ?? scheme.onSurface),
          ),
          if (caption != null) ...[
            const SizedBox(height: 2),
            Text(
              caption!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: OmniType.micro.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}

/// Thẻ chứa các [OmniDetailRow], vạch ngăn giữa từng dòng.
class OmniDetailCard extends StatelessWidget {
  const OmniDetailCard({super.key, required this.rows});

  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    return OmniCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            rows[i],
          ],
        ],
      ),
    );
  }
}

/// Dòng "nhãn — giá trị" trong thẻ chi tiết: nhãn chữ phụ cột 110, giá trị
/// 15; dòng bấm được (gọi, gửi thư) tô giá trị màu chính đậm như liên kết.
class OmniDetailRow extends StatelessWidget {
  const OmniDetailRow({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.onTap,
    this.valueColor,
    this.strong = false,
  });

  final String label;
  final String value;

  /// Icon đầu dòng. Bộ Orbit không dùng; giữ cho chỗ gọi cũ.
  final IconData? icon;
  final VoidCallback? onTap;
  final Color? valueColor;

  /// Giá trị đậm (người phụ trách, giai đoạn).
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final link = onTap != null;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (icon != null) ...[
              Icon(icon, size: OmniIconSize.md, color: scheme.onSurfaceVariant),
              const SizedBox(width: OmniSpacing.md),
            ],
            SizedBox(
              width: 110,
              child: Text(
                label,
                style: OmniType.bodyStrong.copyWith(
                  fontWeight: FontWeight.w400,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: OmniType.bodyStrong.copyWith(
                  height: 21 / 15,
                  color:
                      valueColor ?? (link ? scheme.primary : scheme.onSurface),
                  fontWeight: link || strong
                      ? FontWeight.w600
                      : FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
