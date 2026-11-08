import 'package:flutter/material.dart';

import '../../../../design/components/components.dart';

/// Thao tác trực tiếp từ một dòng Team / Kế hoạch trong tab Việc.
enum WorkListAction { edit, delete }

/// Menu long-press gọn: mở thẳng thao tác của đúng thực thể, không có bước
/// trung gian chọn lại team hay kế hoạch.
///
/// [coverColor] / [subtitle] tuỳ chọn: nếu chỗ gọi có sẵn (màu nền kế hoạch,
/// "Team · n việc") thì đầu sheet hiện ô màu + dòng phụ.
Future<WorkListAction?> showWorkListActionsSheet(
  BuildContext context, {
  required String title,
  required String editLabel,
  required String deleteLabel,
  required bool canEdit,
  required bool canDelete,
  Color? coverColor,
  String? subtitle,
}) => showOmniSheet<WorkListAction>(
  context: context,
  builder: (_) => WorkListActionsSheet(
    title: title,
    editLabel: editLabel,
    deleteLabel: deleteLabel,
    canEdit: canEdit,
    canDelete: canDelete,
    coverColor: coverColor,
    subtitle: subtitle,
  ),
);

class WorkListActionsSheet extends StatelessWidget {
  const WorkListActionsSheet({
    super.key,
    required this.title,
    required this.editLabel,
    required this.deleteLabel,
    required this.canEdit,
    required this.canDelete,
    this.coverColor,
    this.subtitle,
  });

  final String title;
  final String editLabel;
  final String deleteLabel;
  final bool canEdit;
  final bool canDelete;
  final Color? coverColor;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return OmniSheetBody(
      semanticsLabel: 'Tuỳ chọn $title',
      header: OmniSheetHeader(
        title: title,
        subtitle: subtitle,
        leading: coverColor == null
            ? null
            : Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: coverColor,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
      ),
      children: [
        if (canEdit)
          OmniGroupSection(
            dividerIndent: 14,
            children: [
              OmniGroupRow(
                key: const Key('work-list-action-edit'),
                icon: Icons.edit_outlined,
                title: editLabel,
                chevron: false,
                onTap: () => Navigator.of(context).pop(WorkListAction.edit),
              ),
            ],
          ),
        if (canDelete)
          OmniGroupSection(
            dividerIndent: 14,
            children: [
              OmniGroupRow(
                key: const Key('work-list-action-delete'),
                icon: Icons.delete_outline_rounded,
                title: deleteLabel,
                destructive: true,
                onTap: () => Navigator.of(context).pop(WorkListAction.delete),
              ),
            ],
          ),
      ],
    );
  }
}
