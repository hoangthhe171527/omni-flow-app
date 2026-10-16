import 'package:flutter/material.dart';

import '../tokens/tokens.dart';

/// The single surface primitive: white, a hairline E3E8EF border, radius 10,
/// NO shadow — hierarchy comes from spacing and borders, not elevation.
class OmniCard extends StatelessWidget {
  const OmniCard({
    super.key,
    required this.child,
    this.padding = OmniSpacing.card,
    this.onTap,
    this.borderColor,
    this.background,
    this.leadingEdge,
    this.flat = false,
  });

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final Color? borderColor;
  final Color? background;

  /// Dùng cho các section cấp trang: không viền, không bo góc. Nội dung vẫn
  /// giữ Material/Ink để phản hồi chạm nhất quán với thẻ thông thường.
  final bool flat;

  /// A 3px coloured strip on the leading edge — how a conversation row encodes
  /// its platform without spending horizontal space.
  final Color? leadingEdge;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = flat ? BorderRadius.zero : OmniRadius.xlAll;

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
      borderRadius: radius,
      clipBehavior: flat ? Clip.none : Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: radius,
            // Viền TRANG TRÍ (outlineVariant, #E3E8EF): thẻ trắng trên nền xám
            // đã tự tách khỏi nền. Viền tương tác 3:1 dành cho ô nhập, nút.
            border: flat
                ? null
                : Border.all(color: borderColor ?? scheme.outlineVariant),
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

  /// Vùng của nút + để nơi gọi có thể mở menu nhanh neo đúng vị trí.
  final ValueChanged<Rect>? onAction;
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
              title,
              // 13/600 chữ phụ, viết thường — tiêu đề nhóm của đề xuất "Chuẩn
              // hoá phong cách". IN HOA giãn chữ đọc ra chất tài liệu.
              style: OmniType.overline.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          if (action != null)
            Builder(
              builder: (buttonContext) {
                void open() {
                  final box = buttonContext.findRenderObject() as RenderBox?;
                  if (box == null || !box.hasSize) return;
                  onAction?.call(box.localToGlobal(Offset.zero) & box.size);
                }

                return Semantics(
                  button: true,
                  label: action,
                  excludeSemantics: true,
                  onTap: onAction == null ? null : open,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onAction == null ? null : open,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 44),
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
                            style: OmniType.micro.copyWith(
                              color: scheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

/// One KPI tile — pipeline value, open opportunities, conversation count.
/// Ô số liệu nhỏ: nhãn 13 chữ phụ, số 16/600 màu chữ chính
/// (`SMCustomerDetail.dc.html`). Màu kênh hay màu trạng thái không vào số.
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: OmniType.caption.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: OmniType.section.copyWith(
              color: tone ?? scheme.onSurface,
              fontFeatures: OmniType.tabular,
            ),
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
  const OmniDetailCard({super.key, required this.rows, this.flat = false});

  final List<Widget> rows;
  final bool flat;

  @override
  Widget build(BuildContext context) {
    return OmniCard(
      padding: EdgeInsets.zero,
      flat: flat,
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                style: OmniType.body.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: OmniType.body.copyWith(
                  color:
                      valueColor ?? (link ? scheme.primary : scheme.onSurface),
                  fontWeight: link || strong
                      ? FontWeight.w500
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
