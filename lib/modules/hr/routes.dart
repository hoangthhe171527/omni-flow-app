/// Tên và đường dẫn màn Nhân sự. Tên route là khoá branch trong router và
/// được chép chuỗi ở `appItemSpecs` (app_shell_layout.dart).
abstract final class HrRoutes {
  static const clock = 'hr.clock';
  static const clockPath = '/hr/clock';

  /// Công tháng. `?month=YYYY-MM`, `?date=YYYY-MM-DD` mở sẵn sheet ngày.
  static const timesheet = 'hr.timesheet';
  static const timesheetPath = '/hr/timesheet';

  static const requests = 'hr.requests';
  static const requestsPath = '/hr/requests';

  /// Đơn mới (form toàn màn). `?type=phep|tangca|giaitrinh|tamung&date=`.
  static const requestNew = 'hr.requests.new';
  static const requestNewPath = '/hr/request-new';

  static const workshop = 'hr.workshop';
  static const workshopPath = '/hr/workshop';

  /// Duyệt đơn. `?id=` mở sẵn sheet đơn đó.
  static const approvals = 'hr.approvals';
  static const approvalsPath = '/hr/approvals';

  /// Ghi bốc cont (form toàn màn).
  static const contLoad = 'hr.cont';
  static const contLoadPath = '/hr/cont-new';

  /// Thưởng đội.
  static const kpi = 'hr.kpi';
  static const kpiPath = '/hr/kpi';

  /// Phiếu lương. `?period=YYYY-MM`.
  static const payslip = 'hr.payslip';
  static const payslipPath = '/hr/payslip';
}
