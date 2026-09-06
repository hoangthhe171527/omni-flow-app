/// Tên route của module công việc.
///
/// File này KHÔNG import gì, và đó là điểm của nó. Trước đây các hằng số này
/// là `static const` trên `TasksModule`, nên module nào muốn mở một màn công
/// việc phải import cả lớp module — kéo theo route, trang, provider, và một
/// cạnh trong đồ thị phụ thuộc. Hai cạnh như vậy đối nhau là một chu trình.
///
/// Một file hằng số không import gì thì không thể nằm trong chu trình nào.
/// `module_cycle_test.dart` canh chính điều đó.
library;

abstract final class TaskRoutes {
  static const list = 'tasks.list';
  static const detail = 'tasks.detail';
}
