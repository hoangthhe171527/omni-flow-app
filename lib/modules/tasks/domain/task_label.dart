import '../../../core/utils/json.dart';

/// Một nhãn trong bộ nhãn của công ty (`system_options`, `group_key =
/// TASK_LABEL`).
///
/// Việc chỉ lưu [code] trong `labels[]`; tên và màu tra từ danh mục này. Màu
/// là chuỗi hex do server trả — tầng trình bày đổi nó qua
/// `OmniLabelColors.parseHex`, không parse ở đây.
class TaskLabel {
  const TaskLabel({
    required this.id,
    required this.code,
    required this.label,
    this.color,
    this.isSystem = false,
  });

  factory TaskLabel.fromJson(Map<String, dynamic> json) => TaskLabel(
    id: json.strOr('id', ''),
    code: json.strOr('code', ''),
    label: json.str('label') ?? json.strOr('code', ''),
    color: json.str('color'),
    isSystem: json.flag('is_system'),
  );

  /// Id của bản ghi `system_options` — đường sửa (`PUT /system-options/{id}`)
  /// đi theo id, không theo mã.
  final String id;

  /// Mã lưu trên việc. Không đổi được sau khi tạo (server bỏ qua `code` khi
  /// sửa).
  final String code;
  final String label;
  final String? color;

  /// Nhãn mặc định của hệ thống: không xoá được.
  final bool isSystem;
}
