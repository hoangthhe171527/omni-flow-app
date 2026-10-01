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
///
/// Bố cục theo `MPinTabs.dc.html`, kèm thẻ xem trước "Thanh dưới sẽ là" để
/// người dùng thấy kết quả trước khi quay lại.
class PinTabsPage extends ConsumerWidget {
  const PinTabsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(primaryNavEntriesProvider);
    final pinned =
        ref.watch(pinnedTabsProvider).valueOrNull ?? const <String>[];
    final preview = ref.watch(tabEntriesProvider).take(maxPinnedTabs).toList();
    final full = pinned.length >= maxPinnedTabs;
    final scheme = Theme.of(context).colorScheme;
    final secondary = Theme.of(context).brightness == Brightness.dark
        ? scheme.onSurfaceVariant
        : OmniColors.secondaryForeground;

    return Scaffold(
      appBar: AppBar(title: const Text('Chọn tab')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          OmniSpacing.xl,
          OmniSpacing.sm,
          OmniSpacing.xl,
          OmniSpacing.bottomSafe,
        ),
        children: [
          Text(
            'Chọn tối đa 4 mục hiện ở thanh dưới. '
            'Bỏ trống thì app tự chọn theo quyền của bạn.',
            style: OmniType.bodyStrong.copyWith(
              fontWeight: FontWeight.w400,
              height: 22 / 15,
              color: secondary,
            ),
          ),
          const SizedBox(height: OmniSpacing.lg),

          if (entries.isEmpty)
            Text(
              'Chưa có mục nào để ghim.',
              style: OmniType.body.copyWith(color: scheme.onSurfaceVariant),
            )
          else ...[
            _PreviewCard(tabs: preview),
            const SizedBox(height: OmniSpacing.lg),
            _Card(
              children: [
                for (final entry in entries)
                  _PinTile(
                    entry: entry,
                    checked: pinned.contains(entry.routeName),
                    // Đã đủ 4 thì ô chưa chọn tắt hẳn, KÈM lý do ở dòng phụ.
                    // Một checkbox bấm không ăn mà không nói vì sao là lỗi
                    // giao diện — người dùng không đọc được ý định của ta.
                    blockedReason: full && !pinned.contains(entry.routeName)
                        ? 'Đã đủ 4 tab — bỏ chọn một mục khác trước'
                        : null,
                    onToggle: () => ref
                        .read(pinnedTabsProvider.notifier)
                        .toggle(entry.routeName),
                  ),
              ],
            ),
          ],

          if (pinned.isNotEmpty) ...[
            const SizedBox(height: OmniSpacing.lg),
            TextButton(
              onPressed: () => ref.read(pinnedTabsProvider.notifier).reset(),
              style: TextButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                textStyle: OmniType.bodyStrong.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: const Text('Đặt lại về mặc định'),
            ),
          ],
        ],
      ),
    );
  }
}

/// "Thanh dưới sẽ là": một viên cho mỗi tab sẽ hiện, và một viên viền đứt
/// cho số chỗ còn trống.
class _PreviewCard extends StatelessWidget {
  const _PreviewCard({required this.tabs});

  final List<ModuleNavEntry> tabs;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final free = maxPinnedTabs - tabs.length;

    return Semantics(
      container: true,
      label:
          'Thanh dưới sẽ là: ${tabs.map((t) => t.label).join(', ')}'
          '${free > 0 ? ', còn $free chỗ trống' : ''}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: OmniRadius.xlAll,
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Thanh dưới sẽ là',
                style: OmniType.caption.copyWith(
                  fontWeight: FontWeight.w400,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(width: OmniSpacing.sm),
            Expanded(
              child: Wrap(
                alignment: WrapAlignment.end,
                spacing: OmniSpacing.sm,
                runSpacing: OmniSpacing.sm,
                children: [
                  for (final tab in tabs)
                    _Chip(
                      label: tab.label,
                      background: scheme.primaryContainer,
                      foreground: scheme.onPrimaryContainer,
                    ),
                  if (free > 0)
                    CustomPaint(
                      painter: _DashedPillPainter(color: scheme.outline),
                      child: _Chip(
                        label: '+$free',
                        foreground: scheme.onSurfaceVariant,
                        weight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.foreground,
    this.background,
    this.weight = FontWeight.w600,
  });

  final String label;
  final Color foreground;
  final Color? background;
  final FontWeight weight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: OmniRadius.pillAll,
      ),
      child: Text(
        label,
        style: OmniType.micro.copyWith(fontWeight: weight, color: foreground),
      ),
    );
  }
}

/// Viền đứt của viên "+N" — Flutter không có sẵn viền đứt.
class _DashedPillPainter extends CustomPainter {
  _DashedPillPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          rect.deflate(0.5),
          Radius.circular(size.height / 2),
        ),
      );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (final metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 6) {
        canvas.drawPath(metric.extractPath(d, d + 3), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedPillPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _Card extends StatelessWidget {
  const _Card({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // Material chứ không DecoratedBox: dòng bên trong vẽ gợn sóng lên
    // Material gần nhất, và một nền tô giữa hai bên sẽ che mất nó.
    return Material(
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: OmniRadius.xlAll,
        side: BorderSide(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            children[i],
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
    final enabled = blockedReason == null;

    return CheckboxListTile(
      value: checked,
      onChanged: enabled ? (_) => onToggle() : null,
      controlAffinity: ListTileControlAffinity.leading,
      // 56dp: cùng sàn vùng chạm với mọi dòng danh sách khác trong app.
      minVerticalPadding: OmniSpacing.md,
      contentPadding: const EdgeInsets.symmetric(horizontal: OmniSpacing.sm),
      title: Text(
        entry.label,
        style: OmniType.bodyStrong.copyWith(
          color: enabled ? scheme.onSurface : scheme.onSurfaceVariant,
        ),
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle,
              style: OmniType.caption.copyWith(
                fontWeight: FontWeight.w400,
                color: enabled
                    ? scheme.onSurfaceVariant
                    : OmniColors.dangerTextOf(context),
              ),
            ),
    );
  }
}
