import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../design/components/omni_avatar.dart';
import '../../../../design/components/omni_dashed_circle.dart';
import '../../../../design/components/omni_motion_widgets.dart';
import '../../../../design/components/omni_task_chip.dart';
import '../../../../design/platform/omni_motion_scope.dart';
import '../../../../design/tokens/tokens.dart';
import '../../../tasks/application/tasks_providers.dart';
import '../../../tasks/data/tasks_api.dart';
import '../../../tasks/domain/task.dart';
import '../../../tasks/tasks.dart';
import '../../application/plans_providers.dart';

/// Thẻ việc trên bảng kế hoạch (`Board.dc.html` `.card`).
///
/// Từ trên xuống: dải nhãn (vạch 32×6), hàng ô tích + tiêu đề + ghim, hàng
/// meta lùi 28 (chip hạn, việc con, tệp, bình luận, người làm ở mép phải).
///
/// Việc con kế tiếp, thanh tiến độ và điểm kiểm tra đã rời thẻ: xem ở chi
/// tiết. `TaskCard` vẫn là thẻ của "Việc của tôi", Workload và tìm kiếm.
class BoardTaskCard extends ConsumerStatefulWidget {
  const BoardTaskCard({
    super.key,
    required this.task,
    required this.onTap,
    this.delay = Duration.zero,
    this.rise = true,
    this.canComplete = false,
  });

  final Task task;
  final VoidCallback onTap;

  /// Độ trễ của hiệu ứng `rise`, để các thẻ trong một cột hiện lần lượt.
  final Duration delay;

  /// false = hiện ngay. Bảng chỉ cho thẻ "rise" ở lần ĐẦU nó hiện: danh sách
  /// lười dựng lại thẻ khi cuộn về, và phát lại hiệu ứng lúc đó đọc như giật.
  final bool rise;

  /// `taskAccess.canComplete`. false = không có ô tích.
  final bool canComplete;

  @override
  ConsumerState<BoardTaskCard> createState() => _BoardTaskCardState();
}

