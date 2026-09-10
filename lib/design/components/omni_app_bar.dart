import 'package:flutter/material.dart';

/// Chỗ cắm cho nút tài khoản ở góc phải mọi [OmniAppBar].
///
/// Vì sao là một chỗ cắm chứ không phải một import thẳng: nút tài khoản cần
/// phiên đăng nhập và một lượt gọi mạng, tức là nó thuộc về `modules/`. Còn
/// `design/` thì CHỈ được phụ thuộc vào `core/` — nó là vốn từ dùng chung, và
/// một lớp nền tảng import ngược lên module là chỗ mọi thứ bắt đầu rối.
/// `test/architecture/design_layer_test.dart` giữ ranh giới đó.
///
/// Cắm MỘT lần ở gốc app (`omni_app.dart`), và từ đó mọi màn dựng
/// [OmniAppBar] đều có nút — không màn nào phải nhớ gì.
class OmniAccountSlot extends InheritedWidget {
  const OmniAccountSlot({
    super.key,
    required this.builder,
    required super.child,
  });

  final WidgetBuilder builder;

  /// Null khi chưa ai cắm gì — đúng trong bài kiểm widget của một màn lẻ, và
  /// [OmniAppBar] chỉ đơn giản không vẽ nút. Không ném lỗi: một AppBar không
  /// dựng được sẽ làm hỏng cả màn vì một thứ trang trí.
  static WidgetBuilder? maybeOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<OmniAccountSlot>()
          ?.builder;

  @override
  bool updateShouldNotify(OmniAccountSlot oldWidget) =>
      oldWidget.builder != builder;
}

/// AppBar của app, với nút tài khoản ở góc phải là MẶC ĐỊNH.
///
/// Vì sao là một widget chứ không phải một hàm trợ giúp để mỗi màn tự chèn vào
/// `actions:`: một mảnh thứ hai phải nhớ nối là đúng hình dạng lỗi đã sửa ở dự
/// án con "Dòng việc sống" — bốn trong năm chỗ đã quên `ref.watch` thứ hai của
/// tín hiệu realtime, và cái quên đó im lặng suốt nhiều tháng. Ở đây, quên
/// nghĩa là VẪN CÓ nút.
///
/// Chỉ dùng cho **màn gốc của các tab**. Màn chi tiết và form giữ `AppBar`
/// trơn: một nút tài khoản ở góc màn "Team mới" chỉ mời người ta đi lạc giữa
/// chừng một việc đang làm dở.
class OmniAppBar extends StatelessWidget implements PreferredSizeWidget {
  const OmniAppBar({
    super.key,
    required this.title,
    this.actions = const [],
    this.showAccount = true,
    this.bottom,
    this.backgroundColor,
    this.titleSpacing,
    this.toolbarHeight,
  });

  final String title;

  /// Nút riêng của màn. Chúng đứng TRƯỚC nút tài khoản: nút tài khoản là thứ
  /// luôn có mặt, nên nó thuộc về mép ngoài cùng và không được xê dịch theo
  /// từng màn.
  final List<Widget> actions;

  /// Chỉ tắt cho màn cố ý không muốn nút tài khoản.
  final bool showAccount;

  final PreferredSizeWidget? bottom;

  /// Ba tham số dưới đây chỉ là ống dẫn thẳng xuống [AppBar].
  ///
  /// Có mặt vì các màn gốc SẴN CÓ đang đặt chúng, và chuyển sang [OmniAppBar]
  /// mà bỏ qua là lặng lẽ đổi diện mạo của sáu màn — kiểu thay đổi không ai
  /// nhìn ra trong một bản diff, chỉ nhận ra khi mở app lên và thấy nó "hơi
  /// khác". Cố ý KHÔNG mở thêm ống dẫn nào ngoài ba cái đang thật sự dùng.
  final Color? backgroundColor;
  final double? titleSpacing;
  final double? toolbarHeight;

  @override
  Size get preferredSize => Size.fromHeight(
    (toolbarHeight ?? kToolbarHeight) + (bottom?.preferredSize.height ?? 0),
  );

  @override
  Widget build(BuildContext context) {
    final account = showAccount ? OmniAccountSlot.maybeOf(context) : null;

    return AppBar(
      title: Text(title),
      bottom: bottom,
      backgroundColor: backgroundColor,
      titleSpacing: titleSpacing,
      toolbarHeight: toolbarHeight,
      actions: [...actions, if (account != null) account(context)],
    );
  }
}
