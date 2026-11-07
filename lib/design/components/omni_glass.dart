import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

/// Viên kính nổi kiểu "liquid glass" (`liquid-glass-uiux.html`, duyệt 07/11).
///
/// Mờ 22 + tăng bão hoà màu nền phía sau, viền sáng 1px, vệt sáng ở nửa trên,
/// bóng mềm. Chỉ dành cho phần NỔI (thanh tab, thanh trên): làm mờ cả danh
/// sách thì máy yếu ở xưởng giật.
///
/// Flutter chưa có Liquid Glass thật của iOS 26 (khúc xạ) — đây là bản dựng
/// lại chạy được cả Android. Chế độ tương phản cao: nền đặc, không mờ.
class OmniGlass extends StatelessWidget {
  const OmniGlass({
    super.key,
    required this.child,
    required this.radius,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;

  /// Màu viên chọn bên trong kính (mục đang chọn của thanh tab): trắng mờ.
  static Color selectionOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? Colors.white.withValues(alpha: 0.16)
      : Colors.white.withValues(alpha: 0.92);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final solid = MediaQuery.highContrastOf(context);
    final shape = BorderRadius.circular(radius);

    final fill = solid
        ? scheme.surface
        : dark
        ? const Color(0xFF182438).withValues(alpha: 0.55)
        : Colors.white.withValues(alpha: 0.72);
    final edge = dark
        ? Colors.white.withValues(alpha: 0.14)
        : Colors.white.withValues(alpha: 0.85);
    final highlight = dark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.white.withValues(alpha: 0.75);

    final body = DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: shape,
        border: Border.all(color: solid ? scheme.outline : edge),
        gradient: solid
            ? null
            : LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0, 0.55],
                colors: [highlight, highlight.withValues(alpha: 0)],
              ),
      ),
      child: Padding(padding: padding, child: child),
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: shape,
        // Bóng nhẹ: nền kính trong suốt nên bóng đậm lộ qua và làm kính xám.
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.28 : 0.07),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: shape,
        child: solid
            ? body
            : BackdropFilter(
                filter: ImageFilter.compose(
                  outer: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                  inner: const ColorFilter.matrix(_saturate180),
                ),
                child: body,
              ),
      ),
    );
  }
}

/// Ma trận tăng bão hoà 1.8× (như `saturate(180%)` của CSS).
const List<double> _saturate180 = <double>[
  1.6302, -0.5722, -0.0580, 0, 0, //
  -0.1698, 1.2278, -0.0580, 0, 0, //
  -0.1698, -0.5722, 1.7420, 0, 0, //
  0, 0, 0, 1, 0,
];
