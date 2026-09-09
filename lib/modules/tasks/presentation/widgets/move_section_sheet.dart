import 'package:flutter/material.dart';

import '../../../../design/components/components.dart';
import '../../../../design/tokens/tokens.dart';
import '../../domain/task.dart';

/// Chọn công đoạn mới cho một cây đàn.
///
/// Thay cho kéo thả thẻ giữa các cột. Trên điện thoại, kéo một thẻ qua ranh
/// giới trang tranh trực tiếp với cử chỉ lật trang của chính cái bảng — hai
/// thao tác cùng hướng, và người dùng đoán sai một nửa số lần.
///
/// Một danh sách thì không đoán sai lần nào, và nó cũng nói ra được thứ mà
/// kéo thả không nói được: đang ở đâu, có những đâu để đi.
Future<String?> showMoveSectionSheet({
  required BuildContext context,
  required List<TaskSection> sections,
  required String? current,
}) => showOmniSheet<String>(
  context: context,
  builder: (context) => _MoveSectionSheet(sections: sections, current: current),
);

class _MoveSectionSheet extends StatelessWidget {
  const _MoveSectionSheet({required this.sections, required this.current});

  final List<TaskSection> sections;
  final String? current;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            OmniSpacing.lg,
            OmniSpacing.sm,
            OmniSpacing.lg,
            OmniSpacing.md,
          ),
          child: Text(
            'Chuyển nhóm việc',
            style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        if (sections.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              OmniSpacing.lg,
              0,
              OmniSpacing.lg,
              OmniSpacing.xl,
            ),
            child: Text(
              'Kế hoạch này chưa khai báo nhóm việc nào.',
              style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
          )
        else
          for (final section in sections)
            ListTile(
              // 56dp: cùng sàn với dòng công đoạn trong chi tiết việc. Người
              // bấm nó cũng là người đang đứng ở bàn làm việc.
              minTileHeight: 56,
              leading: Icon(
                section.id == current
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: section.id == current
                    ? scheme.primary
                    : scheme.onSurfaceVariant,
              ),
              title: Text(
                section.name,
                style: text.bodyLarge?.copyWith(
                  fontWeight: section.id == current
                      ? FontWeight.w700
                      : FontWeight.w400,
                ),
              ),
              // Công đoạn hiện tại vẫn bấm được, và trả về chính nó. Khoá lại
              // buộc người dùng phải đoán vì sao một dòng không phản hồi.
              onTap: () => Navigator.of(context).pop(section.id),
            ),
        const SizedBox(height: OmniSpacing.sm),
      ],
    );
  }
}
