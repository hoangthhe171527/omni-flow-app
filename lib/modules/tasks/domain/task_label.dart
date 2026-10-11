import '../../../core/utils/json.dart';
import '../../../core/utils/text_search.dart';

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

  /// Trần độ dài mã của server (`SystemOptionCatalog::CODE_MAX`).
  static const codeMax = 100;

  /// Mã cho một nhãn mới, sinh từ tên: bỏ dấu, chữ thường, mọi chuỗi ký tự
  /// khác `[a-z0-9]` thành một `_`. Khớp regex server `^[a-z0-9_]+$`.
  ///
  /// Trùng một mã trong [taken] thì thêm `_2`, `_3`… — `CreateSystemOption`
  /// bên API không kiểm trùng mã, và hai nhãn cùng mã là hai nhãn không phân
  /// biệt được trên việc.
  static String codeFor(String name, {Set<String> taken = const {}}) {
    var base = foldDiacritics(
      name,
    ).replaceAll(RegExp('[^a-z0-9]+'), '_').replaceAll(RegExp(r'^_+|_+$'), '');
    if (base.isEmpty) base = 'nhan';
    if (base.length > codeMax) base = base.substring(0, codeMax);
    if (!taken.contains(base)) return base;

    for (var n = 2; ; n++) {
      final suffix = '_$n';
      final head = base.length + suffix.length > codeMax
          ? base.substring(0, codeMax - suffix.length)
          : base;
      final candidate = '$head$suffix';
      if (!taken.contains(candidate)) return candidate;
    }
  }
}
