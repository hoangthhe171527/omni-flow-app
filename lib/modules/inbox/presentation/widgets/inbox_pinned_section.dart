import 'package:flutter/material.dart';

import '../../../../design/tokens/tokens.dart';
import '../../domain/conversation.dart';

/// Mục "Đã ghim" ở đầu Hộp thư: tiêu đề, tối đa [collapsedCount] dòng rồi
/// "Xem thêm N" ↔ "Thu gọn", và tiêu đề "Hội thoại" mở đầu danh sách chính.
/// Không có dòng nào thì không vẽ gì.
class InboxPinnedSection extends StatefulWidget {
  const InboxPinnedSection({
    super.key,
    required this.items,
    required this.rowBuilder,
  });

  final List<Conversation> items;
  final Widget Function(Conversation conversation) rowBuilder;

  static const collapsedCount = 5;

  @override
  State<InboxPinnedSection> createState() => _InboxPinnedSectionState();
}

class _InboxPinnedSectionState extends State<InboxPinnedSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    if (items.isEmpty) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final hidden = items.length - InboxPinnedSection.collapsedCount;
    final shown = _expanded || hidden <= 0
        ? items
        : items.take(InboxPinnedSection.collapsedCount).toList();
    const divider = Divider(height: 1, thickness: 1, color: OmniColors.divider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionHeader('Đã ghim'),
        for (final c in shown) ...[widget.rowBuilder(c), divider],
        if (hidden > 0) ...[
          InkWell(
            key: const Key('inbox-pinned-more'),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Container(
              constraints: const BoxConstraints(minHeight: 44),
              alignment: Alignment.center,
              child: Text(
                _expanded ? 'Thu gọn' : 'Xem thêm $hidden',
                style: OmniType.caption.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          divider,
        ],
        const _SectionHeader('Hội thoại'),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      header: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: 32),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: OmniType.overline.copyWith(color: scheme.onSurfaceVariant),
        ),
      ),
    );
  }
}
