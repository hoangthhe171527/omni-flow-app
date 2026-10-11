import 'package:flutter/material.dart';

import '../../../../design/platform/omni_motion_scope.dart';
import '../../../../design/tokens/tokens.dart';
import '../../../tasks/domain/task.dart';
import '../../domain/plan.dart';

/// Nút kính lúp nổi của bảng: 52×52 bo 12, nền surface, biểu tượng primary,
/// bóng `0 8 22 ink/.28`. − để thu nhỏ, + để phóng to lại.
class BoardZoomButton extends StatelessWidget {
  const BoardZoomButton({super.key, required this.zoomed, required this.onTap});

  final bool zoomed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      label: zoomed ? 'Phóng to lại' : 'Thu nhỏ xem toàn bảng',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          key: const Key('board-zoom-fab'),
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: OmniColors.ink.withValues(alpha: 0.28),
                offset: const Offset(0, 8),
                blurRadius: 22,
              ),
            ],
          ),
          child: Icon(
            zoomed ? Icons.zoom_in_rounded : Icons.zoom_out_rounded,
            size: 22,
            color: scheme.primary,
          ),
        ),
      ),
    );
  }
}

/// Bảng thu nhỏ (`.zc`, `.zt`): mọi cột thành ô 150 xếp `Wrap`, mỗi việc là
/// một dòng. Chạm một ô thì về bảng ở đúng cột đó ([onOpenColumn]).
///
/// Hiện dần 300ms (`fade`); giảm chuyển động thì hiện ngay.
class BoardZoomGrid extends StatefulWidget {
  const BoardZoomGrid({
    super.key,
    required this.columns,
    required this.buckets,
    required this.onOpenColumn,
  });

  final List<PlanSection> columns;
  final List<List<Task>> buckets;
  final ValueChanged<int> onOpenColumn;

  @override
  State<BoardZoomGrid> createState() => _BoardZoomGridState();
}

class _BoardZoomGridState extends State<BoardZoomGrid>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (OmniMotion.enabled(context)) {
      _fade.forward();
    } else {
      _fade.value = 1;
    }
  }

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      key: const Key('board-zoom-fade'),
      opacity: _fade,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 120),
        child: SizedBox(
          width: double.infinity,
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.start,
            children: [
              for (var i = 0; i < widget.columns.length; i++)
                _ZoomTile(
                  key: ValueKey('zoom-tile-${widget.columns[i].id}'),
                  name: widget.columns[i].name,
                  tasks: i < widget.buckets.length
                      ? widget.buckets[i]
                      : const [],
                  onTap: () => widget.onOpenColumn(i),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ZoomTile extends StatelessWidget {
  const _ZoomTile({
    super.key,
    required this.name,
    required this.tasks,
    required this.onTap,
  });

  final String name;
  final List<Task> tasks;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      label: 'Mở nhóm $name',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: 150,
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: OmniType.caption.copyWith(
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  _Count(count: tasks.length),
                ],
              ),
              for (final task in tasks) ...[
                const SizedBox(height: 5),
                Opacity(
                  opacity: task.isDone ? 0.78 : 1,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      task.title,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                      style: OmniType.micro.copyWith(
                        fontWeight: FontWeight.w400,
                        height: 1.3,
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// `.cnt` trên nền surface.
class _Count extends StatelessWidget {
  const _Count({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      constraints: const BoxConstraints(minWidth: 20),
      height: 20,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$count',
        style: OmniType.micro.copyWith(
          fontWeight: FontWeight.w600,
          color: scheme.onSurfaceVariant,
          fontFeatures: OmniType.tabular,
        ),
      ),
    );
  }
}
