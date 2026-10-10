import 'package:flutter/material.dart';

import '../platform/omni_motion_scope.dart';
import '../tokens/omni_motion.dart';
import '../tokens/omni_typography.dart';
import 'omni_card.dart';

/// Thẻ có tiêu đề bấm để thu / mở (màn Tổng quan).
///
/// Tiêu đề là một nút cao 44 với `Semantics(button, expanded)`; mũi tên ⌄ xoay
/// 180° khi mở, thân co giãn bằng [AnimatedSize]. Tắt chuyển động → cả hai
/// đổi ngay trong một khung.
class OmniCollapsibleCard extends StatefulWidget {
  const OmniCollapsibleCard({
    super.key,
    required this.title,
    this.count,
    required this.child,
    this.initiallyExpanded = true,
    this.footer,
    this.storageKey,
  });

  final String title;

  /// Số đếm cạnh tiêu đề; `null` thì không hiện.
  final int? count;

  final Widget child;
  final bool initiallyExpanded;

  /// Dòng cuối thẻ ("Xem tất cả"), ẩn cùng thân khi thu.
  final Widget? footer;

  /// Khoá [PageStorage] để nhớ thu/mở khi thẻ bị dựng lại (đổi tab, cuộn
  /// khỏi màn); `null` thì không nhớ.
  final String? storageKey;

  @override
  State<OmniCollapsibleCard> createState() => _OmniCollapsibleCardState();
}

class _OmniCollapsibleCardState extends State<OmniCollapsibleCard> {
  late bool _expanded = _restore();

  bool _restore() {
    final key = widget.storageKey;
    if (key == null) return widget.initiallyExpanded;
    final saved = PageStorage.maybeOf(
      context,
    )?.readState(context, identifier: _id(key));
    return saved is bool ? saved : widget.initiallyExpanded;
  }

  static String _id(String key) => 'omni-collapsible:$key';

  void _toggle() {
    setState(() => _expanded = !_expanded);
    final key = widget.storageKey;
    if (key != null) {
      PageStorage.maybeOf(
        context,
      )?.writeState(context, _expanded, identifier: _id(key));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final motion = OmniMotion.enabled(context);
    final duration = motion ? OmniDuration.base : Duration.zero;
    final count = widget.count;
    final Widget body = _expanded
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [widget.child, ?widget.footer],
          )
        : const SizedBox(width: double.infinity);

    return OmniCard(
      padding: EdgeInsets.zero,
      background: scheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: true,
            expanded: _expanded,
            child: InkWell(
              onTap: _toggle,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          widget.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: OmniType.section.copyWith(
                            color: scheme.onSurface,
                          ),
                        ),
                      ),
                      if (count != null) ...[
                        const SizedBox(width: 6),
                        Text(
                          '$count',
                          style: OmniType.micro.copyWith(
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const Spacer(),
                      AnimatedRotation(
                        turns: _expanded ? .5 : 0,
                        duration: duration,
                        child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 22,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Tắt chuyển động → không dựng AnimatedSize (với Duration.zero nó
          // tự đánh dấu lại layout giữa lúc layout và ném assert).
          if (motion)
            ClipRect(
              child: AnimatedSize(
                duration: duration,
                alignment: Alignment.topCenter,
                child: body,
              ),
            )
          else
            body,
        ],
      ),
    );
  }
}
