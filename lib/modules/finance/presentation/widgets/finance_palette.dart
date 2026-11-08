import 'package:flutter/material.dart';

import '../../../../design/components/components.dart';
import '../../../../design/tokens/tokens.dart';

/// Bảng màu của Sổ chi phí. Nền, thẻ, chữ, nét kẻ và màu điều khiển lấy từ
/// theme chung (liquid, duyệt 08/11/2026); chỉ giữ riêng ba màu NGỮ NGHĨA
/// của trạng thái tiền: đã trả (`ok`), còn phải trả (`amber`), lỗi (`danger`).
@immutable
class FinancePalette {
  const FinancePalette({
    required this.isDark,
    required this.bg,
    required this.card,
    required this.ink,
    required this.ink2,
    required this.muted,
    required this.line,
    required this.divider,
    required this.track,
    required this.control,
    required this.selLine,
    required this.primary,
    required this.primarySoft,
    required this.primaryInk,
    required this.amber,
    required this.amberSoft,
    required this.ok,
    required this.okSoft,
    required this.danger,
    required this.dangerSoft,
  });

  factory FinancePalette.of(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final status = isDark ? dark : light;

    return FinancePalette(
      isDark: isDark,
      bg: theme.scaffoldBackgroundColor,
      card: scheme.surface,
      ink: scheme.onSurface,
      ink2: scheme.onSurface.withValues(alpha: .78),
      muted: scheme.onSurfaceVariant,
      line: scheme.outlineVariant,
      divider: scheme.outlineVariant.withValues(alpha: .7),
      track: scheme.onSurface.withValues(alpha: isDark ? .12 : .07),
      control: scheme.onSurface.withValues(alpha: isDark ? .10 : .05),
      selLine: scheme.primary.withValues(alpha: .35),
      primary: scheme.primary,
      primarySoft: scheme.primary.withValues(alpha: isDark ? .18 : .10),
      primaryInk: scheme.primary,
      amber: status.amber,
      amberSoft: status.amberSoft,
      ok: status.ok,
      okSoft: status.okSoft,
      danger: status.danger,
      dangerSoft: status.dangerSoft,
    );
  }

  static const FinancePalette light = FinancePalette(
    isDark: false,
    bg: Color(0xFFF2F3F7),
    card: Color(0xFFFFFFFF),
    ink: Color(0xFF0F172A),
    ink2: Color(0xFF475569),
    muted: Color(0xFF64748B),
    line: Color(0xFFE5E7EB),
    divider: Color(0xFFF1F5F9),
    track: Color(0xFFEBEEF3),
    control: Color(0xFFF1F5F9),
    selLine: Color(0xFF94E2D8),
    primary: Color(0xFF0A7D76),
    primarySoft: Color(0xFFE6F4F2),
    primaryInk: Color(0xFF065F5B),
    amber: Color(0xFFB45309),
    amberSoft: Color(0xFFFEF3C7),
    ok: Color(0xFF15803D),
    okSoft: Color(0xFFDCFCE7),
    danger: Color(0xFFB91C1C),
    dangerSoft: Color(0xFFFEE2E2),
  );

  static const FinancePalette dark = FinancePalette(
    isDark: true,
    bg: Color(0xFF0B1120),
    card: Color(0xFF131C2E),
    ink: Color(0xFFF8FAFC),
    ink2: Color(0xFFCBD5E1),
    muted: Color(0xFF94A3B8),
    line: Color(0xFF1E293B),
    divider: Color(0xFF1A2438),
    track: Color(0xFF1E293B),
    control: Color(0xFF1E293B),
    selLine: Color(0xFF134E4A),
    primary: Color(0xFF14B8A6),
    primarySoft: Color(0xFF0F2E2D),
    primaryInk: Color(0xFF5EEAD4),
    amber: Color(0xFFF59E0B),
    amberSoft: Color(0xFF33240C),
    ok: Color(0xFF22C55E),
    okSoft: Color(0xFF0F2E1E),
    danger: Color(0xFFF87171),
    dangerSoft: Color(0xFF351519),
  );

