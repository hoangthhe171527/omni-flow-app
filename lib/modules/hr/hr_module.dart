import 'package:flutter/material.dart';

import '../../core/module/module_route.dart';
import '../../core/module/nav_destination.dart';
import '../../core/module/omni_module.dart';
import '../../security/guard/access_requirement.dart';
import 'application/hr_providers.dart';
import 'domain/hr_permissions.dart';
import 'presentation/approvals_page.dart';
import 'presentation/clock_page.dart';
import 'presentation/cont_load_page.dart';
import 'presentation/payslip_page.dart';
import 'presentation/request_form_page.dart';
import 'presentation/requests_page.dart';
import 'presentation/team_bonus_page.dart';
import 'presentation/timesheet_page.dart';
import 'presentation/workshop_today_page.dart';
import 'routes.dart';

/// Phân hệ **Nhân sự** trên app (nhan-su-kpi/02 §6, 03 §5, 04 §7.3): chấm
/// công, công tháng, đơn từ, phiếu lương, thưởng đội; quản đốc thêm xưởng hôm
/// nay, duyệt đơn, ghi bốc cont.
class HrModule extends OmniModule {
  const HrModule();

  static const moduleId = 'hr';

  @override
  String get id => moduleId;

  @override
  String get title => 'Nhân sự';

  @override
  List<String> get permissions => HrPermissions.all;

  static const _self = AccessRequirement.all([HrPermissions.attendanceSelf]);
  static const _workshop = AccessRequirement.any(HrPermissions.workshop);
  static const _approve = AccessRequirement.any(HrPermissions.approve);
  static const _payslip = AccessRequirement.all([HrPermissions.payslipsSelf]);
  static const _kpi = AccessRequirement.all([HrPermissions.kpiSelf]);

  @override
  List<ModuleRoute> routes() => [
    ModuleRoute(
      path: HrRoutes.clockPath,
      name: HrRoutes.clock,
      access: _self,
      builder: (_, _) => const ClockPage(),
    ),
    ModuleRoute(
      path: HrRoutes.timesheetPath,
      name: HrRoutes.timesheet,
      access: _self,
      builder: (_, state) => TimesheetPage(
        initialMonth: state.uri.queryParameters['month'],
        openDate: state.uri.queryParameters['date'],
      ),
    ),
    ModuleRoute(
      path: HrRoutes.requestsPath,
      name: HrRoutes.requests,
      access: _self,
      builder: (_, _) => const RequestsPage(),
    ),
    ModuleRoute(
      path: HrRoutes.requestNewPath,
      name: HrRoutes.requestNew,
      access: _self,
      rootNavigator: true,
      builder: (_, state) => RequestFormPage(
        initialType: state.uri.queryParameters['type'],
        initialDate: state.uri.queryParameters['date'],
      ),
    ),
    ModuleRoute(
      path: HrRoutes.workshopPath,
      name: HrRoutes.workshop,
      access: _workshop,
      builder: (_, _) => const WorkshopTodayPage(),
    ),
    ModuleRoute(
      path: HrRoutes.approvalsPath,
      name: HrRoutes.approvals,
      access: _approve,
      builder: (_, state) =>
          ApprovalsPage(openId: state.uri.queryParameters['id']),
    ),
    ModuleRoute(
      path: HrRoutes.contLoadPath,
      name: HrRoutes.contLoad,
      access: _approve,
      rootNavigator: true,
      builder: (_, _) => const ContLoadPage(),
    ),
    ModuleRoute(
      path: HrRoutes.kpiPath,
      name: HrRoutes.kpi,
      access: _kpi,
      builder: (_, _) => const TeamBonusPage(),
    ),
    ModuleRoute(
      path: HrRoutes.payslipPath,
      name: HrRoutes.payslip,
      access: _payslip,
      builder: (_, state) =>
          PayslipPage(initialPeriod: state.uri.queryParameters['period']),
    ),
  ];

  @override
  List<ModuleNavEntry> navEntries() => [
    ModuleNavEntry(
      moduleId: moduleId,
      label: 'Xưởng hôm nay',
      icon: Icons.factory_outlined,
      selectedIcon: Icons.factory_rounded,
      routeName: HrRoutes.workshop,
      area: NavArea.hr,
      order: 1,
      access: _workshop,
      feature: HrFlags.attendance,
      capabilities: const [HrCapabilities.attendance],
    ),
    ModuleNavEntry(
      moduleId: moduleId,
      label: 'Duyệt đơn',
      icon: Icons.fact_check_outlined,
      selectedIcon: Icons.fact_check_rounded,
      routeName: HrRoutes.approvals,
      area: NavArea.hr,
      order: 2,
      access: _approve,
      feature: HrFlags.attendance,
      capabilities: const [HrCapabilities.attendance],
      badge: hrPendingApprovalsProvider,
      badgeTone: NavBadgeTone.alert,
    ),
    const ModuleNavEntry(
      moduleId: moduleId,
      label: 'Chấm công',
      icon: Icons.schedule_outlined,
      selectedIcon: Icons.schedule_rounded,
      routeName: HrRoutes.clock,
      area: NavArea.hr,
      order: 3,
      access: _self,
      feature: HrFlags.attendance,
      capabilities: [HrCapabilities.attendance],
    ),
    const ModuleNavEntry(
      moduleId: moduleId,
      label: 'Công tháng',
      icon: Icons.calendar_month_outlined,
      selectedIcon: Icons.calendar_month_rounded,
      routeName: HrRoutes.timesheet,
      area: NavArea.hr,
      order: 4,
      access: _self,
      feature: HrFlags.attendance,
      capabilities: [HrCapabilities.attendance],
    ),
    const ModuleNavEntry(
      moduleId: moduleId,
      label: 'Đơn từ',
      icon: Icons.description_outlined,
      selectedIcon: Icons.description_rounded,
      routeName: HrRoutes.requests,
      area: NavArea.hr,
      order: 5,
      access: _self,
      feature: HrFlags.attendance,
      capabilities: [HrCapabilities.attendance],
    ),
    const ModuleNavEntry(
      moduleId: moduleId,
      label: 'Phiếu lương',
      icon: Icons.receipt_long_outlined,
      selectedIcon: Icons.receipt_long_rounded,
      routeName: HrRoutes.payslip,
      area: NavArea.hr,
      order: 6,
      access: _payslip,
      feature: HrFlags.payroll,
      capabilities: [HrCapabilities.payroll],
    ),
    const ModuleNavEntry(
      moduleId: moduleId,
      label: 'Thưởng đội',
      icon: Icons.emoji_events_outlined,
      selectedIcon: Icons.emoji_events_rounded,
      routeName: HrRoutes.kpi,
      area: NavArea.hr,
      order: 7,
      access: _kpi,
      feature: HrFlags.kpiTeam,
      capabilities: [HrCapabilities.kpiTeam],
    ),
  ];
}
