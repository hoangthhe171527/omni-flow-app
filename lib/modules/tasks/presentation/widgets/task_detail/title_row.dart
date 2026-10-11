import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/error/app_exception.dart';
import '../../../../../design/platform/omni_motion_scope.dart';
import '../../../../../design/tokens/tokens.dart';
import '../../../application/task_controller.dart';
import '../../../application/tasks_providers.dart';
import '../../../domain/task.dart';

/// Tiêu đề việc có ô tích (`TaskDetail.dc.html`): ô 26 bo 6 (viền 2
/// `#9AA5B8`) trong vùng chạm 44, nảy `tick` 350ms; chữ 20 w600.
///
/// Ô tích thay nút "Hoàn thành / Mở lại công việc" của thanh đáy cũ: cùng
/// đường `setStatus` (`done` / `doing`), cùng lời báo, cùng lời server khi
/// bị từ chối. Ô đổi ngay dưới ngón tay; server từ chối thì trả về như cũ.
class TaskTitleRow extends ConsumerStatefulWidget {
  const TaskTitleRow({
    super.key,
    required this.task,
    required this.taskId,
    required this.canComplete,
  });

  final Task task;
  final String taskId;
  final bool canComplete;

  @override
  ConsumerState<TaskTitleRow> createState() => _TaskTitleRowState();
}

class _TaskTitleRowState extends ConsumerState<TaskTitleRow>
    with SingleTickerProviderStateMixin {
  bool? _doneOverride;
  bool _saving = false;

  late final AnimationController _tick = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 350),
  );

  /// `@keyframes tick`: 1 → 1.25 ở 40% → 1.
  late final Animation<double> _bounce = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween<double>(
        begin: 1,
        end: 1.25,
      ).chain(CurveTween(curve: OmniCurves.standard)),
      weight: 40,
    ),
    TweenSequenceItem(
      tween: Tween<double>(
        begin: 1.25,
        end: 1,
      ).chain(CurveTween(curve: OmniCurves.standard)),
      weight: 60,
    ),
  ]).animate(_tick);

  bool get _done => _doneOverride ?? widget.task.isDone;

  @override
  void didUpdateWidget(TaskTitleRow old) {
    super.didUpdateWidget(old);
    if (old.task.status != widget.task.status && !_saving) {
      _doneOverride = null;
    }
  }

  @override
  void dispose() {
    _tick.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_saving) return;
    final next = !_done;
    // Lấy trước khi await: màn có thể đã đóng khi server trả lời.
    final messenger = ScaffoldMessenger.of(context);
    final container = ProviderScope.containerOf(context);
    final controller = ref.read(taskDetailProvider(widget.taskId).notifier);

    // Xong cả việc nặng hơn tick một việc con: rung mạnh hơn.
    unawaited(HapticFeedback.mediumImpact());
    setState(() {
      _doneOverride = next;
      _saving = true;
    });
    if (OmniMotion.enabled(context)) unawaited(_tick.forward(from: 0));

    try {
      // `doing` — mã chuẩn của server (CV-I15), không phải `in_progress`.
      await controller.setStatus(next ? 'done' : 'doing');
      unawaited(container.read(myTasksProvider.notifier).refresh());
      if (mounted) {
        setState(() {
          _saving = false;
          _doneOverride = null;
        });
      }
      // Báo SAU khi server đã nhận.
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            next
                ? 'Đã báo hoàn thành. Quản lý sẽ nhận thông báo.'
                : 'Đã mở lại công việc.',
          ),
        ),
      );
    } on AppException catch (error) {
      _fail(
        messenger,
        failureText(error, 'Chưa lưu được. Kiểm tra mạng rồi thử lại.'),
      );
    } on Object {
      _fail(messenger, 'Chưa lưu được. Vui lòng thử lại.');
    }
  }

  void _fail(ScaffoldMessengerState messenger, String message) {
    if (mounted) {
      setState(() {
        _doneOverride = null;
        _saving = false;
      });
    }
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final done = _done;
    final faint = OmniTaskTones.of(context).faint;
    final enabled = widget.canComplete;

    final box = ScaleTransition(
      key: const ValueKey('title-tick-bounce'),
      scale: _bounce,
      child: Container(
        key: const ValueKey('title-tick-box'),
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: done ? scheme.primary : scheme.surface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: done ? scheme.primary : faint,
            width: done ? 0 : 2,
            style: done ? BorderStyle.none : BorderStyle.solid,
          ),
        ),
        child: done
            ? Icon(
                Icons.check_rounded,
                size: OmniIconSize.sm,
                color: scheme.onPrimary,
              )
            : null,
      ),
    );

    final tick = Semantics(
      button: enabled,
      toggled: done,
      label: done ? 'Bỏ đánh dấu xong' : 'Đánh dấu xong',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? _toggle : null,
        child: SizedBox.square(
          dimension: 44,
          child: Align(alignment: Alignment.centerLeft, child: box),
        ),
      ),
    );

    // `.ck` lề trái −10 của bản mẫu: ô 26 vẽ thẳng mép thân (x 0), chữ bắt
    // đầu ở 38 (−10 + 44 + 4). Bố cục thật, không dịch hình: chữ được trọn bề
    // rộng của nó. Vùng chạm 44 của ô phủ lên 6px đầu dòng chữ — chữ không
    // chạm được nên không tranh chạm.
    return Stack(
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.only(left: 38, top: 7),
            child: Text(
              widget.task.title,
              key: const ValueKey('detail-title'),
              style: OmniType.title.copyWith(
                letterSpacing: 0,
                color: scheme.onSurface,
              ),
            ),
          ),
        ),
        Positioned(left: 0, top: 0, width: 44, height: 44, child: tick),
      ],
    );
  }
}
