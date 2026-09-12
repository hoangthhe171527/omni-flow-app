/// Mặt tiền công khai của module settings.
///
/// Module khác import file này, không với sâu hơn. Hiện chỉ có một thứ được
/// chia sẻ: `SurfaceBackdrop` — nền cả app mà chat và bảng dự án bọc thân
/// mình vào. Provider `backgroundProvider` vẫn là việc nội bộ của settings;
/// màn khác không cần biết nền được lưu ở đâu.
library;

export 'presentation/widgets/surface_backdrop.dart';
