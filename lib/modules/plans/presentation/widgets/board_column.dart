import 'dart:math' as math;

import 'package:flutter/foundation.dart';
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
    this.liftable,
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

  /// false = tạm chưa cho nhấc thẻ (một lượt thả còn chờ server). null = luôn
  /// cho. Nghe riêng ở lớp `LongPressDraggable` của từng thẻ, nên bật/tắt
  /// không dựng lại thẻ.
  final ValueListenable<bool>? liftable;

  @override
  State<BoardColumn> createState() => _BoardColumnState();
}

class _BoardColumnState extends State<BoardColumn> {
  final _keys = <String, GlobalKey>{};

  /// Khoá của khe chèn thứ i (trước thẻ i; khe [BoardColumn.tasks].length là
  /// khe cuối cột), để [_indexAt] đọc chiều cao HIỆN TẠI của từng khe.
  final _gapKeys = <int, GlobalKey>{};

  /// Thẻ đã dựng, theo id: dùng lại nguyên widget khi việc không đổi
  /// (`identical`) và quyền kéo của nó không đổi, nên lượt kéo không dựng lại
  /// thẻ nào. Giữ cả `rise`: danh sách lười tạo lại phần tử của thẻ khi cuộn
  /// về, và widget cache còn `rise: true` từ khung đầu thì `OmniRise` mới phát
  /// lại hiệu ứng — nên `rise` đổi là dựng lại thẻ, trừ khi phần tử của thẻ
  /// vẫn đang trong cây (`OmniRise` chỉ đọc `animate` lúc vào cây, nên dùng
  /// lại là vô hại, và lượt dựng lại cột giữa lượt kéo không dựng lại thẻ).
  final _cards =
      <String, ({Task task, bool canDrag, bool rise, Widget widget})>{};

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
    _gapKeys.removeWhere((i, _) => i > widget.tasks.length);
    // Thẻ cache giữ `drag.column(columnIndex)` (bóng mờ ở cột nguồn) và
    // [BoardColumn.liftable]: đổi một trong chúng là dựng lại thẻ.
    if (old.canComplete != widget.canComplete ||
        old.drag != widget.drag ||
        old.columnIndex != widget.columnIndex ||
        old.liftable != widget.liftable) {
      _cards.clear();
    } else {
      _cards.removeWhere((id, _) => !ids.contains(id));
    }
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

  GlobalKey _gapKeyOf(int index) => _gapKeys.putIfAbsent(index, GlobalKey.new);

  /// Chiều cao hiện tại của khe [index] (0 nếu chưa dựng).
  double _gapHeight(int index) {
    final box = _gapKeys[index]?.currentContext?.findRenderObject();

    return box is RenderBox && box.attached && box.hasSize
        ? box.size.height
        : 0;
  }

  /// Chỉ số (trong [BoardColumn.tasks]) của thẻ đang được nhấc TỪ cột này;
  /// −1 nếu lượt kéo không bắt đầu ở đây.
  int _lifted() {
    final drag = widget.drag;
    final id = drag?.task?.id;
    if (drag == null || id == null || drag.fromColumn != widget.columnIndex) {
      return -1;
    }

    return widget.tasks.indexWhere((t) => t.id == id);
  }

  /// Thẻ nhấc từ cột này đang được rê trong chính nó: bóng mờ của nó gập lại
  /// (cùng khoảng 8 phía trên), chỉ còn đúng một ô chỗ trống. −1 nếu không.
  int _collapsed(BoardColumnDrop drop) => drop.hot ? _lifted() : -1;

  /// Khe mở cho chỗ chèn [BoardColumnDrop.slot]. Chỗ chèn đếm trên cột ĐÃ bỏ
  /// thẻ đang kéo; ở cột nguồn, từ vị trí của thẻ ấy trở đi lệch một khe.
  int? _gapFor(BoardColumnDrop drop) {
    final slot = drop.slot;
    if (slot == null) return null;
    final f = _collapsed(drop);

    return f >= 0 && slot >= f ? slot + 1 : slot;
  }

  /// Khoảng trên thẻ thứ [i]: 8 nếu phía trên còn thẻ thấy được.
  double _spaceAbove(int i, BoardColumnDrop drop) {
    if (i == 0) return 0;
    final f = _collapsed(drop);
    if (f == i || (f == 0 && i == 1)) return 0;

    return 8;
  }

  /// Khe cuối cần khoảng 8 phía trên khi trong cột còn thẻ thấy được.
  bool _hasVisibleCards(BoardColumnDrop drop) {
    final n = widget.tasks.length;
    if (n == 0) return false;

    return !(n == 1 && _collapsed(drop) == 0);
  }

