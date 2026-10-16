import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../design/platform/omni_motion_scope.dart';
import '../../../../design/tokens/tokens.dart';
import '../../../tasks/domain/task.dart';

/// Trạng thái kéo mà MỘT cột cần: nó có đang là cột đích không ([hot]), và ô
/// chỗ trống nằm ở chỉ số nào trong nó ([slot]). [slot] null ở cột nguồn và
/// ở cột không phải đích.
typedef BoardColumnDrop = ({bool hot, int? slot});

/// Trạng thái một lượt kéo thẻ trên bảng: thẻ nào, từ cột nào, đang lơ lửng
/// trên cột nào và sẽ chèn ở đâu. Bản nổi nghe cả bộ điều khiển; mỗi cột chỉ
/// nghe [column] của mình, nên đổi chỗ chèn chỉ dựng lại cột cũ và cột mới.
///
/// Chỉ báo khi một trong các giá trị ĐỔI: con trỏ đi qua lại trong một khe
/// giữa hai thẻ không dựng lại gì.
class BoardDragController extends ChangeNotifier {
  final _columns = <int, ValueNotifier<BoardColumnDrop>>{};

  /// Trạng thái kéo của cột [index] (tạo lười). Chỉ báo khi chính cột này
  /// đổi (`ValueNotifier` so `==` của record).
  ValueListenable<BoardColumnDrop> column(int index) =>
      _columns.putIfAbsent(index, () => ValueNotifier(_stateOf(index)));

  BoardColumnDrop _stateOf(int i) => (
    hot: targetColumn == i,
    slot: targetColumn == i && fromColumn != i ? targetIndex : null,
  );

  /// Gọi sau mỗi lần đổi task/fromColumn/targetColumn/targetIndex.
  void _syncColumns() {
    for (final e in _columns.entries) {
      e.value.value = _stateOf(e.key);
    }
  }

  @override
  void dispose() {
    for (final n in _columns.values) {
      n.dispose();
    }
    _columns.clear();
    super.dispose();
  }

  Task? task;
  int? fromColumn;
  int? targetColumn;
  int? targetIndex;

  /// Vị trí con trỏ toàn cục lần cuối. Không báo: trang đọc nó khi cần.
  Offset? pointer;

  /// Tên cột đích, cho dòng "Thả vào …" của bản nổi.
  String targetName = '';

  bool get active => task != null;

  void start(Task task, int fromColumn) {
    this.task = task;
    this.fromColumn = fromColumn;
    targetColumn = null;
    targetIndex = null;
    targetName = '';
    _syncColumns();
    notifyListeners();
  }

  void hover(int column, int index, String name) {
    if (targetColumn == column && targetIndex == index && targetName == name) {
      return;
    }
    targetColumn = column;
    targetIndex = index;
    targetName = name;
    _syncColumns();
    notifyListeners();
  }

  /// Con trỏ rời [column]. Cột khác có thể đã nhận hover trước (thứ tự sự kiện
  /// không đảm bảo), nên chỉ xoá khi đích vẫn là cột này.
  void leave(int column) {
    if (targetColumn != column) return;
    targetColumn = null;
    targetIndex = null;
    targetName = '';
    _syncColumns();
    notifyListeners();
  }

  /// Bỏ đích (con trỏ không còn trên cột nào), dù đích đang là cột nào.
  void clearTarget() {
    if (targetColumn == null) return;
    targetColumn = null;
    targetIndex = null;
    targetName = '';
    _syncColumns();
    notifyListeners();
  }

  /// Mỗi cột kéo được đăng ký một hàm dò: con trỏ toàn cục → chỗ chèn, hoặc
  /// null nếu con trỏ không nằm trong cột. Trang dùng nó sau khi dải tự trượt,
  /// vì lúc đó Flutter không dò lại `DragTarget` khi ngón tay đứng yên.
  final _probes = <int, int? Function(Offset pointer, Task dragged)>{};

  void attach(int column, int? Function(Offset, Task) probe) =>
      _probes[column] = probe;

  /// Chỉ gỡ khi [column] vẫn là của [probe] (cột mới cùng chỉ số có thể đã
  /// đăng ký trước khi cột cũ bị huỷ).
  void detach(int column, int? Function(Offset, Task) probe) {
    if (_probes[column] == probe) _probes.remove(column);
  }

  /// Chỗ chèn trong [column] tại [pointer]; null nếu cột chưa dựng, không
  /// kéo được, hoặc con trỏ nằm ngoài cột.
  int? indexAt(int column, Offset pointer) {
    final dragged = task;
    final probe = _probes[column];
    if (dragged == null || probe == null) return null;

    return probe(pointer, dragged);
  }

  void clear() {
    if (task == null && targetColumn == null) return;
    task = null;
    fromColumn = null;
    targetColumn = null;
    targetIndex = null;
    targetName = '';
    pointer = null;
    _syncColumns();
    notifyListeners();
  }
}

/// Neo của `LongPressDraggable`: bản nổi lệch (−134, −30) so với con trỏ.
Offset boardDragAnchor(
  Draggable<Object> draggable,
  BuildContext context,
  Offset position,
) => BoardDragFeedback.grab;

/// Bản nổi của thẻ đang kéo (`AppBoard.dc.html`): rộng 268, bóng đậm, nghiêng
/// −1.5° và phóng 1.04 trong 180ms. Giảm chuyển động thì chỉ còn bóng.
class BoardDragFeedback extends StatelessWidget {
  const BoardDragFeedback({
    super.key,
    required this.task,
    required this.controller,
  });

  static const double width = 268;

  /// Chỗ ngón tay nằm TRONG bản nổi: giữa chiều ngang, 30 từ đỉnh — tức bản
  /// nổi lệch (−134, −30) so với con trỏ (`AppBoard.dc.html`).
  static const Offset grab = Offset(134, 30);

  final Task task;
  final BoardDragController controller;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final card = Material(
      type: MaterialType.transparency,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(8),
          boxShadow: OmniShadows.lifted,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                task.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: OmniType.bodySm.copyWith(
                  fontWeight: FontWeight.w500,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              ListenableBuilder(
                listenable: controller,
                builder: (context, _) => Text(
                  controller.targetName.isEmpty
                      ? 'Kéo tới một nhóm việc'
                      : 'Thả vào “${controller.targetName}”',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: OmniType.micro.copyWith(
                    fontWeight: FontWeight.w400,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    // Thẻ vẽ một lần vào lớp riêng: kéo chỉ dời offset lớp (và xoay/phóng
    // trong 180ms đầu), không vẽ lại bóng mỗi khung.
    if (!OmniMotion.enabled(context)) {
      return SizedBox(
        key: const Key('drag-feedback'),
        width: width,
        child: RepaintBoundary(child: card),
      );
    }

    return SizedBox(
      key: const Key('drag-feedback'),
      width: width,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 180),
        curve: OmniCurves.standard,
        builder: (context, t, child) => Transform.rotate(
          angle: -0.0261799 * t,
          child: Transform.scale(scale: 1 + 0.04 * t, child: child),
        ),
        child: RepaintBoundary(child: card),
      ),
    );
  }
}
