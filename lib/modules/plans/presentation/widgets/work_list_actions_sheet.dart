import 'package:flutter/material.dart';

import '../../../../design/components/components.dart';
import '../../../../design/tokens/tokens.dart';

/// Thao tác trực tiếp từ một dòng Team / Kế hoạch trong tab Việc.
enum WorkListAction { edit, delete }

/// Menu long-press gọn: mở thẳng thao tác của đúng thực thể, không có bước
/// trung gian chọn lại team hay kế hoạch.
Future<WorkListAction?> showWorkListActionsSheet(
  BuildContext context, {
  required String title,
  required String editLabel,
  required String deleteLabel,
  required bool canEdit,
  required bool canDelete,
}) => showOmniSheet<WorkListAction>(
  context: context,
  builder: (_) => WorkListActionsSheet(
    title: title,
    editLabel: editLabel,
    deleteLabel: deleteLabel,
    canEdit: canEdit,
    canDelete: canDelete,
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
  });

  final String title;
  final String editLabel;
  final String deleteLabel;
  final bool canEdit;
  final bool canDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      label: 'Tuỳ chọn $title',
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 2, 8, 10),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: OmniType.bodyStrong.copyWith(
                      color: scheme.onSurface,
                    ),
                  ),
                ),
              ),
              Material(
                color: scheme.surface,
                borderRadius: OmniRadius.lgAll,
                clipBehavior: Clip.antiAlias,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (canEdit)
                      _ActionRow(
                        action: WorkListAction.edit,
                        icon: Icons.edit_outlined,
                        label: editLabel,
                      ),
                    if (canEdit && canDelete)
                      Divider(
                        height: 1,
                        thickness: 1,
                        indent: 52,
                        color: scheme.surfaceContainerHighest,
                      ),
                    if (canDelete)
                      _ActionRow(
                        action: WorkListAction.delete,
                        icon: Icons.delete_outline_rounded,
                        label: deleteLabel,
                        destructive: true,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.action,
    required this.icon,
    required this.label,
    this.destructive = false,
  });

  final WorkListAction action;
  final IconData icon;
  final String label;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = destructive ? OmniColors.dangerTextOf(context) : null;

    return InkWell(
      key: Key('work-list-action-${action.name}'),
      onTap: () => Navigator.of(context).pop(action),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              Icon(
                icon,
                size: OmniIconSize.lg,
                color: color ?? scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: OmniType.body.copyWith(
                    fontWeight: FontWeight.w500,
                    color: color ?? scheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
