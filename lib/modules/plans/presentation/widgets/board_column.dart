import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../design/tokens/tokens.dart';
import '../../../tasks/domain/task.dart';
import '../../domain/plan.dart';
import 'board_task_card.dart';

/// Kích thước dải cột của bảng (`Board.dc.html` `.track`, `.col`).
abstract final class BoardMetrics {
  static const double columnWidth = 300;
  static const double gap = 10;

  /// Đệm trái/phải của dải.
  static const double inset = 16;

  static const double top = 12;

  /// Đệm đáy: chỗ cho nút kính lúp nổi (Task 5) không che thẻ cuối.
  static const double bottom = 120;

  static const double pitch = columnWidth + gap;
}

/// Snap từng cột, căn GIỮA cột vào giữa màn (`scroll-snap-align:center`).
///
/// Cột đầu và cột cuối không căn giữa được thì dừng ở mép dải, như trình
/// duyệt kẹp vị trí snap. Vuốt có vận tốc thì sang cột kế theo chiều vuốt;
/// thả chậm thì về cột gần nhất.
///
/// [animate] = false (giảm chuyển động): nhảy thẳng tới cột đích trong một
/// khung, không trượt.
class BoardSnapPhysics extends ScrollPhysics {
  const BoardSnapPhysics({super.parent, this.animate = true, this.count});

  final bool animate;

  /// Số ô trên dải (cột + ô "Thêm nhóm việc"). Biết thì kẹp đầu cuối theo
  /// nó; null thì suy từ tầm cuộn — mà tầm cuộn của danh sách lười chỉ là
  /// ước lượng cho tới khi ô cuối được dựng.
  final int? count;

  @override
  BoardSnapPhysics applyTo(ScrollPhysics? ancestor) => BoardSnapPhysics(
    parent: buildParent(ancestor),
    animate: animate,
    count: count,
  );

  static double offsetOf(int index, ScrollMetrics metrics) =>
      (BoardMetrics.inset +
              BoardMetrics.columnWidth / 2 +
              index * BoardMetrics.pitch -
              metrics.viewportDimension / 2)
          .clamp(metrics.minScrollExtent, metrics.maxScrollExtent);

  double _target(ScrollMetrics metrics, double velocity, double tolerance) {
    var index =
        (metrics.pixels +
            metrics.viewportDimension / 2 -
            BoardMetrics.inset -
            BoardMetrics.columnWidth / 2) /
        BoardMetrics.pitch;
    if (velocity < -tolerance) {
      index -= 0.5;
    } else if (velocity > tolerance) {
      index += 0.5;
    }
    final content =
        metrics.maxScrollExtent -
        metrics.minScrollExtent +
        metrics.viewportDimension -
        2 * BoardMetrics.inset +
        BoardMetrics.gap;
    final count =
        this.count ?? math.max(1, (content / BoardMetrics.pitch).round());

    return offsetOf(index.round().clamp(0, math.max(0, count - 1)), metrics);
  }

  /// Vị trí dừng khi thả ở [metrics] với vận tốc [velocity] (px/s).
  @visibleForTesting
  double targetFor(ScrollMetrics metrics, double velocity) =>
      _target(metrics, velocity, toleranceFor(metrics).velocity);

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    if ((velocity <= 0 && position.pixels <= position.minScrollExtent) ||
        (velocity >= 0 && position.pixels >= position.maxScrollExtent)) {
      return super.createBallisticSimulation(position, velocity);
    }
    final tolerance = toleranceFor(position);
    final target = _target(position, velocity, tolerance.velocity);
    if ((target - position.pixels).abs() < tolerance.distance) return null;
    if (!animate) return _JumpSimulation(target);

    return ScrollSpringSimulation(
      spring,
      position.pixels,
      target,
      velocity,
      tolerance: tolerance,
    );
  }

  @override
  bool get allowImplicitScrolling => false;
}

/// Tới đích ngay ở khung đầu tiên.
class _JumpSimulation extends Simulation {
  _JumpSimulation(this._target);

  final double _target;

  @override
  double x(double time) => _target;

  @override
  double dx(double time) => 0;

  @override
  bool isDone(double time) => true;
}

