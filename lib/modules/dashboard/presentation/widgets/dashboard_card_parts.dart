/// Mảnh dùng chung của các thẻ danh sách trên Tổng quan.
library;

import 'package:flutter/material.dart';
import 'package:omni_app/core/error/app_exception.dart';
import 'package:omni_app/design/components/components.dart';
import 'package:omni_app/design/tokens/omni_colors.dart';
import 'package:omni_app/design/platform/omni_motion_scope.dart';
import 'package:omni_app/design/tokens/omni_motion.dart';
import 'package:omni_app/design/tokens/omni_typography.dart';

/// Một khối của Tổng quan theo kiểu nhóm lồng liquid: nhãn xám + số đếm
/// NGOÀI thẻ (bấm để thu / mở), thẻ trắng bo 18 bên dưới, "Xem tất cả" là
/// dòng cuối nhóm. Nhớ thu/mở bằng [PageStorage] khi khối bị dựng lại.
class DashboardGroup extends StatefulWidget {
  const DashboardGroup({
    super.key,
    required this.title,
    required this.storageKey,
    this.count,
    this.rows = const [],
    this.placeholder,
    this.onSeeAll,
    this.dividerIndent = 14,
  });

  final String title;
  final String storageKey;
  final int? count;

  /// Các dòng của nhóm (khi có dữ liệu).
  final List<Widget> rows;

  /// Thay cho [rows] khi đang tải / lỗi / trống — vẫn nằm trong thẻ trắng.
  final Widget? placeholder;

  /// Có thì thêm dòng cuối "Xem tất cả ›".
  final VoidCallback? onSeeAll;
  final double dividerIndent;

  @override
  State<DashboardGroup> createState() => _DashboardGroupState();
}

class _DashboardGroupState extends State<DashboardGroup> {
  late bool _expanded = _restore();

  String get _id => 'omni-collapsible:${widget.storageKey}';

  bool _restore() {
    final saved = PageStorage.maybeOf(
      context,
    )?.readState(context, identifier: _id);
    return saved is bool ? saved : true;
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    PageStorage.maybeOf(
      context,
    )?.writeState(context, _expanded, identifier: _id);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final motion = OmniMotion.enabled(context);
    final count = widget.count;

    final Widget card = widget.placeholder != null
        ? Material(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(18),
            clipBehavior: Clip.antiAlias,
            child: widget.placeholder,
          )
        : OmniGroupSection(
            dividerIndent: widget.dividerIndent,
            children: [
              ...widget.rows,
              if (widget.onSeeAll != null)
                OmniGroupRow(
                  title: 'Xem tất cả',
                  chevron: true,
                  onTap: widget.onSeeAll,
                ),
            ],
          );
    final Widget body = _expanded
        ? card
        : const SizedBox(width: double.infinity);

    return Padding(
      padding: const EdgeInsets.only(bottom: OmniGroupSection.gap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: true,
            expanded: _expanded,
            child: InkWell(
              onTap: _toggle,
              borderRadius: BorderRadius.circular(8),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          widget.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: OmniType.caption.copyWith(
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurfaceVariant,
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
                        duration: motion ? OmniDuration.base : Duration.zero,
                        child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 20,
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
                duration: OmniDuration.base,
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

/// Dòng chữ nhạt khi thẻ không có gì.
class DashboardEmptyLine extends StatelessWidget {
  const DashboardEmptyLine(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(14),
    child: Text(
      text,
      style: OmniType.caption.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );
}

/// Khung xương ba dòng lúc thẻ đang tải.
class DashboardCardSkeleton extends StatelessWidget {
  const DashboardCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.all(12),
    child: Column(
      children: [
        OmniSkeletonBox(height: 36),
        SizedBox(height: 8),
        OmniSkeletonBox(height: 36),
        SizedBox(height: 8),
        OmniSkeletonBox(height: 36),
      ],
    ),
  );
}

/// Lỗi gọn trong thẻ: một dòng + "Thử lại", không ảnh hưởng thẻ khác.
class DashboardCardError extends StatelessWidget {
  const DashboardCardError({
    super.key,
    required this.error,
    required this.onRetry,
  });

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final color = OmniColors.dangerTextOf(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 6, 4),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, size: 18, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              humanError(error),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: OmniType.caption.copyWith(color: color),
            ),
          ),
          TextButton(
            style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
            onPressed: onRetry,
            child: const Text('Thử lại'),
          ),
        ],
      ),
    );
  }
}
