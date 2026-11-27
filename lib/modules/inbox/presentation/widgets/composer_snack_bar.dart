import 'package:flutter/material.dart';

import '../../../../design/components/components.dart';

/// Trang hội thoại đánh dấu thanh dưới đáy (composer, hoặc dòng "chỉ xem")
/// bằng [barKey], để toast nổi PHÍA TRÊN nó thay vì che nút Gửi.
///
/// Toast nổi của Scaffold đặt từ mép dưới thân trang; composer nằm trong
/// thân trang nên trước đây toast đè đúng lên ô nhập ~4 giây.
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

/// Lề để toast nổi cách mép trên của thanh [barKey] 8px. Không đo được thanh
/// (chưa dựng, hoặc ngoài trang hội thoại) thì `null` — dùng lề của theme.
EdgeInsets? marginAboveBar(GlobalKey? barKey) {
  final box = barKey?.currentContext?.findRenderObject();
  final height = box is RenderBox && box.attached && box.hasSize
      ? box.size.height
      : 0.0;
  return height > 0 ? EdgeInsets.fromLTRB(16, 5, 16, height + 8) : null;
}

/// [showOmniToast] nổi phía trên thanh [barKey].
void showToastAboveBar(
  BuildContext? context,
  String message, {
  GlobalKey? barKey,
  ScaffoldMessengerState? messenger,
}) {
  showOmniToast(
    context,
    message,
    messenger: messenger,
    margin: marginAboveBar(barKey),
  );
}

/// [showToastAboveBar] với khoá lấy từ [ComposerSnackBarScope] quanh
/// [context]; [messenger] đã giữ trước `await` thì truyền vào.
void showComposerToast(
  BuildContext context,
  String text, {
  ScaffoldMessengerState? messenger,
}) {
  showToastAboveBar(
    context,
    text,
    barKey: ComposerSnackBarScope.keyOf(context),
    messenger: messenger,
  );
}
