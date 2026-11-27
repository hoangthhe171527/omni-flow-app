import 'package:flutter/widgets.dart';

/// Chiều cao thanh tab dưới mà shell đang phủ lên body (`extendBody`).
///
/// Scaffold lồng bên trong đặt nút nổi theo `viewPadding`, không theo phần đệm
/// đã nới của shell, nên nút nổi ở màn gốc của tab bị thanh kính mờ đè lên.
/// Ngoài shell (màn đẩy phủ lên, thanh rail rộng) giá trị là 0.
class ShellBarInset extends InheritedWidget {
  const ShellBarInset({super.key, required this.height, required super.child});

  /// Chiều cao viên kính của thanh tab (liquid glass).
  static const double pillHeight = 66;

  /// Phần thanh che lên body, chưa tính vùng an toàn: viên kính + khe 12 ở
  /// đáy (Scaffold đã tự cộng vùng an toàn).
  static const double barHeight = pillHeight + 12;

  final double height;

  static double of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ShellBarInset>()?.height ?? 0;

  /// Phần đáy màn bị che THẬT: trong shell là viên kính + đáy của nó (vùng an
  /// toàn, tối thiểu 12 — đúng như `_ShellNavBar` vẽ); ngoài shell chỉ là vùng
  /// an toàn.
  ///
  /// Lưu ý: `Scaffold(extendBody: true)` của `AppShell` tiêu thụ
  /// `viewPadding.bottom` khi bọc `body`, nên bên trong màn con
  /// `MediaQuery.viewPaddingOf(context).bottom` bằng 0. Vì vậy `AppShell` đo
  /// vùng an toàn bên ngoài `Scaffold` và truyền tổng chiều cao bị che qua
  /// [height]; hàm này lấy `max(inset, pillHeight + max(safe, 12))` để vừa đúng
  /// trong app thật vừa giữ nguyên hành vi cho các test dựng `ShellBarInset`
  /// trực tiếp với [barHeight].
  static double coveredBottom(BuildContext context) {
    final inset = of(context);
    final safe = MediaQuery.viewPaddingOf(context).bottom;
    if (inset <= 0) return safe;
    final fromSafe = pillHeight + (safe > 12 ? safe : 12);
    return inset > fromSafe ? inset : fromSafe;
  }

  /// Mép dưới của nút nổi / khay đáy: trên phần bị che một khe [gap].
  static double floatingBottom(BuildContext context, {double gap = 16}) =>
      coveredBottom(context) + gap;

  @override
  bool updateShouldNotify(ShellBarInset oldWidget) =>
      height != oldWidget.height;
}
