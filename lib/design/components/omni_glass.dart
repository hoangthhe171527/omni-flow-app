import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../platform/omni_performance.dart';

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
    this.blur = true,
  });

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;

  /// false: viên nhỏ (nút tròn 44 của thanh trên) — làm mờ σ22 trên 44px
  /// không nhìn ra khác biệt mà vẫn tốn một lớp BackdropFilter đè nội dung
  /// cuộn. Vẽ nền mờ đặc, giữ vệt sáng / mép sáng.
  final bool blur;

  /// Màu viên chọn bên trong kính (mục đang chọn của thanh tab): trắng mờ.
  static Color selectionOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? Colors.white.withValues(alpha: 0.16)
      : Colors.white.withValues(alpha: 0.92);

  /// Mặt "nút kính" (liquid-buttons-uiux.html phương án B) cho nút tự vẽ:
  /// trắng mờ + vệt sáng nửa trên, mép sáng mảnh, bóng mềm — không viền
  /// màu. Cùng công thức với theme FilledButton/OutlinedButton.
  static BoxDecoration buttonDecoration(
    BuildContext context, {
    double radius = 999,
  }) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    if (MediaQuery.highContrastOf(context)) {
      final scheme = Theme.of(context).colorScheme;
      return BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: scheme.outline),
      );
    }
    return BoxDecoration(
      color: Colors.white.withValues(alpha: dark ? .12 : .82),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: Colors.white.withValues(alpha: dark ? .16 : .9),
      ),
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        stops: const [0, .5, 1],
        colors: [
          Colors.white.withValues(alpha: dark ? .14 : .7),
          Colors.white.withValues(alpha: dark ? .06 : .55),
          Colors.white.withValues(alpha: dark ? .08 : .78),
        ],
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: dark ? .35 : .10),
          blurRadius: 10,
          offset: const Offset(0, 3),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    // `solid`: tương phản cao (trợ năng) — nền đặc + viền đậm, không vệt sáng.
    // `noBlur`: thêm bậc hiệu năng tối giản / [blur] = false — bỏ làm mờ
    // nhưng GIỮ dáng kính (vệt sáng, mép sáng) với nền mờ đặc hơn bù lại.
    final solid = MediaQuery.highContrastOf(context);
    final noBlur = !blur || OmniPerformance.solidGlass(context);
    final shape = BorderRadius.circular(radius);

    final fill = solid
        ? scheme.surface
        : noBlur
        ? (dark
              ? const Color(0xFF1C2A42).withValues(alpha: 0.86)
              : Colors.white.withValues(alpha: 0.84))
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

    final sigma = OmniPerformance.glassSigma(context);
    // RepaintBoundary: đổi nội dung viên (huy hiệu, gõ chữ) không kéo vẽ lại
    // vùng chứa, và cuộn bên dưới không vẽ lại nội dung viên.
    return RepaintBoundary(
      child: DecoratedBox(
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
        child: noBlur || solid
            // Không làm mờ thì không cần ClipRRect (cắt bo góc tốn một lớp).
            ? body
            : ClipRRect(
                borderRadius: shape,
                child: BackdropFilter(
                  filter: OmniPerformance.saturate(context)
                      ? ImageFilter.compose(
                          outer: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
                          inner: const ColorFilter.matrix(_saturate180),
                        )
                      : ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
                  child: body,
                ),
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

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).scaffoldBackgroundColor;
    final solid = MediaQuery.highContrastOf(context);
    // MỘT lớp mờ σ6 ở nửa sát mép (trước: 3 dải σ2/5/9 = 3 BackdropFilter mỗi
    // mép, 6 lớp mỗi màn tab đè nội dung cuộn). Dải màu chuyển dần phía trên
    // vẫn tạo cảm giác "nhoè dần". Bậc hiệu năng thấp: chỉ dải màu.
    final blurStrip = OmniPerformance.edgeBlur(context)
        ? Expanded(
            child: RepaintBoundary(
              child: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          )
        : const Expanded(child: SizedBox.expand());
    final strips = [const Expanded(child: SizedBox.expand()), blurStrip];

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
