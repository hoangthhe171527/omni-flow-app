/// Bản demo cho kiểm thử khép kín: bật bằng `--dart-define=DEMO_MODE=true`.
///
/// App bỏ qua đăng nhập, vào thẳng một workspace mẫu và nói chuyện với một
/// "máy chủ" nằm trong bộ nhớ ([DemoApiAdapter]) thay cho API thật. Thêm/sửa/
/// xoá chỉ sống tới khi tắt app — không có gì ghi lên máy chủ nào.
const bool kDemoMode = bool.fromEnvironment('DEMO_MODE');
