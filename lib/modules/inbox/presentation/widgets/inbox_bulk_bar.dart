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
        // A hairline, and no shadow. OmniShadows.sheet threw a dark halo that
        // does nothing on a dark canvas except muddy the edge, and the bar is
        // already separated by the rule and by sitting against the list.
        border: Border(
          top: BorderSide(color: scheme.outline.withValues(alpha: 0.5)),
        ),
      ),
      child: Row(
        children: [
          Text(
            'Đã chọn ${selectedIds.length}',
            style: OmniType.caption.copyWith(
              fontSize: 14,
              color: scheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: OmniSpacing.md),
          // Leaving the selection was only possible from the app bar, which is
          // the far end of the screen from the thumb that is selecting.
          GestureDetector(
            onTap: onDone,
            child: Text(
              'Bỏ chọn',
              style: OmniType.caption.copyWith(
                fontSize: 13,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          const Spacer(),
          _BulkAction(
            icon: Icons.person_add_alt_rounded,
            label: 'Gán',
            onTap: () => _assign(context, ref),
          ),
          const SizedBox(width: OmniSpacing.xs),
          _BulkAction(
            icon: Icons.sell_outlined,
            label: 'Gắn nhãn',
            onTap: () => _label(context, ref),
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
      label: Text(label, style: OmniType.caption.copyWith(fontSize: 13.5)),
      style: TextButton.styleFrom(
        foregroundColor: OmniColors.chatPrimary,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        minimumSize: const Size(0, 40),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}
