import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../platform/omni_performance.dart';
import '../tokens/omni_colors.dart';

/// Lớp nổi của điều hướng: "kính phẳng" (bớt kính mờ, duyệt 26/11/2026 —
/// `docs/superpowers/specs/phong-cach-ios/bot-kinh-mo.html`).
///
/// Nền gần đặc .92 + nhoè nhẹ, viền mảnh, bóng mềm — không vệt sáng, không mép
/// sáng, không tăng bão hoà màu (dáng "liquid glass" cũ bị chê nặng, mờ nhạt).
/// Chỉ dùng cho thanh tab, thanh trên khi đã cuộn, thanh chọn nhiều, lớp nổi
/// trên ảnh. Menu, popover, khay nút đáy dùng [opaque]: nền đặc, không nhoè.
/// Chế độ tương phản cao: nền đặc, viền đậm.
class OmniGlass extends StatelessWidget {
  const OmniGlass({
    super.key,
    required this.child,
    required this.radius,
    this.padding = EdgeInsets.zero,
    this.blur = true,
    this.shadow = true,
    this.opaque = false,
  });

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;

  /// false: viên nhỏ (nút tròn 44 của thanh trên) — làm mờ σ22 trên 44px
  /// không nhìn ra khác biệt mà vẫn tốn một lớp BackdropFilter đè nội dung
  /// cuộn. Vẽ nền mờ đặc, giữ vệt sáng / mép sáng.
  final bool blur;

  /// false: bỏ bóng đổ ngoài (vd nút tròn trong thanh trên có chiều cao cố
  /// định 48, bóng blur 16 dễ bị cắt thành khung mờ chữ nhật).
  final bool shadow;

  /// true: nền đặc màu thẻ, không nhoè — menu, popover, khay nút đáy (nội
  /// dung phía sau không được loang qua chữ).
  final bool opaque;

  /// Màu mục đang chọn (phong cách iOS 25/11/2026): nền xanh nhạt của màu
  /// chính, không còn viên trắng mờ.
  static Color selectionOf(BuildContext context) {
    final theme = Theme.of(context);
    return theme.colorScheme.primary.withValues(
      alpha: theme.brightness == Brightness.dark ? 0.16 : 0.10,
    );
  }

  /// Mặt nút tự vẽ bậc "nhẹ" (spec phong cách iOS 25/11/2026 §3.2): nền xám
  /// đặc nhạt, không vệt sáng, không viền, không bóng. Kính chỉ còn dành cho
  /// lớp điều hướng (thanh tab, thanh trên khi cuộn, menu).
  static BoxDecoration buttonDecoration(
    BuildContext context, {
    double radius = 999,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    if (MediaQuery.highContrastOf(context)) {
      return BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: scheme.outline),
      );
    }
    return BoxDecoration(
      color: scheme.onSurface.withValues(
        alpha: theme.brightness == Brightness.dark ? .12 : .06,
      ),
      borderRadius: BorderRadius.circular(radius),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    // `solid`: tương phản cao (trợ năng) — nền đặc + viền đậm.
    // `noBlur`: [opaque], [blur] = false hoặc bậc hiệu năng tối giản.
    final solid = MediaQuery.highContrastOf(context);
    final noBlur = opaque || !blur || OmniPerformance.solidGlass(context);
    final shape = BorderRadius.circular(radius);

    final fill = solid || opaque
        ? scheme.surface
        // Token `glass` (gói Viomni, 26/11): nền .92 — đọc rõ chữ dưới nó,
        // nhoè nhẹ chỉ để mép nội dung cuộn qua không sắc.
        : dark
        ? const Color(0xFF132033).withValues(alpha: 0.92)
        : Colors.white.withValues(alpha: 0.92);
    final edge = solid
        ? scheme.outline
        : dark
        ? Colors.white.withValues(alpha: 0.08)
        : OmniColors.ink.withValues(alpha: 0.06);

    final body = DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: shape,
        border: Border.all(color: edge),
      ),
      child: Padding(padding: padding, child: child),
    );

    final sigma = OmniPerformance.glassSigma(context);
    final glass = noBlur || solid
        // Không làm mờ thì không cần ClipRRect (cắt bo góc tốn một lớp).
        ? body
        : ClipRRect(
            borderRadius: shape,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
              child: body,
            ),
          );

    // RepaintBoundary: đổi nội dung viên (huy hiệu, gõ chữ) không kéo vẽ lại
    // vùng chứa, và cuộn bên dưới không vẽ lại nội dung viên.
    return RepaintBoundary(
      child: shadow
          ? DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: shape,
                // Bóng mềm: lớp nổi tách khỏi nội dung bằng bóng, không bằng
                // nhoè. Nền đặc ([opaque]) cần bóng rõ hơn một chút.
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: dark ? 0.32 : (opaque ? 0.12 : 0.07),
                    ),
                    blurRadius: opaque ? 24 : 16,
                    offset: Offset(0, opaque ? 8 : 4),
                  ),
                ],
              ),
              child: glass,
            )
          : glass,
    );
  }
}

/// Dải mờ dần ở mép màn hình: nội dung chạy tới gần thanh trên / thanh tab
/// thì nhạt dần vào màu nền thay vì bị cắt sắc.
///
/// Chỉ dải màu từ trong suốt tới 85% ở sát mép — không nhoè (bớt kính mờ
/// 26/11/2026; lớp nhoè đè nội dung cuộn phải vẽ lại mỗi khung). Không nhận
/// chạm.
class OmniScrollEdge extends StatelessWidget {
  const OmniScrollEdge({super.key, required this.atTop});

  /// true = mép trên (đậm nhất ở trên cùng); false = mép dưới.
  final bool atTop;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).scaffoldBackgroundColor;
    final solid = MediaQuery.highContrastOf(context);
    return IgnorePointer(
      child: SizedBox.expand(
        child: DecoratedBox(
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
