import 'package:flutter/foundation.dart';

import '../../../security/session/session.dart';

/// Quyền, cờ và khả năng API của Nhân sự (nhan-su-kpi/00 §7–§8).
///
/// Một mục chỉ hiện khi đủ BA điều: cờ công ty bật, bản API có khả năng, và
/// người dùng có quyền. Thiếu một là ẩn — không có màn nào chỉ để báo lỗi.
abstract final class HrPermissions {
  static const attendanceSelf = 'hr.attendance.self';
  static const attendanceRead = 'hr.attendance.read';
  static const attendanceManage = 'hr.attendance.manage';
  static const requestsApprove = 'hr.requests.approve';
  static const settingsManage = 'hr.settings.manage';
  static const payslipsSelf = 'hr.payslips.self';
  static const kpiSelf = 'kpi.team.self';

  static const all = [
    attendanceSelf,
    attendanceRead,
    attendanceManage,
    requestsApprove,
    settingsManage,
    payslipsSelf,
    kpiSelf,
  ];

  /// Xem xưởng hôm nay (API: `hr.attendance.read` hoặc `.manage`).
  static const workshop = [attendanceRead, attendanceManage];

  /// Duyệt đơn, ghi bốc cont, duyệt tăng ca chưa đăng ký.
  static const approve = [requestsApprove, attendanceManage];

  /// Thêm WiFi đang kết nối (`/hr/settings/wifi/capture`).
  static const wifiCapture = [settingsManage, requestsApprove];
}

/// Cờ công ty (`/auth/context` → `features`).
abstract final class HrFlags {
  static const kpiTeam = 'kpi_team_v2';
  static const attendance = 'hr_attendance';
  static const payroll = 'hr_payroll';
}

/// Khả năng API (`/auth/context` → `api_capabilities`).
abstract final class HrCapabilities {
  static const kpiTeam = 'kpi.team';
  static const attendance = 'hr.attendance';
  static const payroll = 'hr.payroll';
}

/// Những gì phiên hiện tại làm được ở Nhân sự — tính một lần từ [Session].
@immutable
class HrAccess {
  const HrAccess({
    this.clock = false,
    this.workshop = false,
    this.approve = false,
    this.wifiCapture = false,
    this.payslips = false,
    this.kpi = false,
  });

  factory HrAccess.of(Session s) {
    bool flag(String key) => s.featureEnabled(key);
    final att =
        flag(HrFlags.attendance) && s.apiSupports(HrCapabilities.attendance);
    final pay = flag(HrFlags.payroll) && s.apiSupports(HrCapabilities.payroll);
    final kpi = flag(HrFlags.kpiTeam) && s.apiSupports(HrCapabilities.kpiTeam);
    final p = s.policy;
    return HrAccess(
      clock: att && p.can(HrPermissions.attendanceSelf),
      workshop: att && p.canAny(HrPermissions.workshop),
      approve: att && p.canAny(HrPermissions.approve),
      wifiCapture: att && p.canAny(HrPermissions.wifiCapture),
      payslips: pay && p.can(HrPermissions.payslipsSelf),
      kpi: kpi && p.can(HrPermissions.kpiSelf),
    );
  }

  /// Chấm công, công tháng, đơn từ của chính mình.
  final bool clock;

  /// Quản đốc: xưởng hôm nay, nhắc chấm.
  final bool workshop;

  /// Quản đốc: duyệt đơn, ghi bốc cont, duyệt tăng ca chưa đăng ký.
  final bool approve;
  final bool wifiCapture;
  final bool payslips;
  final bool kpi;

  bool get any => clock || workshop || approve || payslips || kpi;

  @override
  bool operator ==(Object other) =>
      other is HrAccess &&
      other.clock == clock &&
      other.workshop == workshop &&
      other.approve == approve &&
      other.wifiCapture == wifiCapture &&
      other.payslips == payslips &&
      other.kpi == kpi;

  @override
  int get hashCode =>
      Object.hash(clock, workshop, approve, wifiCapture, payslips, kpi);
}
