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
        ? const Color(0xFF182438).withValues(alpha: 0.42)
        : Colors.white.withValues(alpha: 0.52);
    final edge = dark
        ? Colors.white.withValues(alpha: 0.14)
        : Colors.white.withValues(alpha: 0.85);
    final highlight = dark
        ? Colors.white.withValues(alpha: 0.16)
        : Colors.white.withValues(alpha: 0.85);

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
                stops: const [0, 0.45],
                colors: [highlight, highlight.withValues(alpha: 0)],
              ),
      ),
      // Đường sáng mảnh sát mép trên — "mép kính bắt sáng" như iOS.
      position: DecorationPosition.background,
      child: DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          borderRadius: shape,
          gradient: solid
              ? null
              : LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0, 0.06, 0.94, 1],
                  colors: [
                    Colors.white.withValues(alpha: dark ? 0.28 : 0.9),
                    Colors.white.withValues(alpha: 0),
                    Colors.white.withValues(alpha: 0),
                    Colors.black.withValues(alpha: dark ? 0.18 : 0.05),
                  ],
                ),
        ),
        child: Padding(padding: padding, child: child),
      ),
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

/// Dải mờ dần ở mép màn hình (scroll edge effect của iOS 26): nội dung chạy
/// tới gần thanh trên / thanh tab thì nhoè và nhạt dần thay vì bị cắt sắc.
///
/// Mờ tăng dần theo 3 dải (2 → 5 → 9) và phủ màu nền từ trong suốt tới 85% ở
/// sát mép. Không nhận chạm.
class OmniScrollEdge extends StatelessWidget {
  const OmniScrollEdge({super.key, required this.atTop});

  /// true = mép trên (đậm nhất ở trên cùng); false = mép dưới.
  final bool atTop;

  static const _sigmas = [2.0, 5.0, 9.0];

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).scaffoldBackgroundColor;
    final solid = MediaQuery.highContrastOf(context);
    // Thứ tự từ phía nội dung → mép màn hình.
    final strips = [
      for (final sigma in _sigmas)
        Expanded(
          child: solid
              ? const SizedBox.expand()
              : ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
                    child: const SizedBox.expand(),
                  ),
                ),
        ),
    ];

    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          Column(children: atTop ? strips.reversed.toList() : strips),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: atTop ? Alignment.bottomCenter : Alignment.topCenter,
                end: atTop ? Alignment.topCenter : Alignment.bottomCenter,
                colors: [
                  base.withValues(alpha: 0),
                  base.withValues(alpha: solid ? 1 : 0.85),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Màn có thân chạy BÊN DƯỚI [OmniTopBar] (`extendBodyBehindAppBar`) bọc thân
/// bằng widget này: nó ghi lại chiều cao thanh trên để danh sách cộng vào đệm
/// trên ([of]) và [OmniAsyncView] chừa chỗ cho trạng thái tải / trống / lỗi.
class OmniTopBarOverlap extends InheritedWidget {
  const OmniTopBarOverlap._({required this.inset, required super.child});

  /// Bọc thân màn; đọc chiều cao từ đệm trên mà Scaffold đã cộng thanh trên.
  static Widget wrap({required Widget child}) => Builder(
    builder: (context) => OmniTopBarOverlap._(
      inset: MediaQuery.paddingOf(context).top,
      child: child,
    ),
  );

  final double inset;

  /// Chiều cao thanh trên đè lên thân; 0 khi thân không chạy dưới thanh.
  static double of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<OmniTopBarOverlap>()?.inset ??
      0;

  @override
  bool updateShouldNotify(OmniTopBarOverlap oldWidget) =>
      inset != oldWidget.inset;
}

/// Thấu kính chọn bên trong kính (thanh tab, bộ chọn đoạn): viên trắng mờ
/// dạng viên thuốc, viền sáng, bóng nhẹ — mục đang chọn "nổi" trên kính.
class OmniGlassLens extends StatelessWidget {
  const OmniGlassLens({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: ShapeDecoration(
        shape: StadiumBorder(
          side: BorderSide(
            color: Colors.white.withValues(alpha: dark ? 0.22 : 0.95),
          ),
        ),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: dark
              ? [
                  Colors.white.withValues(alpha: 0.20),
                  Colors.white.withValues(alpha: 0.08),
                ]
              : [
                  Colors.white.withValues(alpha: 0.95),
                  Colors.white.withValues(alpha: 0.55),
                ],
        ),
        shadows: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.30 : 0.10),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
    );
  }
}
