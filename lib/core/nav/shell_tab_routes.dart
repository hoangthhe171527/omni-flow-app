import 'package:flutter/widgets.dart';

/// Tên route mà khung ứng dụng đang mở sẵn ở thanh dưới hoặc sheet "Thêm".
///
/// Module không được import `app/`, nên màn của module hỏi qua đây để KHÔNG
/// vẽ thêm lối vào trùng trên header (rà soát 12/11/2026: Nhà cung cấp vừa là
/// tab vừa là nút trên header Hàng sắp về). Không có khung ứng dụng (cờ
/// `app_shell` tắt, thanh bên, bài kiểm một màn lẻ) → tập rỗng: màn giữ đủ lối
/// vào như cũ.
class ShellTabRoutes extends InheritedWidget {
  const ShellTabRoutes({super.key, required this.routes, required super.child});

  final Set<String> routes;

  static Set<String> of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ShellTabRoutes>()?.routes ??
      const {};

  /// Màn [routeName] đã có lối vào ở thanh dưới / "Thêm" của ứng dụng đang mở.
  static bool reachable(BuildContext context, String routeName) =>
      of(context).contains(routeName);

  @override
  bool updateShouldNotify(ShellTabRoutes oldWidget) =>
      !_sameSet(routes, oldWidget.routes);

  static bool _sameSet(Set<String> a, Set<String> b) =>
      a.length == b.length && a.containsAll(b);
}
