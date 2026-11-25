/// Mặt công khai của phân hệ Nhân sự cho module khác (Tổng quan, Dòng việc).
/// Không xuất lớp module (xem `module_public_surface_test.dart`).
library;

export 'application/hr_providers.dart'
    show hrAccessProvider, hrKpiMeProvider, hrThisMonthProvider;
export 'domain/hr_models.dart' show KpiMe;
export 'domain/hr_permissions.dart' show HrAccess;
export 'presentation/widgets/hr_home_card.dart'
    show HrHomeCard, refreshHrHomeCard;
export 'presentation/widgets/team_kpi_card.dart' show TeamKpiCard;
export 'routes.dart';
