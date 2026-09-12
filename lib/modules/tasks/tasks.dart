/// Mặt tiền công khai của module tasks.
///
/// Bảng dự án (module plans) hiển thị công việc và mở màn tạo việc — nó lấy
/// hai thứ đó ở đây, không với vào `presentation/` của tasks. Domain và
/// application của tasks vẫn import trực tiếp được (đó là kiểu dữ liệu và
/// provider, không phải màn hình); riêng widget và trang thì chỉ đi qua đây.
library;

export 'presentation/create_task_page.dart';
export 'presentation/widgets/task_card.dart';