class _BoardTaskCardState extends ConsumerState<BoardTaskCard>
    with SingleTickerProviderStateMixin {
  /// Trạng thái xong đã tích nhưng server chưa trả về thẻ mới. null = theo
  /// [Task.isDone].
  bool? _doneOverride;
  bool _saving = false;

  late final AnimationController _tick = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 350),
  );

  /// `@keyframes tick`: 1 → 1.25 ở 40% → 1, cubic(.2,.8,.2,1).
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
  void didUpdateWidget(BoardTaskCard old) {
    super.didUpdateWidget(old);
    // Bản server mới về: nó là sự thật, bỏ phần lạc quan.
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
    // Lấy trước khi await: thẻ có thể rời cây (cuộn, đổi lọc) trước khi
    // server trả lời.
    final container = ProviderScope.containerOf(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final api = ref.read(tasksApiProvider);
    final planId = widget.task.projectId;

    unawaited(HapticFeedback.lightImpact());
    setState(() {
      _doneOverride = next;
      _saving = true;
    });
    if (OmniMotion.enabled(context)) unawaited(_tick.forward(from: 0));

    try {
      // `doing` — mã chuẩn của server, cùng đường với nút Hoàn thành ở chi
      // tiết (vòng tick ở dòng tên — TitleRow).
      await api.setStatus(widget.task.id, next ? 'done' : 'doing');
      if (planId != null) container.invalidate(planTasksProvider(planId));
      if (mounted) setState(() => _saving = false);
    } on AppException catch (error) {
      // Lời của server (422 còn việc con chưa xong, 403 chỉ xem…): người
      // dùng cần biết VÌ SAO, không phải thử lại mãi.
      _fail(
        messenger,
        failureText(error, 'Chưa lưu được. Kiểm tra mạng rồi thử lại.'),
      );
    } on Object {
      _fail(messenger, 'Chưa lưu được. Vui lòng thử lại.');
    }
  }

  void _fail(ScaffoldMessengerState? messenger, String message) {
    if (mounted) {
      setState(() {
        _doneOverride = null;
        _saving = false;
      });
    }
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final scheme = Theme.of(context).colorScheme;
    final done = _done;
    final catalog = ref.watch(taskLabelsProvider).valueOrNull ?? const [];
    final byCode = {for (final l in catalog) l.code: l};
    final labels = [for (final code in task.labels) ?byCode[code]];

    final meta = <Widget>[
      // Theo trạng thái lạc quan: vừa tích xong thì thôi báo quá hạn ngay,
      // không đợi server.
      if (task.dueDate != null)
        DueChip(
          task: done == task.isDone
              ? task
              : task.copyWith(status: done ? 'done' : 'doing'),
          icon: Icons.calendar_today_outlined,
        ),
      if (task.priority == 'high') const OmniTaskChip.high('Ưu tiên cao'),
      if (task.hasSubtasks)
        _Meta(
          icon: Icons.checklist_rounded,
          text: '${task.doneCount}/${task.totalCount}',
          semantics: '${task.doneCount} trên ${task.totalCount} việc con xong',
        ),
      if (task.attachmentCount > 0)
        _Meta(
          icon: Icons.attach_file_rounded,
          text: '${task.attachmentCount}',
          semantics: '${task.attachmentCount} tệp đính kèm',
        ),
      if (task.commentCount > 0)
        _Meta(
          icon: Icons.chat_bubble_outline_rounded,
          text: '${task.commentCount}',
          semantics: '${task.commentCount} bình luận',
        ),
    ];

    // Hàng tiêu đề bắt đầu dưới dải nhãn (6 + lề 8).
    final rowTop = labels.isEmpty ? 0.0 : 14.0;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (labels.isNotEmpty)
          Semantics(
            container: true,
            label: 'Nhãn: ${labels.map((l) => l.label).join(', ')}',
            excludeSemantics: true,
            child: Padding(
              padding: const EdgeInsets.only(left: 2, bottom: 8),
              child: Row(
                children: [
                  for (var i = 0; i < labels.length; i++) ...[
                    if (i > 0) const SizedBox(width: 4),
                    Container(
                      key: ValueKey('label-bar-${labels[i].code}'),
                      width: 32,
                      height: 6,
                      decoration: BoxDecoration(
                        color: OmniLabelColors.parseHex(labels[i].color),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // `.ck` 44 lề âm −10/−8: chiếm 26 × 22 trong dòng, cách 6.
            if (widget.canComplete) const SizedBox(width: 32, height: 22),
            Expanded(
              child: Text(
                task.title,
                style: OmniType.bodySm.copyWith(
                  fontWeight: FontWeight.w500,
                  height: 1.35,
                  decoration: done ? TextDecoration.lineThrough : null,
                  color: done ? scheme.onSurfaceVariant : scheme.onSurface,
                ),
              ),
            ),
            if (task.isPinned) ...[
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Semantics(
                  container: true,
                  label: 'Đã ghim',
                  child: ExcludeSemantics(
                    child: Icon(
                      Icons.push_pin_rounded,
                      size: 16,
                      color: scheme.primary,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        Padding(
          padding: EdgeInsets.only(top: 8, left: widget.canComplete ? 28 : 0),
          child: Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: meta,
                ),
              ),
              const SizedBox(width: 6),
              _Assignees(
                names: task.assigneeNames,
                avatars: task.assigneeAvatars,
              ),
            ],
          ),
        ),
      ],
    );

    final card = Semantics(
      button: true,
      label: _semanticLabel(done),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: const BorderRadius.all(Radius.circular(8)),
          child: Container(
            key: const ValueKey('card-shell'),
            padding: const EdgeInsets.fromLTRB(8, 10, 10, 10),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: OmniColors.ink.withValues(alpha: 0.08),
                  offset: const Offset(0, 1),
                  blurRadius: 2,
                ),
              ],
            ),
            child: content,
          ),
        ),
      ),
    );

    final body = !widget.canComplete
        ? card
        : Stack(
            clipBehavior: Clip.none,
            children: [
              card,
              // Vùng chạm 44 phủ mép trên-trái thẻ; ô vẽ 20 nằm đúng chỗ của
              // `.ck` (trái 10, trên = hàng tiêu đề + 1).
              Positioned(
                left: 0,
                top: math.max(0, 10 + rowTop - 11),
                child: _TickBox(
                  done: done,
                  bounce: _bounce,
                  boxTop: 10 + rowTop + 1 - math.max(0, 10 + rowTop - 11),
                  onTap: _toggle,
                ),
              ),
            ],
          );

    // Mờ .78 bọc CẢ thẻ lẫn ô tích (`.card` opacity): ô tích nằm ngoài thẻ
    // trong Stack nên đặt Opacity bên trong là bỏ sót nó. Chưa xong thì không
    // bọc Opacity(1.0) để đỡ cấp phát lớp đệm mỗi khung cuộn.
    return OmniRise(
      delay: widget.delay,
      animate: widget.rise,
      child: done
          ? Opacity(
              key: const ValueKey('card-opacity'),
              opacity: 0.78,
              child: body,
            )
          : body,
    );
  }

  String _semanticLabel(bool done) {
    final task = widget.task;
    final parts = <String>[task.title];
    if (done) {
      parts.add('đã xong');
    } else {
      final due = dueToneOf(task);
      if (due.tone == DueTone.late) parts.add(due.label.toLowerCase());
    }

    return parts.join(', ');
  }
}

