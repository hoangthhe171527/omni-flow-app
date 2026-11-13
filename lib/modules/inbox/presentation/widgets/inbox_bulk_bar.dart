import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/nav/shell_bar_inset.dart';
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
    final allSelected = selectedIds.length == allIds.length;
    final pill = OutlinedButton.styleFrom(
      minimumSize: const Size(0, 44),
      shape: const StadiumBorder(),
      padding: const EdgeInsets.symmetric(horizontal: 14),
    );

    // Khay kính bo 24 nổi phía trên thanh tab kính (ShellBarInset) — nút thao
    // tác là viên thuốc 999px một tông.
    return Padding(
      padding: EdgeInsets.fromLTRB(
        12,
        8,
        12,
        ShellBarInset.floatingBottom(context, gap: 10),
      ),
      child: OmniGlass(
        radius: 24,
        padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
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
                      fontFeatures: OmniType.tabular,
                    ),
                  ),
                ),
                OutlinedButton(
                  onPressed: allIds.isEmpty
                      ? null
                      : () => onSelectAll(allSelected ? const [] : allIds),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  child: Text(allSelected ? 'Bỏ tất cả' : 'Chọn tất cả'),
                ),
                const SizedBox(width: 6),
                OmniGlassCircle(
                  child: IconButton(
                    tooltip: 'Bỏ chọn',
                    onPressed: onDone,
                    icon: const Icon(Icons.close_rounded),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _assign(context, ref),
                    style: pill,
                    icon: Icon(
                      Icons.person_add_alt_rounded,
                      size: OmniIconSize.md,
                      color: scheme.onSurface,
                    ),
                    label: const Text('Gán'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _label(context, ref),
                    style: pill,
                    icon: Icon(
                      Icons.sell_outlined,
                      size: OmniIconSize.md,
                      color: scheme.onSurface,
                    ),
                    label: const Text('Gắn nhãn'),
                  ),
                ),
              ],
            ),
          ],
        ),
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
