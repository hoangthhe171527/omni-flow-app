import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../design/components/components.dart';
import '../../../../design/tokens/tokens.dart';
import '../../application/inbox_providers.dart';
import '../../data/inbox_api.dart';
import 'assign_sheet.dart';

/// Bulk actions on selected conversations: assign in one go, or apply a label.
/// Triage on mobile is done in batches — one thread at a time is how a 200-row
/// inbox stays a 200-row inbox.
class InboxBulkBar extends ConsumerWidget {
  const InboxBulkBar({
    super.key,
    required this.selectedIds,
    required this.onDone,
  });

  final List<String> selectedIds;
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
        border: Border(top: BorderSide(color: scheme.outline)),
        boxShadow: OmniShadows.sheet,
      ),
      child: Row(
        children: [
          Text(
            'Đã chọn ${selectedIds.length}',
            style: OmniType.caption.copyWith(
              color: scheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: () => _assign(context, ref),
            icon: const Icon(Icons.person_add_alt_rounded, size: 18),
            label: const Text('Gán'),
          ),
          const SizedBox(width: OmniSpacing.sm),
          TextButton.icon(
            onPressed: () => _label(context, ref),
            icon: const Icon(Icons.sell_outlined, size: 18),
            label: const Text('Gắn nhãn'),
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

    final api = ref.read(inboxApiProvider);
    try {
      for (final id in selectedIds) {
        await api.assign(id, result.assigneeId, note: result.note);
      }
      onDone();
      await ref.read(inboxListProvider.notifier).refresh();
      messenger.showSnackBar(
        SnackBar(content: Text('Đã gán ${selectedIds.length} hội thoại.')),
      );
    } on AppException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _label(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final controller = TextEditingController();
    final label = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Gắn nhãn'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'VD: gia đình, VIP'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Huỷ'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Áp dụng'),
          ),
        ],
      ),
    );
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