/// Một cột của bảng (`.col`): rãnh phẳng, đầu cột 44 (tên, viên đếm, ⋯),
/// thẻ cuộn dọc TRONG cột, đáy "Thêm công việc".
class BoardColumn extends StatelessWidget {
  const BoardColumn({
    super.key,
    required this.section,
    required this.tasks,
    required this.onOpenTask,
    required this.firstShow,
    this.canComplete = false,
    this.onAddTask,
    this.onOptions,
  });

  final PlanSection section;
  final List<Task> tasks;
  final ValueChanged<Task> onOpenTask;

  /// true nếu thẻ được "rise" (chỉ ở khung đầu của bảng, xem PlanBoardPage).
  final bool Function(String taskId) firstShow;

  /// Có ô tích trên thẻ (`taskAccess.canComplete`).
  final bool canComplete;

  /// null = không có quyền tạo việc: ẩn "Thêm công việc".
  final VoidCallback? onAddTask;

  /// null = không sửa được nhóm việc: ẩn ⋯. Khi chạm, trả vùng của nút để
  /// menu nổi neo đúng tại nơi người dùng vừa thao tác.
  final ValueChanged<Rect>? onOptions;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      container: true,
      label: section.name,
      child: DecoratedBox(
        decoration: BoxDecoration(color: scheme.surfaceContainerHighest),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(
              name: section.name,
              count: tasks.length,
              onOptions: onOptions,
            ),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: tasks.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final task = tasks[index];

                  return BoardTaskCard(
                    key: ValueKey(task.id),
                    task: task,
                    rise: firstShow(task.id),
                    canComplete: canComplete,
                    delay: Duration(milliseconds: 50 * math.min(index, 6)),
                    onTap: () => onOpenTask(task),
                  );
                },
              ),
            ),
            if (onAddTask case final add?)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
                child: _AddTaskButton(onTap: add),
              )
            else
              const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.name, required this.count, this.onOptions});

  final String name;
  final int count;
  final ValueChanged<Rect>? onOptions;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 44),
      child: Padding(
        padding: EdgeInsets.fromLTRB(12, 4, onOptions == null ? 12 : 0, 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: OmniType.bodySm.copyWith(
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Semantics(
              label: '$count việc',
              excludeSemantics: true,
              child: Container(
                key: const Key('column-count'),
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
                    height: 1,
                    color: scheme.onSurfaceVariant,
                    fontFeatures: OmniType.tabular,
                  ),
                ),
              ),
            ),
            if (onOptions != null) ...[
              const SizedBox(width: 8),
              Builder(
                builder: (buttonContext) => IconButton(
                  tooltip: 'Tuỳ chọn nhóm việc',
                  onPressed: () {
                    final box = buttonContext.findRenderObject() as RenderBox?;
                    if (box == null || !box.hasSize) return;
                    onOptions!(box.localToGlobal(Offset.zero) & box.size);
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 44,
                    height: 44,
                  ),
                  style: IconButton.styleFrom(
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(6)),
                    ),
                  ),
                  icon: Icon(
                    Icons.more_horiz_rounded,
                    size: OmniIconSize.md,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// `.add`: cao 44, bo 6, chữ w500 14 `#3D4A60`, dấu + 18.
class _AddTaskButton extends StatelessWidget {
  const _AddTaskButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = OmniTaskTones.of(context).upcoming.foreground;

    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: [
                Icon(Icons.add_rounded, size: OmniIconSize.md, color: color),
                const SizedBox(width: 6),
                Text(
                  'Thêm công việc',
                  style: OmniType.bodySm.copyWith(
                    fontWeight: FontWeight.w500,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Ô "Thêm nhóm việc" cuối dải: rộng 300, cao 52, nền trắng .18, chữ trắng.
class BoardAddSectionTile extends StatelessWidget {
  const BoardAddSectionTile({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const Key('add-section-tile'),
      width: BoardMetrics.columnWidth,
      height: 52,
      child: Material(
        color: Colors.white.withValues(alpha: .18),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.add_rounded,
                size: OmniIconSize.md,
                color: Colors.white,
              ),
              const SizedBox(width: 6),
              Text(
                'Thêm nhóm việc',
                style: OmniType.bodySm.copyWith(
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