  /// Chỗ chèn theo con trỏ Y toàn cục: số thẻ có tâm "lúc nghỉ" nằm trên nó,
  /// có vùng đệm (xem [dropIndexWithHysteresis]). Bỏ thẻ đang kéo; thẻ chưa
  /// dựng (cuộn ra xa) coi như nằm trên hay dưới tuỳ vị trí.
  int _indexAt(double pointerY, Task dragged) {
    final centers = <double>[];
    final others = <Task>[];
    var seenBuilt = false;
    // Tâm lúc nghỉ = tâm đo − tổng chiều cao hiện tại của các khe phía trên
    // (gồm khe ngay trên thẻ). Khe đang trượt dở cũng trừ đúng phần đã mở, nên
    // con trỏ đứng yên thì chỗ chèn không nhảy qua lại.
    var gapAbove = 0.0;
    final tasks = widget.tasks;
    final hot = widget.drag?.column(widget.columnIndex).value.hot ?? false;
    for (var i = 0; i < tasks.length; i++) {
      final task = tasks[i];
      gapAbove += _gapHeight(i);
      if (task.id == dragged.id) {
        // Cột nguồn: lúc nghỉ (cột là đích) bóng mờ đã gập cả khoảng 8 phía
        // trên. Trừ phần nó còn chiếm — kể cả khi đang gập dở.
        final ghost = _keys[task.id]?.currentContext?.findRenderObject();
        if (ghost is RenderBox && ghost.attached && ghost.hasSize) {
          gapAbove += ghost.size.height;
        }
        if (!hot && tasks.length > 1) gapAbove += 8;
        continue;
      }
      others.add(task);
      final box = _keys[task.id]?.currentContext?.findRenderObject();
      if (box is RenderBox && box.attached && box.hasSize) {
        seenBuilt = true;
        centers.add(
          box.localToGlobal(box.size.center(Offset.zero)).dy - gapAbove,
        );
      } else {
        centers.add(seenBuilt ? double.infinity : double.negativeInfinity);
      }
    }
    final drag = widget.drag;
    final current = drag != null && drag.targetColumn == widget.columnIndex
        ? drag.targetIndex
        : null;

    return clampToPinZone(
      others,
      dragged.isPinned,
      dropIndexWithHysteresis(centers, pointerY, current),
    );
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

  /// Thẻ [task] ở vị trí [index], lấy từ cache khi được.
  Widget _cardFor(Task task, int index) {
    final canDrag = widget.drag != null && widget.canDrag(task);
    final rise = widget.firstShow(task.id);
    final cached = _cards[task.id];
    if (cached != null &&
        identical(cached.task, task) &&
        cached.canDrag == canDrag &&
        (cached.rise == rise || _keys[task.id]?.currentContext != null)) {
      return cached.widget;
    }
    final built = _card(task, index, canDrag: canDrag, rise: rise);
    _cards[task.id] = (task: task, canDrag: canDrag, rise: rise, widget: built);

    return built;
  }

  Widget _card(
    Task task,
    int index, {
    required bool canDrag,
    required bool rise,
  }) {
    final card = BoardTaskCard(
      key: ValueKey(task.id),
      task: task,
      rise: rise,
      canComplete: widget.canComplete,
      delay: Duration(milliseconds: 50 * math.min(index, 6)),
      // Đọc `widget` lúc chạm: widget thẻ được cache qua nhiều lần dựng cột.
      onTap: () => widget.onOpenTask(task),
    );
    final drag = widget.drag;
    // Thẻ không nhấc được (khoá) vẫn phải có khoá: `_indexAt` đo tâm mọi thẻ,
    // thiếu khoá thì nó bị coi như ở vô cực và chỗ chèn lệch.
    if (drag == null) return card;
    if (!canDrag) {
      return KeyedSubtree(key: _keyOf(task.id), child: card);
    }
    final feedback = BoardDragFeedback(task: task, controller: drag);
    final ghost = _LiftedGhost(
      drop: drag.column(widget.columnIndex),
      child: Opacity(
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
    );

    Widget draggable(bool enabled) => LongPressDraggable<Task>(
      key: _keyOf(task.id),
      data: task,
      delay: const Duration(milliseconds: 400),
      // 0 = không nhấc được, mà không đổi cấu trúc cây (thẻ giữ phần tử).
      maxSimultaneousDrags: enabled ? null : 0,
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
      feedback: feedback,
      childWhenDragging: ghost,
      child: card,
    );

    final liftable = widget.liftable;
    if (liftable == null) return draggable(true);

    return ValueListenableBuilder<bool>(
      valueListenable: liftable,
      builder: (_, enabled, _) => draggable(enabled),
    );
  }

  @override
  Widget build(BuildContext context) {
    final drag = widget.drag;
    final tasks = widget.tasks;
    final dropOf = drag?.column(widget.columnIndex) ?? const _IdleDrop();

    // Ô chỗ trống là các khe gắn trước mỗi thẻ (và một khe cuối cột): số mục
    // không đổi khi kéo, chỉ số không dịch, khoá của thẻ không đổi chỗ. Kéo
    // trong cùng cột thì bóng mờ gập lại ([_LiftedGhost]) chứ không bỏ thẻ
    // khỏi danh sách, nên cũng không mục nào đổi chỗ.
    Widget buildCards({required bool shrinkWrap}) => ListView.builder(
      shrinkWrap: shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      itemCount: tasks.length + 1,
      itemBuilder: (context, i) {
        if (i == tasks.length) {
          return _SlotGap(
            key: _gapKeyOf(i),
            drop: dropOf,
            index: i,
            gapOf: _gapFor,
            last: true,
            hasCards: _hasVisibleCards,
          );
        }

        return _CardSpacing(
          drop: dropOf,
          spaceOf: (drop) => _spaceAbove(i, drop),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SlotGap(
                key: _gapKeyOf(i),
                drop: dropOf,
                index: i,
                gapOf: _gapFor,
              ),
              RepaintBoundary(child: _cardFor(tasks[i], i)),
            ],
          ),
        );
      },
    );

    final body = _ColumnDropBuilder(
      drop: dropOf,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(
            name: widget.section.name,
            count: tasks.length,
            onOptions: widget.onOptions,
          ),
          Flexible(
            child: LayoutBuilder(
              builder: (_, constraints) => buildCards(
                shrinkWrap:
                    !constraints.maxHeight.isFinite || tasks.length <= 12,
              ),
            ),
          ),
          if (widget.onAddTask case final add?)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
              child: _AddTaskButton(
                onTap: () {
                  HapticFeedback.selectionClick();
                  add();
                },
              ),
            )
          else
            const SizedBox(height: 8),
        ],
      ),
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