/// Ô tích `.ck` / `.box`: vùng chạm 44, ô vẽ 20 bo 5.
class _TickBox extends StatelessWidget {
  const _TickBox({
    required this.done,
    required this.bounce,
    required this.boxTop,
    required this.onTap,
  });

  final bool done;
  final Animation<double> bounce;

  /// Đỉnh ô vẽ tính từ đỉnh vùng chạm.
  final double boxTop;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final faint = OmniTaskTones.of(context).faint;

    return Semantics(
      button: true,
      toggled: done,
      label: done ? 'Bỏ đánh dấu xong' : 'Đánh dấu xong',
      excludeSemantics: true,
      child: GestureDetector(
        key: const ValueKey('tick-target'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox.square(
          dimension: 44,
          child: Padding(
            padding: EdgeInsets.only(left: 10, top: boxTop),
            child: Align(
              alignment: Alignment.topLeft,
              child: ScaleTransition(
                key: const ValueKey('tick-bounce'),
                scale: bounce,
                child: Container(
                  key: const ValueKey('tick-box'),
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: done ? scheme.primary : scheme.surface,
                    borderRadius: BorderRadius.circular(5),
                    border: done ? null : Border.all(color: faint, width: 1.5),
                  ),
                  child: done
                      ? Icon(
                          Icons.check_rounded,
                          size: 14,
                          color: scheme.onPrimary,
                        )
                      : null,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// `.mt`: biểu tượng 14, cách 3, chữ 12 màu phụ.
class _Meta extends StatelessWidget {
  const _Meta({
    required this.icon,
    required this.text,
    required this.semantics,
  });

  final IconData icon;
  final String text;
  final String semantics;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;

    return Semantics(
      container: true,
      label: semantics,
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 3),
          Text(
            text,
            style: OmniType.micro.copyWith(
              fontWeight: FontWeight.w400,
              color: color,
              fontFeatures: OmniType.tabular,
            ),
          ),
        ],
      ),
    );
  }
}

/// `.av`: avatar 24 (viền 2 màu `surface`), chồng −6, tối đa 3 + "+n".
/// Chưa ai làm thì vòng nét đứt có +.
class _Assignees extends StatelessWidget {
  const _Assignees({required this.names, this.avatars = const []});

  final List<String> names;
  final List<String?> avatars;

  static const _max = 3;
  static const double _size = 24;
  static const double _ring = 2;
  static const double _step = _size - 6;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (names.isEmpty) {
      return Semantics(
        container: true,
        label: 'Chưa giao ai',
        excludeSemantics: true,
        child: OmniDashedCircle(
          size: _size,
          color: OmniTaskTones.of(context).faint,
          fill: scheme.surface,
        ),
      );
    }

    final shown = names.take(_max).toList();
    final extra = names.length - shown.length;

    return Semantics(
      container: true,
      label: names.join(', '),
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: _size + (shown.length - 1) * _step,
            height: _size,
            child: Stack(
              children: [
                for (var i = 0; i < shown.length; i++)
                  Positioned(
                    left: i * _step,
                    child: Container(
                      key: const ValueKey('assignee'),
                      width: _size,
                      height: _size,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: scheme.surface, width: _ring),
                      ),
                      child: _Face(
                        name: shown[i],
                        imageUrl: i < avatars.length ? avatars[i] : null,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (extra > 0) ...[
            const SizedBox(width: OmniSpacing.xs),
            Text(
              '+$extra',
              style: OmniType.micro.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Mặt người trong avatar 20: ảnh nếu có, không thì MỘT chữ cái (tên gọi,
/// chữ cuối) 12 w600 — avatar 20 không chứa nổi hai chữ ở cỡ 12.
class _Face extends StatelessWidget {
  const _Face({required this.name, this.imageUrl});

  final String name;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    if (imageUrl != null) {
      return OmniAvatar(name: name, imageUrl: imageUrl, size: 20);
    }
    final dark = Theme.of(context).brightness == Brightness.dark;
    // MỘT chữ (ô 20 không vừa hai chữ cỡ 12): chữ đầu của chữ CUỐI — tên
    // người Việt gọi theo chữ cuối ("Trần Minh" → M, "Hoàng" → H).
    final words = name.trim().split(RegExp(r'\s+'));
    final initial = words.last.isEmpty
        ? '?'
        : words.last.characters.first.toUpperCase();

    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: dark ? OmniColors.darkAvatarSurface : OmniColors.avatarSurface,
      ),
      child: Text(
        initial,
        style: OmniType.micro.copyWith(
          height: 1,
          fontWeight: FontWeight.w600,
          color: dark
              ? OmniColors.darkAvatarForeground
              : OmniColors.avatarForeground,
        ),
      ),
    );
  }
}
