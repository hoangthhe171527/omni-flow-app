import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../platform/omni_motion_scope.dart';
import '../tokens/tokens.dart';
import 'omni_motion_widgets.dart';

/// Menu nổi neo vào một nút, dùng chung cho các thao tác nhanh ở header.
///
/// Nút chỉ mở lựa chọn tại chỗ; việc chuyển sang một màn chuyên sâu chỉ xảy ra
/// sau khi người dùng chọn rõ một mục trong menu.
Future<T?> showOmniAnchoredMenu<T>({
  required BuildContext context,
  required Rect anchor,
  required WidgetBuilder builder,
  double width = 220,
  Key? menuKey,
  String semanticsLabel = 'Tuỳ chọn',
  bool dismissOnOutsideTap = true,
  bool scrollable = true,
}) {
  final motion = OmniMotion.enabled(context);

  // [anchor] được đo bằng RenderBox.localToGlobal nên route phải sống trên
  // root overlay. Nếu đẩy vào Navigator của từng nhánh shell, thanh rail làm
  // lệch tọa độ và lớp scrim không phủ được điều hướng toàn cục.
  return Navigator.of(context, rootNavigator: true).push<T>(
    _OmniAnchoredMenuRoute<T>(
      anchor: anchor,
      width: width,
      menuKey: menuKey,
      semanticsLabel: semanticsLabel,
      dismissOnOutsideTap: dismissOnOutsideTap,
      scrollable: scrollable,
      builder: builder,
      duration: motion ? _popDuration : Duration.zero,
    ),
  );
}

const _popDuration = Duration(milliseconds: 280);
const _fadeDuration = Duration(milliseconds: 200);
const _popCurve = Cubic(0.2, 0.9, 0.25, 1);

class _OmniAnchoredMenuRoute<T> extends PopupRoute<T> {
  _OmniAnchoredMenuRoute({
    required this.anchor,
    required this.width,
    required this.menuKey,
    required this.semanticsLabel,
    required this.dismissOnOutsideTap,
    required this.scrollable,
    required this.builder,
    required this.duration,
  });

  final Rect anchor;
  final double width;
  final Key? menuKey;
  final String semanticsLabel;
  final bool dismissOnOutsideTap;
  final bool scrollable;
  final WidgetBuilder builder;
  final Duration duration;

  @override
  Color? get barrierColor => null;

  @override
  bool get barrierDismissible => false;

  @override
  String? get barrierLabel => null;

  @override
  Duration get transitionDuration => duration;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    final media = MediaQuery.of(context);
    final size = media.size;
    final menuWidth = math.min(width, size.width - 24);
    final alignRight = anchor.center.dx >= size.width / 2;
    final preferredLeft = alignRight ? anchor.right - menuWidth : anchor.left;
    final left = preferredLeft.clamp(12.0, size.width - menuWidth - 12);
    final topLimit = media.padding.top + 12;
    final bottomLimit = size.height - media.padding.bottom - 12;
    final belowTop = anchor.bottom + 6;
    final aboveBottom = size.height - anchor.top + 6;
    final spaceBelow = bottomLimit - belowTop;
    final spaceAbove = anchor.top - 6 - topLimit;
    final openAbove = spaceBelow < 240 && spaceAbove > spaceBelow;
    final menuMaxHeight = math.max(0.0, openAbove ? spaceAbove : spaceBelow);
    final fade = CurvedAnimation(
      parent: animation,
      curve: Interval(
        0,
        _fadeDuration.inMilliseconds / _popDuration.inMilliseconds,
      ),
    );
    final pop = CurvedAnimation(parent: animation, curve: _popCurve);
    final scrim = OmniColors.byBrightness(
      context,
      OmniColors.ink.withValues(alpha: .22),
      Colors.black.withValues(alpha: .4),
    );

    return Stack(
      children: [
        Positioned.fill(child: _buildScrim(context, fade, scrim)),
        Positioned(
          top: openAbove ? null : belowTop,
          bottom: openAbove ? aboveBottom : null,
          left: left,
          child: AnimatedBuilder(
            animation: pop,
            builder: (context, child) {
              final t = pop.value;
              return Opacity(
                opacity: t.clamp(0.0, 1.0),
                child: Transform.translate(
                  offset: Offset(0, 8 * (1 - t)),
                  child: Transform.scale(
                    scale: .96 + .04 * t,
                    alignment: openAbove
                        ? (alignRight
                              ? Alignment.bottomRight
                              : Alignment.bottomLeft)
                        : (alignRight ? Alignment.topRight : Alignment.topLeft),
                    child: child,
                  ),
                ),
              );
            },
            child: _MenuSurface(
              key: menuKey,
              width: menuWidth,
              maxHeight: menuMaxHeight,
              semanticsLabel: semanticsLabel,
              scrollable: scrollable,
              child: Builder(builder: builder),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildScrim(
    BuildContext context,
    Animation<double> fade,
    Color scrim,
  ) {
    final blurred = FadeTransition(
      opacity: fade,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
        child: ColoredBox(color: scrim),
      ),
    );
    if (!dismissOnOutsideTap) {
      return ExcludeSemantics(child: AbsorbPointer(child: blurred));
    }
    final background = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(context).pop(),
      child: blurred,
    );
    return Semantics(
      button: true,
      label: 'Đóng',
      onTap: () => Navigator.of(context).pop(),
      child: background,
    );
  }
}

class _MenuSurface extends StatelessWidget {
  const _MenuSurface({
    super.key,
    required this.width,
    required this.maxHeight,
    required this.semanticsLabel,
    required this.scrollable,
    required this.child,
  });

  final double width;
  final double maxHeight;
  final String semanticsLabel;
  final bool scrollable;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const radius = BorderRadius.all(Radius.circular(8));

    return Container(
      width: width,
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            offset: const Offset(0, 12),
            blurRadius: 32,
            color: OmniColors.ink.withValues(alpha: .18),
          ),
        ],
      ),
      child: Material(
        color: scheme.surface,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: Semantics(
          scopesRoute: true,
          namesRoute: true,
          label: semanticsLabel,
          explicitChildNodes: true,
          child: scrollable ? SingleChildScrollView(child: child) : child,
        ),
      ),
    );
  }
}

/// Một dòng hành động trong [showOmniAnchoredMenu].
class OmniAnchoredMenuItem extends StatelessWidget {
  const OmniAnchoredMenuItem({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.divider = false,
    this.destructive = false,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool divider;
  final bool destructive;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = onTap != null;
    final color = !enabled
        ? scheme.onSurfaceVariant.withValues(alpha: .55)
        : destructive
        ? scheme.error
        : scheme.onSurface;

    return OmniPressScale(
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: divider
              ? BoxDecoration(
                  border: Border(
                    top: BorderSide(color: scheme.surfaceContainerHighest),
                  ),
                )
              : null,
          child: Row(
            children: [
              Icon(
                icon,
                size: OmniIconSize.md,
                color: !enabled
                    ? scheme.onSurfaceVariant.withValues(alpha: .45)
                    : destructive
                    ? scheme.error
                    : scheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: OmniType.body.copyWith(
                    fontWeight: FontWeight.w500,
                    color: color,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
        ),
      ),
    );
  }
}
