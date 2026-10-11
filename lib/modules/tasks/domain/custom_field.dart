import '../../../core/utils/json.dart';

/// Kiểu của một trường tuỳ chỉnh, đúng bốn giá trị `CreateProjectRequest`
/// bên API nhận (`in:text,number,date,select`).
enum CustomFieldType {
  text,
  number,
  date,
  select;

  /// Kiểu lạ (API về sau thêm kiểu mới) thì coi là chữ: hiện giá trị dạng chữ
  /// còn hơn giấu cả trường đi.
  static CustomFieldType parse(String? raw) {
    for (final type in values) {
      if (type.name == raw) return type;
    }
    return CustomFieldType.text;
  }
}

/// Định nghĩa MỘT trường tuỳ chỉnh của kế hoạch (`projects.custom_fields[]`).
///
/// Nằm ở module tasks chứ không ở plans: chi tiết việc cần đọc nó, và tasks
/// không được import plans (`module_cycle_test.dart`). Plans dùng lại kiểu này.
///
/// Giá trị của trường nằm trên VIỆC (`tasks.custom_fields`, một map theo
/// [id]); định nghĩa nằm trên KẾ HOẠCH.
class CustomFieldDef {
  const CustomFieldDef({
    required this.id,
    required this.name,
    this.type = CustomFieldType.text,
    this.options = const [],
  });

  factory CustomFieldDef.fromJson(Map<String, dynamic> json) => CustomFieldDef(
    id: json.strOr('id', ''),
    name: json.strOr('name', ''),
    type: CustomFieldType.parse(json.str('type')),
    options: json.strList('options'),
  );

  final String id;
  final String name;
  final CustomFieldType type;

  /// Lựa chọn của trường `select`; rỗng với kiểu khác.
  final List<String> options;

  /// Đúng khoá `UpdateProjectRequest` nhận: `options` chỉ gửi khi có.
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'type': type.name,
    if (options.isNotEmpty) 'options': options,
  };
}
