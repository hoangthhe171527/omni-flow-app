import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../../design/tokens/tokens.dart';

/// Bảng màu Viomni Orbit chuẩn 100% theo `so-chi-phi-mobile.html` (Light & Dark).
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? dark : light;
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

/// Hiển thị iOS Popover Menu neo tại vị trí của widget (`anchorContext` hoặc `anchorRect`).
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

  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Đóng menu',
    barrierColor: Colors.black.withValues(alpha: 0.14),
    transitionDuration: const Duration(milliseconds: 160),
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      return _FinancePopoverOverlay<T>(
        header: header,
        items: items,
        anchorRect: resolvedAnchor,
        width: width,
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.94, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class _FinancePopoverOverlay<T> extends StatelessWidget {
  const _FinancePopoverOverlay({
    required this.header,
    required this.items,
    required this.anchorRect,
    required this.width,
  });

  final String? header;
  final List<FinancePopoverItem<T>> items;
  final Rect anchorRect;
  final double width;

  @override
  Widget build(BuildContext context) {
    final p = FinancePalette.of(context);
    final screen = MediaQuery.sizeOf(context);
    final pad = MediaQuery.paddingOf(context);

    final estimatedHeight =
        (header != null ? 34.0 : 0.0) + items.length * 46.0 + 16.0;
    final spaceBelow = screen.height - pad.bottom - anchorRect.bottom - 12;
    final openUp =
        spaceBelow < estimatedHeight && anchorRect.top > estimatedHeight;

    final left = (anchorRect.right - width).clamp(
      14.0,
      screen.width - width - 14.0,
    );
    final top = openUp
        ? (anchorRect.top - estimatedHeight - 6).clamp(
            pad.top + 8.0,
            screen.height - 80.0,
          )
        : (anchorRect.bottom + 6).clamp(
            pad.top + 8.0,
            screen.height - estimatedHeight.clamp(0.0, 360.0) - 14.0,
          );

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).pop(),
              child: const SizedBox.expand(),
            ),
          ),
          Positioned(
            left: left,
            top: top,
            width: width,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: p.isDark
                        ? const Color(0xF5192338)
                        : const Color(0xFAFFFFFF),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: p.line, width: 0.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.18),
                        blurRadius: 32,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 340),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (header != null)
                            Container(
                              padding: const EdgeInsets.fromLTRB(14, 9, 14, 7),
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: p.divider,
                                    width: 0.5,
                                  ),
                                ),
                              ),
                              child: Text(
                                header!.toUpperCase(),
                                style: OmniType.overline.copyWith(
                                  color: p.muted,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ),
                          for (var i = 0; i < items.length; i++)
                            _buildItem(
                              context,
                              p,
                              items[i],
                              isLast: i == items.length - 1,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItem(
    BuildContext context,
    FinancePalette p,
    FinancePopoverItem<T> item, {
    required bool isLast,
  }) {
    final textColor = item.destructive
        ? p.danger
        : (item.selected ? p.primary : p.ink);

    return InkWell(
      onTap: () => Navigator.of(context).pop(item.value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          border: isLast
              ? null
              : Border(bottom: BorderSide(color: p.divider, width: 0.5)),
        ),
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
              Icon(item.icon, size: 17, color: textColor),
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
                            fontWeight: item.selected
                                ? FontWeight.w600
                                : FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          item.subtitle!,
                          style: OmniType.caption.copyWith(
                            color: p.muted,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    )
                  : Text(
                      item.label,
                      style: OmniType.body.copyWith(
                        color: textColor,
                        fontWeight: item.selected
                            ? FontWeight.w600
                            : FontWeight.w500,
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
              width: 16,
              child: item.selected
                  ? Icon(Icons.check_rounded, size: 16, color: p.primary)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
