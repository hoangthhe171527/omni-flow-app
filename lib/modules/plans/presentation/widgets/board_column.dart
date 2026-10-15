import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../design/components/omni_dashed_box.dart';
import '../../../../design/platform/omni_motion_scope.dart';
import '../../../../design/tokens/tokens.dart';
import '../../../tasks/domain/task.dart';
import '../../domain/board_drop.dart';
import '../../domain/plan.dart';
import 'board_drag.dart';
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
///
/// Có [drag] thì giữ thẻ ~400ms để nhấc lên và thả trong cùng cột hoặc sang
/// cột khác; cả cột là một `DragTarget`, ô chỗ trống chèn tại chỉ số tính từ
/// tâm các thẻ.
class BoardColumn extends StatefulWidget {
  const BoardColumn({
    super.key,
    required this.section,
    required this.tasks,
    required this.onOpenTask,
    required this.firstShow,
    this.canComplete = false,
    this.onAddTask,
    this.onOptions,
    this.columnIndex = 0,
    this.drag,
    this.canDrag = _never,
    this.onDragUpdate,
    this.onDragEnd,
  });

  static bool _never(Task _) => false;

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

  /// Vị trí của cột trên bảng, để [drag] biết đích là cột nào.
  final int columnIndex;

  /// null = tắt kéo thả (không quyền, thu nhỏ, cột dựng tạm).
  final BoardDragController? drag;

  /// Thẻ này nhấc được không (đã khoá thì không).
  final bool Function(Task task) canDrag;

  /// Con trỏ toàn cục khi đang kéo — trang dùng để bật tự trượt ở mép.
  final ValueChanged<Offset>? onDragUpdate;

  /// Kết thúc kéo (thả hay huỷ).
  final VoidCallback? onDragEnd;

  @override
  State<BoardColumn> createState() => _BoardColumnState();
}

class _BoardColumnState extends State<BoardColumn> {
  /// Chiều cao ô chỗ trống, và bước nó đẩy các thẻ phía sau (cộng khe 8).
  static const double _slot = 64;
  static const double _slotStep = _slot + 8;

  final _keys = <String, GlobalKey>{};

  /// Chỉ số ô chỗ trống ở lần dựng gần nhất (null = không có).
  int? _builtSlot;

  @override
  void initState() {
    super.initState();
    widget.drag?.attach(widget.columnIndex, _probe);
  }

  @override
  void didUpdateWidget(BoardColumn old) {
    super.didUpdateWidget(old);
    final ids = {for (final t in widget.tasks) t.id};
    _keys.removeWhere((id, _) => !ids.contains(id));
    if (old.drag != widget.drag || old.columnIndex != widget.columnIndex) {
      old.drag?.detach(old.columnIndex, _probe);
      widget.drag?.attach(widget.columnIndex, _probe);
    }
  }

  @override
  void dispose() {
    widget.drag?.detach(widget.columnIndex, _probe);
    super.dispose();
  }

  /// Chỗ chèn tại con trỏ toàn cục [pointer], hoặc null nếu nó nằm ngoài cột.
  int? _probe(Offset pointer, Task dragged) {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return null;
    if (!(Offset.zero & box.size).contains(box.globalToLocal(pointer))) {
      return null;
    }

    return _indexAt(pointer.dy, dragged);
  }

  GlobalKey _keyOf(String id) => _keys.putIfAbsent(id, GlobalKey.new);

  /// Chỗ chèn theo con trỏ Y toàn cục: số thẻ có tâm nằm trên nó. Bỏ thẻ đang
  /// kéo; thẻ chưa dựng (cuộn ra xa) coi như nằm trên hay dưới tuỳ vị trí.
  int _indexAt(double pointerY, Task dragged) {
    // Ô chỗ trống ĐÃ DỰNG (khung trước), không phải ô sẽ dựng: hover vừa đổi
    // đích trong cùng sự kiện thì các thẻ chưa bị đẩy xuống.
    final slotAt = _builtSlot;
    final centers = <double>[];
    var seenBuilt = false;
    for (final task in widget.tasks) {
      if (task.id == dragged.id) continue;
      final box = _keys[task.id]?.currentContext?.findRenderObject();
      if (box is RenderBox && box.attached && box.hasSize) {
        seenBuilt = true;
        var y = box.localToGlobal(box.size.center(Offset.zero)).dy;
        // Ô chỗ trống đẩy các thẻ phía sau xuống; trừ đi, kẻo con trỏ đứng yên
        // mà chỗ chèn nhảy qua lại.
        if (slotAt != null && centers.length >= slotAt) y -= _slotStep;
        centers.add(y);
      } else {
        centers.add(seenBuilt ? double.infinity : double.negativeInfinity);
      }
    }

    return dropIndexFor(centers, pointerY);
  }

  /// Con trỏ Y toàn cục. [DragTargetDetails.offset] là góc trên-trái của bản
  /// nổi; con trỏ nằm [BoardDragFeedback.grab] bên trong nó.
  double _pointerY(DragTargetDetails<Task> details) =>
      details.offset.dy + BoardDragFeedback.grab.dy;

  void _hover(DragTargetDetails<Task> details) => widget.drag?.hover(
    widget.columnIndex,
    _indexAt(_pointerY(details), details.data),
    widget.section.name,
  );

