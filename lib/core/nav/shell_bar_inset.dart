import 'package:flutter/widgets.dart';

/// Chiều cao thanh tab dưới mà shell đang phủ lên body (`extendBody`).
///
/// Scaffold lồng bên trong đặt nút nổi theo `viewPadding`, không theo phần đệm
/// đã nới của shell, nên nút nổi ở màn gốc của tab bị thanh kính mờ đè lên.
/// Ngoài shell (màn đẩy phủ lên, thanh rail rộng) giá trị là 0.
class ShellBarInset extends InheritedWidget {
  const ShellBarInset({super.key, required this.height, required super.child});

  /// Chiều cao cố định của thanh, chưa tính vùng an toàn (Scaffold đã tự cộng).
  static const double barHeight = 62;

  final double height;

  static double of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ShellBarInset>()?.height ?? 0;

  @override
  bool updateShouldNotify(ShellBarInset oldWidget) =>
      height != oldWidget.height;
}

/// Nâng một nút nổi lên trên thanh tab của shell; ngoài shell không làm gì.
class ShellFabLift extends StatelessWidget {
  const ShellFabLift({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: ShellBarInset.of(context)),
      child: child,
    );
  }
}
