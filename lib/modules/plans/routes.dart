/// Tên route của module dự án. Xem `tasks/routes.dart` về lý do file này
/// không import gì.
library;

abstract final class PlanRoutes {
  static const teams = 'plans.teams';
  static const board = 'plans.board';
  static const timeline = 'plans.timeline';

  /// Khai báo trường tuỳ chỉnh của một kế hoạch. Chi tiết việc mở trang này
  /// từ thẻ Trường tuỳ chỉnh mà không import module plans.
  static const fields = 'plans.fields';
}
