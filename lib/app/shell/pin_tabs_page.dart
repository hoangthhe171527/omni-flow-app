import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/module/module_registry.dart';
import '../../core/module/nav_destination.dart';
import '../../core/nav/pinned_tabs.dart';
import '../../design/tokens/tokens.dart';

/// Chọn tối đa 4 mục hiện trên thanh dưới.
///
/// Checkbox chứ không kéo-thả. Luật accessibility bắt mọi thao tác kéo phải có
/// cách thay thế không cần kéo, và chọn bằng checkbox là ĐÃ đáp ứng sẵn — lại
/// ít code hơn. Thứ tự vẫn do hệ thống xếp: người dùng chọn *cái nào*, không
/// phải *xếp ra sao*.
///
/// Phần lớn người dùng sẽ không bao giờ mở màn này, và đó là chủ ý: mặc định
/// suy ra từ quyền phải đúng sẵn. Màn này là lối thoát cho số ít người có công
/// việc không khớp bộ quyền của họ.
class PinTabsPage extends ConsumerWidget {
  const PinTabsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(primaryNavEntriesProvider);
    final pinned =
        ref.watch(pinnedTabsProvider).valueOrNull ?? const <String>[];
    final full = pinned.length >= maxPinnedTabs;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Chọn tab')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: OmniSpacing.bottomSafe),
        children: [
          Padding(
            padding: const EdgeInsets.all(OmniSpacing.lg),
            child: Text(
              'Chọn tối đa 4 mục hiện ở thanh dưới. '
              'Bỏ trống thì app tự chọn theo quyền của bạn.',
              style: OmniType.body.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),

          if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: OmniSpacing.lg),
              child: Text(
                'Chưa có mục nào để ghim.',
                style: OmniType.body.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),

          for (final entry in entries)
            _PinTile(
              entry: entry,
              checked: pinned.contains(entry.routeName),
              // Đã đủ 4 thì ô chưa chọn tắt hẳn, KÈM lý do ở dòng phụ. Một
              // checkbox bấm không ăn mà không nói vì sao là lỗi giao diện —
              // người dùng không đọc được ý định của ta.
              blockedReason: full && !pinned.contains(entry.routeName)
                  ? 'Đã đủ 4 tab — bỏ chọn một mục khác trước'
                  : null,
              onToggle: () =>
                  ref.read(pinnedTabsProvider.notifier).toggle(entry.routeName),
            ),

          if (pinned.isNotEmpty) ...[
            const Divider(height: 1),
            ListTile(
              minVerticalPadding: OmniSpacing.md,
              title: Text(
                'Đặt lại về mặc định',
                style: OmniType.body.copyWith(color: scheme.primary),
              ),
              onTap: () => ref.read(pinnedTabsProvider.notifier).reset(),
            ),
          ],
        ],
      ),
    );
  }
}

class _PinTile extends StatelessWidget {
  const _PinTile({
    required this.entry,
    required this.checked,
    required this.blockedReason,
    required this.onToggle,
  });

  final ModuleNavEntry entry;
  final bool checked;
  final String? blockedReason;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final subtitle = blockedReason ?? entry.subtitle;

    return CheckboxListTile(
      value: checked,
      onChanged: blockedReason == null ? (_) => onToggle() : null,
      controlAffinity: ListTileControlAffinity.leading,
      // 56dp: cùng sàn vùng chạm với mọi dòng danh sách khác trong app.
      minVerticalPadding: OmniSpacing.md,
      secondary: Icon(
        checked ? entry.selectedIcon : entry.icon,
        size: OmniIconSize.xl,
        color: blockedReason == null ? scheme.onSurface : scheme.outline,
      ),
      title: Text(entry.label, style: OmniType.body),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle,
              style: OmniType.caption.copyWith(
                color: blockedReason == null
                    ? scheme.onSurfaceVariant
                    : scheme.error,
              ),
            ),
    );
  }
}
