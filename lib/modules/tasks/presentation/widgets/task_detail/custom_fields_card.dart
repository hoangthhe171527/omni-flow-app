import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/utils/formatters.dart';
import '../../../application/tasks_providers.dart';
import '../../../domain/custom_field.dart';
import '../../../domain/task.dart';
import '../../../../../design/tokens/tokens.dart';
import 'detail_card.dart';

/// Thẻ Trường tuỳ chỉnh (mẫu đã duyệt "Trường tuỳ chỉnh – chi tiết việc"):
/// định nghĩa lấy từ kế hoạch (`planCustomFieldsProvider`), giá trị từ
/// `task.customFields`. Mỗi dòng 48: biểu tượng kiểu + nhãn 116, giá trị là
/// nút cả dòng; chưa có thì "Nhập {tên}" / "Chọn {tên}" mờ.
///
/// Việc trong kế hoạch LUÔN có thẻ, kể cả khi kế hoạch chưa khai báo trường
/// nào — trước đây thẻ ẩn hẳn và không ai biết tính năng này có. Khi trống:
/// người quản lý ([onManageFields] khác null) thấy nút "Thêm trường", thành
/// viên chỉ thấy một dòng báo ai thêm được.
///
/// Dòng "Khách" chỉ hiện khi việc có `customer_id`: tên khách nếu tài liệu
/// có `customer_name`, nếu không thì "Xem hồ sơ khách".
///
/// Ẩn cả thẻ khi: việc không thuộc kế hoạch và không có khách; hoặc chưa đọc
/// được kế hoạch (đang tải / lỗi) và không có khách — "chưa có trường nào"
/// khi thật ra là lỗi mạng thì sai.
class CustomFieldsCard extends ConsumerWidget {
  const CustomFieldsCard({
    super.key,
    required this.task,
    this.onEdit,
    this.onOpenCustomer,
    this.onManageFields,
  });

  final Task task;

  /// Chạm một trường để sửa. null = chỉ đọc.
  final ValueChanged<CustomFieldDef>? onEdit;

  /// Mở hồ sơ khách. null = chữ thường, không chạm được.
  final VoidCallback? onOpenCustomer;

  /// Mở trang khai báo trường của kế hoạch (chủ / quản lý). null = không có
  /// nút + ở đầu thẻ lẫn nút "Thêm trường".
  final VoidCallback? onManageFields;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectId = task.projectId;
    final loaded = projectId == null
        ? null
        : ref.watch(planCustomFieldsProvider(projectId)).valueOrNull;
    final defs = loaded ?? const <CustomFieldDef>[];
    final empty = loaded != null && loaded.isEmpty;
    final customerId = task.customerId;
    final hasCustomer = customerId != null && customerId.isNotEmpty;
    if (defs.isEmpty && !empty && !hasCustomer) return const SizedBox.shrink();

    final manage = projectId == null ? null : onManageFields;
    final iconColor = OmniTaskTones.of(context).fieldIcon;

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: DetailCard(
        children: [
          DetailCardHeader(
            icon: Icons.feed_outlined,
            title: 'Trường tuỳ chỉnh',
            actions: [
              if (manage != null)
                DetailHeaderButton(
                  tooltip: 'Quản lý trường của kế hoạch',
                  icon: Icons.add_rounded,
                  onPressed: manage,
                ),
            ],
          ),
          for (var i = 0; i < defs.length; i++)
            DetailRow(
              key: ValueKey('custom-field-${defs[i].id}'),
              label: defs[i].name,
              icon: customFieldIcon(defs[i].type),
              iconColor: iconColor,
              divider: true,
              child: _Value(
                text: displayCustomValue(
                  defs[i],
                  task.customFields[defs[i].id],
                ),
                placeholder: customFieldPlaceholder(defs[i]),
                onTap: onEdit == null ? null : () => onEdit!(defs[i]),
              ),
            ),
          if (empty) _Empty(onAdd: manage),
          if (hasCustomer)
            DetailRow(
              label: 'Khách',
              icon: Icons.person_outline_rounded,
              divider: true,
              child: _Customer(name: task.customerName, onTap: onOpenCustomer),
            ),
        ],
      ),
    );
  }
}

