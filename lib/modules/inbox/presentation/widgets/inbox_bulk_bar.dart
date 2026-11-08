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
    final allSelected = selectedIds.length == allIds.length;
    // Nút kính viên thuốc nhỏ (theme OutlinedButton là kính).
    final pill = OutlinedButton.styleFrom(
      minimumSize: const Size(0, 40),
      padding: const EdgeInsets.symmetric(horizontal: 14),
    );

    // Thanh thành viên kính nổi cách mép, bo 28 — không nền đặc / vạch viền.
    return Padding(
      padding: EdgeInsets.fromLTRB(
        12,
        8,
        12,
        10 + MediaQuery.paddingOf(context).bottom,
      ),
      child: OmniGlass(
        radius: 28,
        padding: const EdgeInsets.fromLTRB(
          OmniSpacing.md,
          OmniSpacing.sm,
          OmniSpacing.md,
          OmniSpacing.sm,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Được phép xuống dòng: Row cố định làm tràn trên Android hẹp.
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 6,
              children: [
                Text(
                  'Đã chọn ${selectedIds.length}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: OmniType.body.copyWith(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                OutlinedButton(
                  onPressed: allIds.isEmpty
                      ? null
                      : () => onSelectAll(allSelected ? const [] : allIds),
                  style: pill,
                  child: Text(allSelected ? 'Bỏ tất cả' : 'Chọn tất cả'),
                ),
                OutlinedButton(
                  onPressed: onDone,
                  style: pill,
                  child: const Text('Bỏ chọn'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _BulkAction(
                  icon: Icons.person_add_alt_rounded,
                  label: 'Gán',
                  onTap: () => _assign(context, ref),
                ),
                const SizedBox(width: 24),
                _BulkAction(
                  icon: Icons.sell_outlined,
                  label: 'Gắn nhãn',
                  onTap: () => _label(context, ref),
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

/// Một thao tác hàng loạt: nút kính tròn có nhãn nhỏ phía dưới.
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
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 64),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              OmniGlassCircle(
                child: Icon(icon, size: 20, color: scheme.onSurface),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                style: OmniType.micro.copyWith(
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 2),
            ],
          ),
        ),
      ),
    );
  }
}