/// Cột không kéo được: không bao giờ là đích, không có ô chỗ trống.
class _IdleDrop implements ValueListenable<BoardColumnDrop> {
  const _IdleDrop();

  @override
  BoardColumnDrop get value => (hot: false, slot: null);

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}
}

/// Nền và viền đích của cột. Nghe RIÊNG trạng thái kéo của cột này, chỉ đọc
/// `hot`; thân cột ([child]: đầu cột, thẻ, "Thêm công việc") dựng ngoài nó.
/// Kế thừa `ValueListenableBuilder` (thay vì dùng thẳng) để có tên lớp riêng:
/// test đếm lượt dựng lại theo `runtimeType` tách được builder của cột.
class _ColumnDropBuilder extends ValueListenableBuilder<BoardColumnDrop> {
  const _ColumnDropBuilder({
    required ValueListenable<BoardColumnDrop> drop,
    required Widget super.child,
  }) : super(valueListenable: drop, builder: _build);

  static Widget _build(
    BuildContext context,
    BoardColumnDrop drop,
    Widget? child,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final hot = drop.hot;
    final duration = OmniMotion.enabled(context)
        ? const Duration(milliseconds: 200)
        : Duration.zero;

    // Rãnh phẳng, không bo góc (bản 0.1.6 đã duyệt).
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
          child!,
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
  }
}

/// Khoảng phía trên một thẻ ([spaceOf]): 8, hoặc 0 khi thẻ phía trên (hay
/// chính thẻ này) là bóng mờ đã gập. Chỉ dựng lại khi khoảng ĐỔI — tức lúc
/// cột nguồn thành/thôi là đích — không phải mỗi lần đổi chỗ chèn.
class _CardSpacing extends StatefulWidget {
  const _CardSpacing({
    required this.drop,
    required this.spaceOf,
    required this.child,
  });

  final ValueListenable<BoardColumnDrop> drop;
  final double Function(BoardColumnDrop drop) spaceOf;
  final Widget child;

  @override
  State<_CardSpacing> createState() => _CardSpacingState();
}

class _CardSpacingState extends State<_CardSpacing> {
  late double _space = widget.spaceOf(widget.drop.value);

  void _changed() {
    final space = widget.spaceOf(widget.drop.value);
    if (space != _space) setState(() => _space = space);
  }

  @override
  void initState() {
    super.initState();
    widget.drop.addListener(_changed);
  }

  @override
  void didUpdateWidget(_CardSpacing old) {
    super.didUpdateWidget(old);
    if (old.drop != widget.drop) {
      old.drop.removeListener(_changed);
      widget.drop.addListener(_changed);
    }
    _space = widget.spaceOf(widget.drop.value);
  }

  @override
  void dispose() {
    widget.drop.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(top: _space),
    child: widget.child,
  );
}

