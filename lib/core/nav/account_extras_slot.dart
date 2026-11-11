import 'package:flutter/widgets.dart';

/// Chỗ cắm phần thêm cuối màn Tài khoản, do tầng app quyết định.
///
/// Khung ứng dụng (cờ `app_shell`) bỏ màn "Tất cả", nên "Cài đặt ứng dụng" và
/// "Trợ giúp" chuyển vào Tài khoản. Các dòng đó dùng thứ của tầng app (bậc hiệu
/// năng), mà module không được import `app/` — nên app cắm vào một lần ở gốc,
/// màn Tài khoản chỉ đặt [maybeOf] vào chỗ của nó. Không cắm thì không có gì.
class AccountExtrasSlot extends InheritedWidget {
  const AccountExtrasSlot({
    super.key,
    required this.builder,
    required super.child,
  });

  final WidgetBuilder builder;

  static WidgetBuilder? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AccountExtrasSlot>()?.builder;

  @override
  bool updateShouldNotify(AccountExtrasSlot oldWidget) =>
      builder != oldWidget.builder;
}
