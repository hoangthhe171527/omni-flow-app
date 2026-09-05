import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../security/guard/access_requirement.dart';

/// Loại việc một mục điều hướng thuộc về.
///
/// Thứ tự khai báo ở đây LÀ thứ tự ưu tiên trên thanh tab. Đổi thứ tự các hằng
/// trong enum này là đổi cả app — cố ý như vậy: nó là một chỗ, một dòng, và
/// người đổi thấy ngay mình đang đổi cái gì.
///
/// Thứ tự hiện tại thiên về xưởng: người giữ đủ quyền thấy "Việc của tôi"
/// trước "Hộp thư".
enum NavArea {
  work('Công việc'),
  communication('Trao đổi'),
  sales('Bán hàng'),
  admin('Quản trị'),
  account('Tài khoản');

  const NavArea(this.label);

  /// Tiêu đề nhóm trong danh bạ "Tất cả".
  final String label;
}

/// Chỗ để sống, hay chỗ để ghé.
///
/// Đây là phán đoán tác giả module ĐƯỢC PHÉP đưa ra, vì nó không phụ thuộc
/// người dùng: "Kết nối kênh" là thứ cài một lần rồi cả năm không mở, với bất
/// kỳ ai. Còn "chính xác 4 mục nào lên tab" thì phụ thuộc người dùng, nên
/// không ai khai báo — nó được tính ra từ quyền.
///
/// Chỉ mục [primary] mới thành branch của shell và mới ghim được: một tab phải
/// giữ được ngăn xếp điều hướng riêng, và biến mọi mục thành branch nghĩa là
/// 20 module thành 20 navigator.
enum NavWeight { primary, secondary }

/// Một mục điều hướng do module khai báo.
///
/// Thay cho cặp `ModuleDestination` + `ModuleMenuEntry` cũ. Cặp đó bắt module
/// tự quyết định LÚC VIẾT CODE rằng mình là tab hay mục menu — một quyết định
/// phụ thuộc vào ai đang dùng, thứ module không thể biết. Hệ quả có thật: để
/// đưa Tasks lên tab, phải mở `opportunities_module.dart` ra sửa. Đến module
/// thứ 12 thì cách đó sập.
class ModuleNavEntry {
  const ModuleNavEntry({
    required this.moduleId,
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.routeName,
    required this.area,
    this.weight = NavWeight.secondary,
    this.order = 100,
    this.subtitle,
    this.access = const AccessRequirement.open(),
    this.badge,
  });

  final String moduleId;
  final String label;

  /// Dòng phụ trong danh bạ. Không hiện trên tab.
  final String? subtitle;

  final IconData icon;
  final IconData selectedIcon;

  /// Tên của [ModuleRoute] mục này mở. Cũng là khoá branch trong router.
  final String routeName;

  final NavArea area;

  /// Mặc định [NavWeight.secondary]: một module mới xuất hiện trong danh bạ mà
  /// không tự động tranh tab của người khác. Muốn tranh thì phải nói ra.
  final NavWeight weight;

  /// Chỉ so trong cùng một [area]. Không phải số toàn cục — không module nào
  /// phải đàm phán với module khác về một con số chung.
  final int order;

  final AccessRequirement access;

  /// Số đếm hiện trên tab. Là provider chứ không phải giá trị, để shell theo
  /// dõi được mà không cần biết nó đếm cái gì.
  final ProviderListenable<int>? badge;
}