/// Bóng mờ ở chỗ cũ của thẻ đang kéo. Khi thẻ được rê trong CHÍNH cột nguồn
/// (cột là đích), bóng gập về 0 để chỉ còn một ô chỗ trống ở vị trí mới; rời
/// cột thì mở lại. Gập/mở trượt 150ms như khe; giảm chuyển động thì tức thì.
class _LiftedGhost extends StatefulWidget {
  const _LiftedGhost({required this.drop, required this.child});

  final ValueListenable<BoardColumnDrop> drop;
  final Widget child;

  @override
  State<_LiftedGhost> createState() => _LiftedGhostState();
}

class _LiftedGhostState extends State<_LiftedGhost> {
  late bool _collapsed = widget.drop.value.hot;

  void _changed() {
    final collapsed = widget.drop.value.hot;
    if (collapsed != _collapsed) setState(() => _collapsed = collapsed);
  }

  @override
  void initState() {
    super.initState();
    widget.drop.addListener(_changed);
  }

  @override
  void didUpdateWidget(_LiftedGhost old) {
    super.didUpdateWidget(old);
    if (old.drop != widget.drop) {
      old.drop.removeListener(_changed);
      widget.drop.addListener(_changed);
    }
    _collapsed = widget.drop.value.hot;
  }

  @override
  void dispose() {
    widget.drop.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final child = _collapsed
        ? const SizedBox(width: double.infinity)
        : widget.child;
    if (!OmniMotion.enabled(context)) return child;

    return AnimatedSize(
      duration: const Duration(milliseconds: 150),
      curve: OmniCurves.standard,
      alignment: Alignment.topCenter,
      child: child,
    );
  }
}

/// Khe chèn thứ [index] của cột: cao 0 khi đóng, mở thành ô chỗ trống viền
/// đứt cao 64 (+ khoảng 8) khi chỗ chèn là nó. Mở/đóng trượt 150ms, nên các
/// thẻ phía sau trượt chứ không nhảy; giảm chuyển động thì tức thì.
///
/// Chỉ dựng lại khi CHÍNH nó đổi đóng↔mở: mỗi lần đổi chỗ chèn chỉ hai khe.
class _SlotGap extends StatefulWidget {
  const _SlotGap({
    super.key,
    required this.drop,
    required this.index,
    required this.gapOf,
    this.last = false,
    this.hasCards = _always,
  });

  static bool _always(BoardColumnDrop _) => true;

  /// Chiều cao ô chỗ trống.
  static const double height = 64;

  final ValueListenable<BoardColumnDrop> drop;
  final int index;

  /// Khe nào đang mở theo trạng thái kéo của cột (null: không khe nào).
  final int? Function(BoardColumnDrop drop) gapOf;

  /// Khe cuối cột (sau thẻ cuối): khoảng 8 nằm TRÊN ô, và chỗ chèn vượt cuối
  /// cũng mở nó.
  final bool last;

  /// Cột còn thẻ thấy được (khe cuối mới cần khoảng 8 phía trên).
  final bool Function(BoardColumnDrop drop) hasCards;

  @override
  State<_SlotGap> createState() => _SlotGapState();
}

class _SlotGapState extends State<_SlotGap> {
  late bool _open = _isOpen();
  late bool _lead = _hasLead();

  bool _isOpen() {
    final gap = widget.gapOf(widget.drop.value);
    if (gap == null) return false;

    return widget.last ? gap >= widget.index : gap == widget.index;
  }

  bool _hasLead() => widget.last && widget.hasCards(widget.drop.value);

  void _changed() {
    final open = _isOpen();
    final lead = _hasLead();
    if (open != _open || (open && lead != _lead)) {
      setState(() {
        _open = open;
        _lead = lead;
      });
    } else {
      _lead = lead;
    }
  }

  @override
  void initState() {
    super.initState();
    widget.drop.addListener(_changed);
  }

  @override
  void didUpdateWidget(_SlotGap old) {
    super.didUpdateWidget(old);
    if (old.drop != widget.drop) {
      old.drop.removeListener(_changed);
      widget.drop.addListener(_changed);
    }
    _open = _isOpen();
    _lead = _hasLead();
  }

  @override
  void dispose() {
    widget.drop.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final child = _open
        ? Padding(
            padding: widget.last
                ? EdgeInsets.only(top: _lead ? 8 : 0)
                : const EdgeInsets.only(bottom: 8),
            child: const OmniDashedBox(
              key: Key('drop-placeholder'),
              height: _SlotGap.height,
            ),
          )
        : const SizedBox(width: double.infinity);
    // Giảm chuyển động: mở/đóng ngay. Không dùng `AnimatedSize` với
    // `Duration.zero` — nó báo đổi cỡ ngay trong layout và vỡ assert.
    if (!OmniMotion.enabled(context)) return child;

    return AnimatedSize(
      duration: const Duration(milliseconds: 150),
      curve: OmniCurves.standard,
      alignment: Alignment.topCenter,
      child: child,
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
                    HapticFeedback.selectionClick();
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
