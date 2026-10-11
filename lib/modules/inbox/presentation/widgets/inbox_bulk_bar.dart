import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../design/components/components.dart';
import '../../../../design/tokens/tokens.dart';
import '../../application/bulk_assign.dart';
import '../../application/inbox_providers.dart';
import '../../data/inbox_api.dart';
import 'assign_sheet.dart';
import 'conversation_actions.dart';

/// Bulk actions on selected conversations: assign in one go, or apply a label.
/// Triage on mobile is done in batches — one thread at a time is how a 200-row
/// inbox stays a 200-row inbox.
class InboxBulkBar extends ConsumerWidget {
  const InboxBulkBar({
    super.key,
    required this.selectedIds,
    required this.allIds,
    required this.onSelectAll,
    required this.onDone,
  });

  final List<String> selectedIds;
  final List<String> allIds;
  final ValueChanged<List<String>> onSelectAll;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: EdgeInsets.fromLTRB(
        OmniSpacing.lg,
        OmniSpacing.md,
        OmniSpacing.lg,
        OmniSpacing.md + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: BoxDecoration(
        color: scheme.surface,
        // A hairline, and no shadow. OmniShadows.sheet threw a dark halo that
        // does nothing on a dark canvas except muddy the edge, and the bar is
        // already separated by the rule and by sitting against the list.
        border: Border(
          top: BorderSide(color: scheme.outline.withValues(alpha: 0.5)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Đã chọn ${selectedIds.length}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: OmniType.body.copyWith(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton(
                onPressed: onDone,
                style: TextButton.styleFrom(
                  minimumSize: const Size(48, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Bỏ chọn'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Actions are allowed to move to a second line. A fixed Row here
          // made the selection footer overflow on narrow Android screens.
          Wrap(
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 4,
            runSpacing: 4,
            children: [
              TextButton(
                onPressed: allIds.isEmpty
                    ? null
                    : () => onSelectAll(
                        selectedIds.length == allIds.length ? const [] : allIds,
                      ),
                style: TextButton.styleFrom(
                  minimumSize: const Size(48, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  selectedIds.length == allIds.length
                      ? 'Bỏ tất cả'
                      : 'Chọn tất cả',
                ),
              ),
              _BulkAction(
                icon: Icons.person_add_alt_rounded,
                label: 'Gán',
                onTap: () => _assign(context, ref),
              ),
              _BulkAction(
                icon: Icons.sell_outlined,
                label: 'Gắn nhãn',
                onTap: () => _label(context, ref),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _assign(BuildContext context, WidgetRef ref) async {
    // Captured before the awaits: the sheet that owned `context` is gone by the
    // time these resolve.
    final messenger = ScaffoldMessenger.of(context);
    final result = await showOmniSheet<AssignResult>(
      context: context,
      expand: true,
      builder: (_) => const AssignSheet(),
    );
    if (result == null) return;

    // Không dừng ở hội thoại lỗi đầu tiên: hội thoại Zalo/FB cá nhân trả 422
    // riêng nó (Đợt 5), những hội thoại khác vẫn gán được.
    final outcome = await bulkAssign(
      ref.read(inboxApiProvider),
      List.of(selectedIds),
      result.assigneeId,
      note: result.note,
    );
    // Lỗi thật thì giữ lựa chọn để thử lại; danh sách vẫn làm mới vì một phần
    // đã được gán.
    if (outcome.error == null) onDone();
    try {
      await ref.read(inboxListProvider.notifier).refresh();
    } on AppException {
      // Làm mới hỏng không đổi kết quả gán; câu báo bên dưới vẫn đúng.
    }
    messenger.showSnackBar(SnackBar(content: Text(outcome.message)));
  }

  Future<void> _label(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final label = await showLabelDialog(context);
    if (label == null || label.isEmpty) return;

    try {
      final updated = await ref.read(inboxApiProvider).setLabels(selectedIds, [
        label,
      ]);
      onDone();
      await ref.read(inboxListProvider.notifier).refresh();
      messenger.showSnackBar(
        SnackBar(content: Text('Đã gắn nhãn cho $updated hội thoại.')),
      );
    } on AppException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    }
  }
}

/// One bulk action. Uses the inbox accent rather than the CRM indigo the
/// default TextButton inherited, so the bar belongs to the screen it sits on.
class _BulkAction extends StatelessWidget {
  const _BulkAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label, style: OmniType.body),
      style: TextButton.styleFrom(
        foregroundColor: OmniColors.chatPrimary,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        minimumSize: const Size(0, 40),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}
