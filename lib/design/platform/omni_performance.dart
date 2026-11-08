import 'dart:ui' show ImageFilter;

import 'package:flutter/widgets.dart';

/// Bậc hiệu năng của giao diện kính (rà soát hiệu năng 08/11/2026).
///
/// Đo trên bản web ở CPU chậm ×4: tắt làm mờ đưa màn Tất cả từ 13,8 lên 58
/// khung/giây, Tổng quan từ 12 lên 39 — làm mờ (BackdropFilter) là gánh nặng
/// lớn nhất trên máy yếu, nhất là Android đời thấp chạy Skia/OpenGL.
///
/// - [full]: kính làm mờ đầy đủ (σ 22, tăng bão hoà màu).
/// - [reduced]: làm mờ nhẹ (σ 12), không tăng bão hoà, lớp phủ toàn màn
///   không làm mờ, tắt hiệu ứng chữ hiện dần khi cuộn.
/// - [minimal]: không làm mờ ở đâu cả — kính là nền mờ đặc, vẫn giữ viền sáng
///   và vệt sáng nên vẫn ra dáng kính.
enum OmniPerfTier { full, reduced, minimal }

/// Cấp [OmniPerfTier] cho cây widget. Đặt một lần trong `MaterialApp.builder`.
/// Không có scope thì coi là [OmniPerfTier.full] (bài kiểm, màn đứng riêng).
class OmniPerformanceScope extends InheritedWidget {
  const OmniPerformanceScope({
    super.key,
    required this.tier,
    required super.child,
  });

  final OmniPerfTier tier;

  @override
  bool updateShouldNotify(OmniPerformanceScope oldWidget) =>
      tier != oldWidget.tier;
}

/// Một chỗ duy nhất để component hỏi "được làm mờ không, mờ bao nhiêu".
abstract final class OmniPerformance {
  static OmniPerfTier tierOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<OmniPerformanceScope>()
          ?.tier ??
      OmniPerfTier.full;

  /// Kính vẽ nền đặc, không BackdropFilter: tương phản cao (trợ năng — có
  /// thêm viền) hoặc bậc [OmniPerfTier.minimal].
  static bool solidGlass(BuildContext context) =>
      MediaQuery.highContrastOf(context) ||
      tierOf(context) == OmniPerfTier.minimal;

  /// Độ mờ của viên kính / sheet / menu. Chỉ có nghĩa khi ![solidGlass].
  static double glassSigma(BuildContext context, {double full = 22}) =>
      tierOf(context) == OmniPerfTier.full
      ? full
      : (full * .55).roundToDouble();

  /// Tăng bão hoà màu sau kính (thêm một lượt lọc màu) — chỉ ở bậc đầy đủ.
  static bool saturate(BuildContext context) =>
      tierOf(context) == OmniPerfTier.full;

  /// Lớp phủ toàn màn sau menu / xem trước được làm mờ — chỉ ở bậc đầy đủ.
  /// Bậc khác: phủ màu, không mờ (toàn màn là lớp mờ đắt nhất).
  static bool scrimBlur(BuildContext context) =>
      tierOf(context) == OmniPerfTier.full &&
      !MediaQuery.highContrastOf(context);

  /// Dải mờ dần ở mép màn có làm mờ thật không (bậc khác: chỉ dải màu).
  static bool edgeBlur(BuildContext context) =>
      tierOf(context) == OmniPerfTier.full &&
      !MediaQuery.highContrastOf(context);

  /// Hiệu ứng mục hiện dần khi cuộn vào (mỗi mục một lớp mờ dần).
  static bool riseOnScroll(BuildContext context) =>
      tierOf(context) == OmniPerfTier.full;
}

/// Lớp làm mờ nền tuân theo bậc hiệu năng: bậc tối giản / tương phản cao trả
/// thẳng [child] (không BackdropFilter), bậc giảm hạ [sigma] còn ~55%.
/// Dùng cho mặt kính tự vẽ trong module (menu tin nhắn, xem trước hội thoại).
class OmniBackdropBlur extends StatelessWidget {
  const OmniBackdropBlur({super.key, required this.sigma, required this.child});

  final double sigma;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (OmniPerformance.solidGlass(context)) return child;
    final s = OmniPerformance.glassSigma(context, full: sigma);
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: s, sigmaY: s),
      child: child,
    );
  }
}