  Widget _card(Task task, int index) {
    final card = BoardTaskCard(
      key: ValueKey(task.id),
      task: task,
      rise: widget.firstShow(task.id),
      canComplete: widget.canComplete,
      delay: Duration(milliseconds: 50 * math.min(index, 6)),
      onTap: () => widget.onOpenTask(task),
    );
    final drag = widget.drag;
    // Thẻ không nhấc được (khoá) vẫn phải có khoá: `_indexAt` đo tâm mọi thẻ,
    // thiếu khoá thì nó bị coi như ở vô cực và chỗ chèn lệch.
    if (drag == null) return card;
    if (!widget.canDrag(task)) {
      return KeyedSubtree(key: _keyOf(task.id), child: card);
    }

    return LongPressDraggable<Task>(
      key: _keyOf(task.id),
      data: task,
      delay: const Duration(milliseconds: 400),
      // Không dùng `feedbackOffset`: nó dời cả điểm dò cột đích đi theo bản
      // nổi (hit-test ở `con trỏ + feedbackOffset`). Neo kiểu này dời riêng
      // bản nổi, còn cột đích vẫn dò ngay dưới ngón tay.
      dragAnchorStrategy: boardDragAnchor,
      hapticFeedbackOnStart: false,
      onDragStarted: () {
        HapticFeedback.selectionClick();
        drag.start(task, widget.columnIndex);
      },
      onDragUpdate: (details) {
        drag.pointer = details.globalPosition;
        widget.onDragUpdate?.call(details.globalPosition);
      },
      onDragEnd: (_) => widget.onDragEnd?.call(),
      feedback: BoardDragFeedback(task: task, controller: drag),
      childWhenDragging: Opacity(
        opacity: .3,
        child: IgnorePointer(
          child: BoardTaskCard(
            task: task,
            rise: false,
            canComplete: widget.canComplete,
            onTap: () {},
          ),
        ),
      ),
      child: card,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final drag = widget.drag;

    final body = ListenableBuilder(
      listenable: drag ?? const _NoListenable(),
      builder: (context, _) {
        final hot = drag?.targetColumn == widget.columnIndex;
        final tasks = widget.tasks;
        final sameColumn =
            drag != null && hot && drag.fromColumn == widget.columnIndex;
        final draggedId = sameColumn ? drag.task?.id : null;
        // Trong cột nguồn, bỏ thẻ đang kéo khỏi danh sách rồi đặt đúng một ô
        // chờ ở vị trí mới. Giữ cả `childWhenDragging` lẫn ô chờ sẽ tạo hai
        // khoảng trống và làm chỉ số thả lệch một hàng.
        final visibleTasks = draggedId != null
            ? [
                for (final task in tasks)
                  if (task.id != draggedId) task,
              ]
            : tasks;
        final slotAt = hot
            ? math.min(
                drag!.targetIndex ?? visibleTasks.length,
                visibleTasks.length,
              )
            : null;
        _builtSlot = slotAt;
        final duration = OmniMotion.enabled(context)
            ? const Duration(milliseconds: 200)
            : Duration.zero;

        return AnimatedContainer(
          duration: duration,
          decoration: BoxDecoration(
            color: hot
                ? OmniTaskTones.of(context).today.background
                : scheme.surfaceContainerHighest,
          ),
          child: Stack(
            fit: StackFit.passthrough,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Header(
                    name: widget.section.name,
                    count: tasks.length,
                    onOptions: widget.onOptions,
                  ),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      itemCount: visibleTasks.length + (slotAt == null ? 0 : 1),
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        if (index == slotAt) {
                          return const OmniDashedBox(
                            key: Key('drop-placeholder'),
                            height: _slot,
                          );
                        }
                        final at = slotAt != null && index > slotAt
                            ? index - 1
                            : index;

                        return _card(visibleTasks[at], at);
                      },
                    ),
                  ),
                  if (widget.onAddTask case final add?)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
                      child: _AddTaskButton(onTap: add),
                    )
                  else
                    const SizedBox(height: 8),
                ],
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedContainer(
                    key: const Key('column-drop-border'),
                    duration: duration,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: hot ? scheme.primary : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );

    return Semantics(
      container: true,
      label: widget.section.name,
      child: drag == null
          ? body
          : DragTarget<Task>(
              // Flutter chỉ gọi onMove khi con trỏ đã ở trong cột từ sự kiện
              // trước; sự kiện VÀO cột chỉ gọi ở đây, nên hover cũng phải
              // báo ở đây, kẻo cột đích chậm một nhịp.
              onWillAcceptWithDetails: (details) {
                _hover(details);

                return true;
              },
              onMove: _hover,
              onLeave: (_) => drag.leave(widget.columnIndex),
              // Không thả ở đây: sau khi dải tự trượt, `DragTarget` nhận thả
              // là cột CŨ (Flutter không dò lại khi ngón tay đứng yên). Trang
              // thả theo đích của [drag] lúc nhấc tay.
              builder: (context, _, _) => body,
            ),
    );
  }
}

/// `ListenableBuilder` cần một [Listenable]; cột không kéo được thì không nghe gì.
class _NoListenable implements Listenable {
  const _NoListenable();

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}
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
