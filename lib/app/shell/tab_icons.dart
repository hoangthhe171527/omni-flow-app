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
  'dashboard.home': OmniFillIcons.chartBar,
  'tasks.list': OmniFillIcons.checkSquare,
  'notifications.centre': OmniFillIcons.bell,
  // Bán hàng
  'inbox.list': OmniFillIcons.chatCircleDots,
  'customers.list': OmniFillIcons.userCircle,
  'opportunities.pipeline': OmniFillIcons.trendUp,
  'inventory.orders': OmniFillIcons.receipt,
  // Kho
  'inventory.stock': OmniFillIcons.package,
  'inventory.lots': OmniFillIcons.truck,
  'inventory.suppliers': OmniFillIcons.storefront,
  'inventory.reservations': OmniFillIcons.bookmarkSimple,
  'inventory.catalog': OmniFillIcons.shapes,
  'inventory.delivered': OmniFillIcons.checkCircle,
  'inventory.counts': OmniFillIcons.clipboardText,
  // Công việc
  'plans.teams': OmniFillIcons.kanban,
  'plans.timeline': OmniFillIcons.chartBarHorizontal,
  'plans.archived': OmniFillIcons.archive,
  // Tài chính
  'finance.expenses': OmniFillIcons.wallet,
  'finance.summary': OmniFillIcons.chartPieSlice,
  'finance.catalog': OmniFillIcons.tag,
  // Hệ thống
  'channels.list': OmniFillIcons.plugsConnected,
  'team.list': OmniFillIcons.users,
  'settings.permissions': OmniFillIcons.shieldCheck,
  'settings.background': OmniFillIcons.image,
  'settings.notifications': OmniFillIcons.bellRinging,
  // Nhân sự
  'hr.clock': OmniFillIcons.clock,
  'hr.timesheet': OmniFillIcons.calendar,
  'hr.requests': OmniFillIcons.fileText,
  'hr.payslip': OmniFillIcons.money,
  'hr.kpi': OmniFillIcons.trophy,
  'hr.workshop': OmniFillIcons.factory,
  'hr.approvals': OmniFillIcons.stamp,
};

/// Bản nét của [tabIcons], cùng khoá.
const tabIconsLine = <String, IconData>{
  // Bàn làm việc
  'dashboard.home': OmniLineIcons.chartBar,
  'tasks.list': OmniLineIcons.checkSquare,
  'notifications.centre': OmniLineIcons.bell,
  // Bán hàng
  'inbox.list': OmniLineIcons.chatCircleDots,
  'customers.list': OmniLineIcons.userCircle,
  'opportunities.pipeline': OmniLineIcons.trendUp,
  'inventory.orders': OmniLineIcons.receipt,
  // Kho
  'inventory.stock': OmniLineIcons.package,
  'inventory.lots': OmniLineIcons.truck,
  'inventory.suppliers': OmniLineIcons.storefront,
  'inventory.reservations': OmniLineIcons.bookmarkSimple,
  'inventory.catalog': OmniLineIcons.shapes,
  'inventory.delivered': OmniLineIcons.checkCircle,
  'inventory.counts': OmniLineIcons.clipboardText,
  // Công việc
  'plans.teams': OmniLineIcons.kanban,
  'plans.timeline': OmniLineIcons.chartBarHorizontal,
  'plans.archived': OmniLineIcons.archive,
  // Tài chính
  'finance.expenses': OmniLineIcons.wallet,
  'finance.summary': OmniLineIcons.chartPieSlice,
  'finance.catalog': OmniLineIcons.tag,
  // Hệ thống
  'channels.list': OmniLineIcons.plugsConnected,
  'team.list': OmniLineIcons.users,
  'settings.permissions': OmniLineIcons.shieldCheck,
  'settings.background': OmniLineIcons.image,
  'settings.notifications': OmniLineIcons.bellRinging,
  // Nhân sự
  'hr.clock': OmniLineIcons.clock,
  'hr.timesheet': OmniLineIcons.calendar,
  'hr.requests': OmniLineIcons.fileText,
  'hr.payslip': OmniLineIcons.money,
  'hr.kpi': OmniLineIcons.trophy,
  'hr.workshop': OmniLineIcons.factory,
  'hr.approvals': OmniLineIcons.stamp,
};

/// Ô cuối "Tất cả" và "Thêm" của thanh dưới.
const tabIconAll = OmniFillIcons.squaresFour;
const tabIconMore = OmniFillIcons.dotsThreeCircle;
const tabIconAllLine = OmniLineIcons.squaresFour;
const tabIconMoreLine = OmniLineIcons.dotsThreeCircle;

/// Icon đặc của một mục trên thanh tab; mục chưa khai (module mới) dùng icon
/// nét của chính nó để không bao giờ trống.
IconData tabIconOf(ModuleNavEntry entry) =>
    tabIcons[entry.routeName] ?? entry.icon;

/// Icon nét của một mục CHƯA chọn trên thanh tab.
IconData tabIconLineOf(ModuleNavEntry entry) =>
    tabIconsLine[entry.routeName] ?? entry.icon;

/// Icon đặc dùng chung cho thanh tab và màn Tất cả.
///
/// Mã ký tự trong `assets/fonts/PhosphorFill.ttf` (Phosphor Icons 2.1, bản
/// Fill), chép từ `phosphor_flutter` 2.1.0. Thêm icon: tra tên ở
/// phosphoricons.com, lấy mã từ `phosphor_icons_fill.dart` của gói đó.
abstract final class OmniFillIcons {
  static const _font = 'PhosphorFill';

  // Ô ứng dụng màn Ứng dụng (lưới iOS).
  static const desktop = IconData(0xe560, fontFamily: _font);
  static const gearSix = IconData(0xe272, fontFamily: _font);
  static const shoppingBag = IconData(0xe416, fontFamily: _font);
  static const usersThree = IconData(0xe68e, fontFamily: _font);

  // Dòng cài đặt / trợ giúp màn Tất cả.
  static const circleHalf = IconData(0xe18c, fontFamily: _font);
  static const fileMagnifyingGlass = IconData(0xe238, fontFamily: _font);
  static const info = IconData(0xe2ce, fontFamily: _font);
  static const question = IconData(0xe3e8, fontFamily: _font);
  static const sparkle = IconData(0xe6a2, fontFamily: _font);

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
  static const userCircle = IconData(0xe4c4, fontFamily: _font);
  static const users = IconData(0xe4d6, fontFamily: _font);
  static const wallet = IconData(0xe68a, fontFamily: _font);
}

/// Bản NÉT của [OmniFillIcons] (Phosphor Regular, cùng mã ký tự): icon mục
/// CHƯA chọn trên thanh tab — iOS vẽ mục chưa chọn bằng nét mảnh, mục đang
/// chọn bằng bản đặc.
abstract final class OmniLineIcons {
  static const _font = 'PhosphorRegular';

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
  static const userCircle = IconData(0xe4c4, fontFamily: _font);
  static const users = IconData(0xe4d6, fontFamily: _font);
  static const wallet = IconData(0xe68a, fontFamily: _font);
}
