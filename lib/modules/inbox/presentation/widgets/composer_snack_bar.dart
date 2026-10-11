import 'package:flutter/material.dart';

/// Trang hội thoại đánh dấu thanh dưới đáy (composer, hoặc dòng "chỉ xem")
/// bằng [barKey], để snackbar nổi PHÍA TRÊN nó thay vì che nút Gửi.
///
/// Snackbar nổi của Scaffold đặt từ mép dưới thân trang; composer nằm trong
/// thân trang nên trước đây snackbar đè đúng lên ô nhập ~4 giây.
class ComposerSnackBarScope extends InheritedWidget {
  const ComposerSnackBarScope({
    super.key,
    required this.barKey,
    required super.child,
  });

  final GlobalKey barKey;

  static GlobalKey? keyOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<ComposerSnackBarScope>()?.barKey;

  @override
  bool updateShouldNotify(ComposerSnackBarScope oldWidget) =>
      barKey != oldWidget.barKey;
}

/// Snackbar nổi, cách mép trên của thanh [barKey] 8px. Không đo được thanh
/// (chưa dựng, hoặc ngoài trang hội thoại) thì dùng lề mặc định của theme.
SnackBar snackAboveBar(
  Widget content, {
  GlobalKey? barKey,
  SnackBarAction? action,
  Duration duration = const Duration(milliseconds: 4000),
}) {
  final box = barKey?.currentContext?.findRenderObject();
  final height = box is RenderBox && box.attached && box.hasSize
      ? box.size.height
      : 0.0;
  return SnackBar(
    content: content,
    action: action,
    duration: duration,
    behavior: SnackBarBehavior.floating,
    margin: height > 0 ? EdgeInsets.fromLTRB(16, 5, 16, height + 8) : null,
  );
}

/// [snackAboveBar] với khoá lấy từ [ComposerSnackBarScope] quanh [context].
SnackBar composerSnackBar(BuildContext context, String text) =>
    snackAboveBar(Text(text), barKey: ComposerSnackBarScope.keyOf(context));
