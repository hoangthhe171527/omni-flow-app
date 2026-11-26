import 'dart:ui' show ImageFilter;

import 'package:flutter/widgets.dart';

/// Bậc hiệu năng của giao diện kính (rà soát hiệu năng 08/11/2026).
///
/// Đo trên bản web ở CPU chậm ×4: tắt làm mờ đưa màn Tất cả từ 13,8 lên 58
/// khung/giây, Tổng quan từ 12 lên 39 — làm mờ (BackdropFilter) là gánh nặng
/// lớn nhất trên máy yếu, nhất là Android đời thấp chạy Skia/OpenGL.
///
/// - [full]: kính làm mờ đầy đủ (σ 8 từ Đợt 0, tăng bão hoà màu).
/// - [reduced]: làm mờ nhẹ (σ 4), không tăng bão hoà, lớp phủ toàn màn
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
  ///
  /// Mặc định 8 (token `glass` của Chuẩn Mobile UI, đã hạ từ 22 ở Đợt 0):
  /// nền kính đã đặc .86 nên mờ nhẹ là đủ, và rẻ hơn nhiều trên máy yếu.
  static double glassSigma(BuildContext context, {double full = 8}) =>
      tierOf(context) == OmniPerfTier.full
      ? full
      : (full * .55).roundToDouble();

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
