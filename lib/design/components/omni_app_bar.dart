import 'package:flutter/material.dart';

import 'omni_glass.dart';
import 'omni_top_bar.dart';

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
    this.tileBuilder,
    required super.child,
  });

  final WidgetBuilder builder;

  /// Biến thể avatar tròn 36 chữ cái đầu, dành cho [OmniTopBar].
  final WidgetBuilder? tileBuilder;

  static WidgetBuilder? maybeTileOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<OmniAccountSlot>()
      ?.tileBuilder;

  /// Null khi chưa ai cắm gì — đúng trong bài kiểm widget của một màn lẻ, và
  /// [OmniAppBar] chỉ đơn giản không vẽ nút. Không ném lỗi: một AppBar không
  /// dựng được sẽ làm hỏng cả màn vì một thứ trang trí.
  static WidgetBuilder? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<OmniAccountSlot>()?.builder;

  @override
  bool updateShouldNotify(OmniAccountSlot oldWidget) =>
      oldWidget.builder != builder || oldWidget.tileBuilder != tileBuilder;
}

/// Thanh trên của các màn còn lại, kiểu nút kính rời (viomni-apple-uiux.html,
/// duyệt 07/11) — dựng bằng [OmniTopBar] để mọi màn cùng một diện mạo:
///
///  * Màn ĐẨY VÀO (quay lại được): kiểu màn con — nút kính quay lại (hoặc ✕
///    khi [close]), tiêu đề 17/600 ở giữa, nút riêng của màn bên phải, không
///    chuông/tài khoản: chúng chỉ mời người ta đi lạc giữa một việc dở.
///  * Màn GỐC: tiêu đề lớn bên trái, nút riêng, chuông và tài khoản.
///
/// Nút riêng ([actions]) tự được bọc viên kính ([OmniGlassAction]); [bottom]
/// vẽ ngay dưới hàng tiêu đề (không coi là ô tìm).
class OmniAppBar extends StatelessWidget implements PreferredSizeWidget {
  const OmniAppBar({
    super.key,
    required this.title,
    this.actions = const [],
    this.showAccount = true,
    this.bottom,
    this.close = false,
    // Ba tham số dưới đây thuộc AppBar cũ; giữ để màn cũ dựng được, không còn
    // tác dụng với thanh kính.
    this.backgroundColor,
    this.titleSpacing,
    this.toolbarHeight,
    this.centerTitle = false,
  });

  final String title;

  /// Nút riêng của màn, đứng trước chuông / tài khoản.
  final List<Widget> actions;

  /// Chỉ tắt cho màn cố ý không muốn nút tài khoản.
  final bool showAccount;

  final PreferredSizeWidget? bottom;

  /// Form tạo/sửa toàn màn: nút đóng ✕ thay cho mũi tên quay lại.
  final bool close;

  final Color? backgroundColor;
  final double? titleSpacing;
  final double? toolbarHeight;
  final bool centerTitle;

  OmniTopBar _bar(bool canPop, VoidCallback? back) => OmniTopBar(
    semanticsTitle: title,
    onBack: canPop ? back : null,
    backIcon: close ? Icons.close_rounded : null,
    showAccount: showAccount,
    searchBottom: false,
    bottom: bottom,
    actions: [for (final a in actions) OmniGlassAction(child: a)],
  );

  @override
  Size get preferredSize => _bar(false, null).preferredSize;

  @override
  Widget build(BuildContext context) {
    final canPop = ModalRoute.of(context)?.canPop ?? false;
    return _bar(canPop, () => Navigator.of(context).maybePop());
  }
}

/// Bọc một nút có sẵn (IconButton, TextButton "Lưu") thành viên kính cao 44:
/// tròn khi là nút biểu tượng, viên thuốc khi có chữ.
class OmniGlassAction extends StatelessWidget {
  const OmniGlassAction({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return OmniGlass(
      radius: 22,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        child: Center(widthFactor: 1, child: child),
      ),
    );
  }
}
