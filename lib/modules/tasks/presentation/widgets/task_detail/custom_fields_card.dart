import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/utils/formatters.dart';
import '../../../application/tasks_providers.dart';
import '../../../domain/custom_field.dart';
import '../../../domain/task.dart';
import '../../../../../design/tokens/tokens.dart';
import 'detail_card.dart';

/// Thẻ Trường tuỳ chỉnh (`TaskDetail.dc.html`): định nghĩa lấy từ kế hoạch
/// (`planCustomFieldsProvider`), giá trị từ `task.customFields`. Mỗi dòng 48:
/// nhãn 104 + giá trị là nút cả dòng; chưa có thì "Nhập {tên}" mờ.
///
/// Dòng "Khách" chỉ hiện khi việc có `customer_id`: tên khách nếu tài liệu
/// có `customer_name`, nếu không thì "Xem hồ sơ khách".
///
/// Kế hoạch không có trường nào và việc không có khách thì cả thẻ ẩn.
class CustomFieldsCard extends ConsumerWidget {
  const CustomFieldsCard({
    super.key,
    required this.task,
    this.onEdit,
    this.onOpenCustomer,
  });

  final Task task;

  /// Chạm một trường để sửa. null = chỉ đọc.
  final ValueChanged<CustomFieldDef>? onEdit;

  /// Mở hồ sơ khách. null = chữ thường, không chạm được.
  final VoidCallback? onOpenCustomer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectId = task.projectId;
    final defs = projectId == null
        ? const <CustomFieldDef>[]
        : ref.watch(planCustomFieldsProvider(projectId)).valueOrNull ??
              const <CustomFieldDef>[];
    final customerId = task.customerId;
    final hasCustomer = customerId != null && customerId.isNotEmpty;
    if (defs.isEmpty && !hasCustomer) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: DetailCard(
        children: [
          const DetailCardHeader(
            icon: Icons.feed_outlined,
            title: 'Trường tuỳ chỉnh',
          ),
          for (var i = 0; i < defs.length; i++)
            DetailRow(
              key: ValueKey('custom-field-${defs[i].id}'),
              label: defs[i].name,
              divider: i > 0,
              child: _Value(
                text: displayCustomValue(
                  defs[i],
                  task.customFields[defs[i].id],
                ),
                placeholder: 'Nhập ${defs[i].name.toLowerCase()}',
                onTap: onEdit == null ? null : () => onEdit!(defs[i]),
              ),
            ),
          if (hasCustomer)
            DetailRow(
              label: 'Khách',
              divider: defs.isNotEmpty,
              child: _Customer(name: task.customerName, onTap: onOpenCustomer),
            ),
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
    final box = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Row(
        children: [
          Icon(
            Icons.person_outline_rounded,
            size: OmniIconSize.sm,
            color: color,
          ),
          const SizedBox(width: 6),
          Flexible(
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
        ],
      ),
    );
    if (onTap == null) return box;

    return Semantics(
      link: true,
      child: InkWell(onTap: onTap, child: box),
    );
  }
}
