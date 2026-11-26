import 'package:flutter/widgets.dart';

import '../../core/module/nav_destination.dart';

/// Icon ĐẶC của thanh tab (phương án C "đặc + nhãn", duyệt 26/11/2026 — xem
/// `docs/superpowers/specs/phong-cach-ios/icon-thanh-tab.html`): mọi mục trên
/// thanh dưới dùng icon đặc Phosphor Fill, mục chưa chọn màu mực, mục đang
/// chọn màu chính. Ngoài thanh tab (danh sách, sheet "Thêm", màn Tất cả) vẫn
/// dùng icon nét Lucide của [ModuleNavEntry.icon].
///
/// Khoá là tên route gốc, chép chuỗi như `tabLabels` để tầng shell không phải
/// import route của từng module. Người dùng ghim được MỌI mục lên thanh, nên
/// test `tab_icons_test.dart` ghim: mọi mục điều hướng phải có icon ở đây.
const tabIcons = <String, IconData>{
  // Bàn làm việc
  'dashboard.home': _Ph.chartBar,
  'tasks.list': _Ph.checkSquare,
  'notifications.centre': _Ph.bell,
  // Bán hàng
  'inbox.list': _Ph.chatCircleDots,
  'customers.list': _Ph.user,
  'opportunities.pipeline': _Ph.trendUp,
  'inventory.orders': _Ph.receipt,
  // Kho
  'inventory.stock': _Ph.package,
  'inventory.lots': _Ph.truck,
  'inventory.suppliers': _Ph.storefront,
  'inventory.reservations': _Ph.bookmarkSimple,
  'inventory.catalog': _Ph.shapes,
  'inventory.delivered': _Ph.checkCircle,
  'inventory.counts': _Ph.clipboardText,
  // Công việc
  'plans.teams': _Ph.kanban,
  'plans.timeline': _Ph.chartBarHorizontal,
  'plans.archived': _Ph.archive,
  // Tài chính
  'finance.expenses': _Ph.wallet,
  'finance.summary': _Ph.chartPieSlice,
  'finance.catalog': _Ph.tag,
  // Hệ thống
  'channels.list': _Ph.plugsConnected,
  'team.list': _Ph.users,
  'settings.permissions': _Ph.shieldCheck,
  'settings.background': _Ph.image,
  'settings.notifications': _Ph.bellRinging,
  // Nhân sự
  'hr.clock': _Ph.clock,
  'hr.timesheet': _Ph.calendar,
  'hr.requests': _Ph.fileText,
  'hr.payslip': _Ph.money,
  'hr.kpi': _Ph.trophy,
  'hr.workshop': _Ph.factory,
  'hr.approvals': _Ph.stamp,
};

/// Ô cuối "Tất cả" và "Thêm" của thanh dưới.
const tabIconAll = _Ph.squaresFour;
const tabIconMore = _Ph.dotsThreeCircle;

/// Icon đặc của một mục trên thanh tab; mục chưa khai (module mới) dùng icon
/// nét của chính nó để không bao giờ trống.
IconData tabIconOf(ModuleNavEntry entry) =>
    tabIcons[entry.routeName] ?? entry.icon;

/// Mã ký tự trong `assets/fonts/PhosphorFill.ttf` (Phosphor Icons 2.1, bản
/// Fill), chép từ `phosphor_flutter` 2.1.0. Thêm icon: tra tên ở
/// phosphoricons.com, lấy mã từ `phosphor_icons_fill.dart` của gói đó.
abstract final class _Ph {
  static const _font = 'PhosphorFill';

  static const archive = IconData(0xe00c, fontFamily: _font);
  static const bell = IconData(0xe0ce, fontFamily: _font);
  static const bellRinging = IconData(0xe5e8, fontFamily: _font);
  static const bookmarkSimple = IconData(0xe0ea, fontFamily: _font);
  static const calendar = IconData(0xe108, fontFamily: _font);
  static const chartBar = IconData(0xe150, fontFamily: _font);
  static const chartBarHorizontal = IconData(0xe152, fontFamily: _font);
  static const chartPieSlice = IconData(0xe15a, fontFamily: _font);
  static const chatCircleDots = IconData(0xe16c, fontFamily: _font);
  static const checkCircle = IconData(0xe184, fontFamily: _font);
  static const checkSquare = IconData(0xe186, fontFamily: _font);
  static const clipboardText = IconData(0xe198, fontFamily: _font);
  static const clock = IconData(0xe19a, fontFamily: _font);
  static const dotsThreeCircle = IconData(0xe200, fontFamily: _font);
  static const factory = IconData(0xe760, fontFamily: _font);
  static const fileText = IconData(0xe23a, fontFamily: _font);
  static const image = IconData(0xe2ca, fontFamily: _font);
  static const kanban = IconData(0xeb54, fontFamily: _font);
  static const money = IconData(0xe588, fontFamily: _font);
  static const package = IconData(0xe390, fontFamily: _font);
  static const plugsConnected = IconData(0xeb5a, fontFamily: _font);
  static const receipt = IconData(0xe3ec, fontFamily: _font);
  static const shapes = IconData(0xec5e, fontFamily: _font);
  static const shieldCheck = IconData(0xe40c, fontFamily: _font);
  static const squaresFour = IconData(0xe464, fontFamily: _font);
  static const stamp = IconData(0xea48, fontFamily: _font);
  static const storefront = IconData(0xe470, fontFamily: _font);
  static const tag = IconData(0xe478, fontFamily: _font);
  static const trendUp = IconData(0xe4ae, fontFamily: _font);
  static const trophy = IconData(0xe67e, fontFamily: _font);
  static const truck = IconData(0xe4b4, fontFamily: _font);
  static const user = IconData(0xe4c2, fontFamily: _font);
  static const users = IconData(0xe4d6, fontFamily: _font);
  static const wallet = IconData(0xe68a, fontFamily: _font);
}