/// Biểu tượng của một kiểu trường; bốn kiểu, bốn biểu tượng khác nhau.
IconData customFieldIcon(CustomFieldType type) => switch (type) {
  CustomFieldType.select => Icons.arrow_drop_down_circle_outlined,
  CustomFieldType.text => Icons.text_fields_rounded,
  CustomFieldType.number => Icons.tag_rounded,
  CustomFieldType.date => Icons.calendar_today_outlined,
};

/// Chữ mờ khi trường chưa có giá trị: chọn trong danh sách / trên lịch thì
/// "Chọn …", gõ vào thì "Nhập …".
String customFieldPlaceholder(CustomFieldDef def) {
  final name = def.name.toLowerCase();

  return switch (def.type) {
    CustomFieldType.select || CustomFieldType.date => 'Chọn $name',
    CustomFieldType.text || CustomFieldType.number => 'Nhập $name',
  };
}

/// Kế hoạch chưa khai báo trường nào.
class _Empty extends StatelessWidget {
  const _Empty({required this.onAdd});

  /// null = thành viên: chỉ báo ai thêm được.
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final style = OmniType.bodySm.copyWith(color: detailSecondary(context));

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: OmniColors.trackOf(context))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            onAdd == null
                ? 'Kế hoạch này chưa có trường nào. Chủ hoặc quản lý kế hoạch '
                      'thêm được trong menu của kế hoạch.'
                : 'Kế hoạch này chưa có trường nào. Thêm trường như Hãng, '
                      'Model, Serial để mọi việc trong kế hoạch cùng ghi một '
                      'kiểu.',
            style: style,
          ),
          if (onAdd != null) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: onAdd,
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
              icon: const Icon(Icons.add_rounded, size: OmniIconSize.md),
              label: const Text('Thêm trường'),
            ),
          ],
        ],
      ),
    );
  }
}

/// Chữ hiện cho một giá trị: ngày `YYYY-MM-DD` thành `dd/MM/yyyy`, số bỏ
/// `.0` thừa. Rỗng / null thì null.
String? displayCustomValue(CustomFieldDef def, Object? raw) {
  if (raw == null) return null;
  final text = raw.toString().trim();
  if (text.isEmpty) return null;
  switch (def.type) {
    case CustomFieldType.date:
      final date = DateUtilsX.parse(text);
      return date == null ? text : Formatters.date(date);
    case CustomFieldType.number:
      if (raw is double && raw == raw.truncateToDouble()) {
        return raw.toInt().toString();
      }
      return text;
    case CustomFieldType.text:
    case CustomFieldType.select:
      return text;
  }
}

class _Value extends StatelessWidget {
  const _Value({required this.text, required this.placeholder, this.onTap});

  final String? text;
  final String placeholder;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final empty = text == null;
    final faint = OmniTaskTones.of(context).faint;
    final label = Text(
      empty ? (onTap == null ? '—' : placeholder) : text!,
      style: OmniType.bodySm.copyWith(color: empty ? faint : scheme.onSurface),
    );
    final box = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Align(alignment: Alignment.centerLeft, child: label),
    );
    if (onTap == null) return box;

    return InkWell(onTap: onTap, child: box);
  }
}

class _Customer extends StatelessWidget {
  const _Customer({required this.name, required this.onTap});

  final String? name;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final shown = (name ?? '').trim().isEmpty ? 'Xem hồ sơ khách' : name!;
    final color = onTap == null ? scheme.onSurface : scheme.primary;
    // Biểu tượng người nằm ở nhãn "Khách" (như các trường), không lặp ở đây.
    final box = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          shown,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: OmniType.bodySm.copyWith(
            color: color,
            fontWeight: onTap == null ? FontWeight.w400 : FontWeight.w500,
          ),
        ),
      ),
    );
    if (onTap == null) return box;

    return Semantics(
      link: true,
      child: InkWell(onTap: onTap, child: box),
    );
  }
}
