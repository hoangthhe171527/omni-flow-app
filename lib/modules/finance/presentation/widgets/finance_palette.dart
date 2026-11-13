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
    final (warnFg, warnBg) = OmniTone.warning.of(context);
    final (okFg, okBg) = OmniTone.success.of(context);
    final (errFg, errBg) = OmniTone.danger.of(context);

    return FinancePalette(
      isDark: isDark,
      bg: theme.scaffoldBackgroundColor,
      card: scheme.surface,
      ink: scheme.onSurface,
      ink2: scheme.onSurface.withValues(alpha: .78),
      muted: scheme.onSurfaceVariant,
      line: scheme.outlineVariant,
      divider: scheme.outlineVariant.withValues(alpha: .7),
      track: OmniColors.trackOf(context),
      control: scheme.onSurface.withValues(alpha: isDark ? .10 : .05),
      selLine: scheme.primary.withValues(alpha: .32),
      primary: scheme.primary,
      primarySoft: scheme.primary.withValues(alpha: isDark ? .18 : .10),
      primaryInk: OmniColors.byBrightness(
        context,
        OmniColors.accentForeground,
        OmniColors.darkAccentForeground,
      ),
      amber: warnFg,
      amberSoft: warnBg,
      ok: okFg,
      okSoft: okBg,
      danger: errFg,
      dangerSoft: errBg,
    );
  }

  static const FinancePalette light = FinancePalette(
    isDark: false,
    bg: OmniColors.background,
    card: OmniColors.card,
    ink: OmniColors.ink,
    ink2: OmniColors.secondaryForeground,
    muted: OmniColors.mutedForeground,
    line: OmniColors.border,
    divider: OmniColors.divider,
    track: OmniColors.muted,
    control: OmniColors.muted,
    selLine: OmniColors.controlBorder,
    primary: OmniColors.primary,
    primarySoft: OmniColors.accent,
    primaryInk: OmniColors.accentForeground,
    amber: OmniColors.warningText,
    amberSoft: OmniColors.warningSoft,
    ok: OmniColors.primary,
    okSoft: OmniColors.accent,
    danger: OmniColors.dangerText,
    dangerSoft: OmniColors.dangerSoft,
  );

  static const FinancePalette dark = FinancePalette(
    isDark: true,
    bg: OmniColors.darkBackground,
    card: OmniColors.darkCard,
    ink: OmniColors.darkForeground,
    ink2: OmniColors.darkForeground,
    muted: OmniColors.darkMutedForeground,
    line: OmniColors.darkBorder,
    divider: OmniColors.darkBorder,
    track: OmniColors.darkMuted,
    control: OmniColors.darkMuted,
    selLine: OmniColors.darkBorderInteractive,
    primary: OmniColors.darkPrimary,
    primarySoft: OmniColors.darkAccent,
    primaryInk: OmniColors.darkAccentForeground,
    amber: OmniColors.warningTextDark,
    amberSoft: OmniColors.darkWarningSoft,
    ok: OmniColors.darkPrimary,
    okSoft: OmniColors.darkAccent,
    danger: OmniColors.dangerTextDark,
    dangerSoft: OmniColors.darkMuted,
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
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          // Mục đang chọn: nền mờ nhẹ (trắng mờ trên kính) + ✓, không chữ màu,
          // một tông biểu tượng (không chấm màu cầu vồng).
          color: item.selected
              ? scheme.onSurface.withValues(alpha: p.isDark ? .10 : .05)
              : null,
          child: Row(
            children: [
              if (item.icon != null) ...[
                Icon(
                  item.icon,
                  size: OmniIconSize.md,
                  color: item.destructive
                      ? p.danger
                      : scheme.onSurface.withValues(alpha: .78),
                ),
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