  final bool isDark;
  final Color bg;
  final Color card;
  final Color ink;
  final Color ink2;
  final Color muted;
  final Color line;
  final Color divider;
  final Color track;
  final Color control;
  final Color selLine;
  final Color primary;
  final Color primarySoft;
  final Color primaryInk;
  final Color amber;
  final Color amberSoft;
  final Color ok;
  final Color okSoft;
  final Color danger;
  final Color dangerSoft;
}

/// Một mục trong iOS Popover Menu (`.menu-it` trong `so-chi-phi-mobile.html`).
@immutable
class FinancePopoverItem<T> {
  const FinancePopoverItem({
    required this.value,
    required this.label,
    this.subtitle,
    this.dotColor,
    this.icon,
    this.selected = false,
    this.destructive = false,
    this.stackSubtitle = false,
  });

  final T value;
  final String label;
  final String? subtitle;
  final Color? dotColor;
  final IconData? icon;
  final bool selected;
  final bool destructive;
  final bool stackSubtitle;
}

/// Hiển thị menu kính neo tại vị trí của widget (`anchorContext` hoặc
/// `anchorRect`) — cùng kiểu menu nổi của app ([showOmniAnchoredMenu]): nền
/// mờ + blur, bo 22, không vạch chia, không tiêu đề IN HOA (nhãn đã có ngay ở
/// dòng gọi nó; [header] chỉ còn làm nhãn trợ năng).
Future<T?> showFinancePopoverMenu<T>({
  required BuildContext context,
  String? header,
  required List<FinancePopoverItem<T>> items,
  BuildContext? anchorContext,
  Rect? anchorRect,
  double width = 252,
}) {
  Rect resolvedAnchor;
  if (anchorRect != null) {
    resolvedAnchor = anchorRect;
  } else {
    final targetCtx = anchorContext ?? context;
    final box = targetCtx.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize) {
      final topLeft = box.localToGlobal(Offset.zero);
      resolvedAnchor = topLeft & box.size;
    } else {
      final screen = MediaQuery.sizeOf(context);
      resolvedAnchor = Rect.fromCenter(
        center: Offset(screen.width / 2, screen.height / 3),
        width: 40,
        height: 40,
      );
    }
  }

  return showOmniAnchoredMenu<T>(
    context: context,
    anchor: resolvedAnchor,
    width: width,
    semanticsLabel: header ?? 'Tuỳ chọn',
    builder: (menuContext) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [for (final item in items) _FinanceMenuRow<T>(item: item)],
    ),
  );
}

class _FinanceMenuRow<T> extends StatelessWidget {
  const _FinanceMenuRow({required this.item});

  final FinancePopoverItem<T> item;

  @override
  Widget build(BuildContext context) {
    final p = FinancePalette.of(context);
    final scheme = Theme.of(context).colorScheme;
    final textColor = item.destructive ? p.danger : p.ink;
    final weight = item.selected ? FontWeight.w600 : FontWeight.w500;

    return Semantics(
      button: true,
      selected: item.selected,
      child: InkWell(
        onTap: () => Navigator.of(context).pop(item.value),
        child: Container(
          constraints: const BoxConstraints(minHeight: 46),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          // Mục đang chọn: nền mờ nhẹ (trắng mờ trên kính) + ✓, không chữ màu.
          color: item.selected
              ? scheme.onSurface.withValues(alpha: p.isDark ? .10 : .05)
              : null,
          child: Row(
            children: [
              if (item.dotColor != null) ...[
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: item.dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
              ] else if (item.icon != null) ...[
                Icon(item.icon, size: 18, color: textColor),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: item.stackSubtitle && item.subtitle != null
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            item.label,
                            style: OmniType.body.copyWith(
                              color: textColor,
                              fontWeight: weight,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            item.subtitle!,
                            style: OmniType.caption.copyWith(
                              color: p.muted,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ],
                      )
                    : Text(
                        item.label,
                        style: OmniType.body.copyWith(
                          color: textColor,
                          fontWeight: weight,
                        ),
                      ),
              ),
              if (!item.stackSubtitle && item.subtitle != null) ...[
                const SizedBox(width: 8),
                Text(
                  item.subtitle!,
                  style: OmniType.caption.copyWith(
                    color: p.muted,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
              const SizedBox(width: 8),
              SizedBox(
                width: 18,
                child: item.selected
                    ? Icon(Icons.check_rounded, size: 18, color: p.primary)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
