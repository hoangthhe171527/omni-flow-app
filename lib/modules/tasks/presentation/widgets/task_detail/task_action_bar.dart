import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../../core/error/app_exception.dart';
import '../../../../../design/platform/omni_motion_scope.dart';
import '../../../../../design/tokens/tokens.dart';
import '../../../application/task_controller.dart';
import '../../../application/tasks_providers.dart';
import '../../../data/tasks_api.dart';
import '../../../domain/task.dart';

/// Thanh đáy kính mờ (`TaskDetail.dc.html`) đứng yên trong khi các khối cuộn.
///
/// Nó nằm TRÊN thanh home chứ không dưới, và nút cao 46 — đây là thứ cuối cùng
/// người thợ chạm bằng ngón tay bẩn trước khi đặt máy xuống. Nút máy ảnh vuông
/// 46 bên trái, nút chính chiếm phần còn lại: "Hoàn thành công việc" khi chưa
/// xong, "Mở lại công việc" khi đã xong (đổi màu 350ms).
class TaskActionBar extends ConsumerStatefulWidget {
  const TaskActionBar({
    super.key,
    required this.task,
    required this.canComplete,
    required this.canAttach,
    required this.taskId,
  });

  final Task task;
  final bool canComplete;
  final bool canAttach;
  final String taskId;

  @override
  ConsumerState<TaskActionBar> createState() => _TaskActionBarState();
}

class _TaskActionBarState extends ConsumerState<TaskActionBar> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (!widget.canComplete && !widget.canAttach) {
      return const SizedBox.shrink();
    }

    final done = widget.task.isDone;
    // `padding` (đã trừ phần bàn phím che), không phải `viewPadding`: bàn phím
    // mở thì thanh nằm sát nó, không để thêm một khoảng hở bằng thanh home.
    final bottom = math.max(8.0, MediaQuery.paddingOf(context).bottom);

    // Nền đặc: mặt sau là danh sách cuộn, làm mờ nó không có gì để mờ đẹp mà
    // vẫn tốn một lớp BackdropFilter mỗi khung hình.
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 8, 16, bottom),
        child: Row(
          children: [
            if (widget.canAttach) ...[
              _CameraButton(onTap: _busy ? null : _attachPhoto),
              const SizedBox(width: 10),
            ],
            if (widget.canComplete)
              Expanded(
                child: _MainButton(
                  done: done,
                  onTap: _busy ? null : () => _setStatus(!done),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _setStatus(bool done) async {
    // Lấy trước khi await: sau đó màn có thể đã rời cây widget.
    final messenger = ScaffoldMessenger.of(context);
    final container = ProviderScope.containerOf(context);
    // Finishing a whole task is a heavier act than ticking one stage, so it
    // gets the heavier haptic.
    unawaited(HapticFeedback.mediumImpact());
    setState(() => _busy = true);
    try {
      await ref
          .read(taskDetailProvider(widget.taskId).notifier)
          // `doing` — mã chuẩn của server; `in_progress` bị lưu nguyên và không
          // bảng nào có cột đó (CV-I15). API A2 còn chuẩn hoá cho dự án có bộ
          // trạng thái riêng.
          .setStatus(done ? 'done' : 'doing');
      // The list behind this screen is showing the old progress until told.
      unawaited(container.read(myTasksProvider.notifier).refresh());
      // Báo SAU khi server đã nhận, không trước: "đã báo quản lý" mà chưa ghi
      // được là một lời nói dối.
      _say(
        messenger,
        done
            ? 'Đã báo hoàn thành. Quản lý sẽ nhận thông báo.'
            : 'Đã mở lại công việc.',
      );
    } on AppException catch (error) {
      _say(
        messenger,
        _failureText(error, 'Chưa lưu được. Kiểm tra mạng rồi thử lại.'),
      );
    } on Object {
      _say(messenger, 'Chưa lưu được. Vui lòng thử lại.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Đính ảnh: chụp mới, hoặc lấy ảnh đã có sẵn trong máy.
  ///
  /// Trước đây chỉ mở thẳng camera. Nhưng người thợ thường đã chụp rồi — ảnh
  /// vừa gửi trong nhóm Zalo, hoặc chụp lúc tháo máy nửa tiếng trước — và bắt
  /// chụp lại một cây đàn đã lắp xong thì đơn giản là không làm được.
  Future<void> _attachPhoto() async {
    final messenger = ScaffoldMessenger.of(context);
    final source = await _pickSource();
    if (source == null) return;

    final photo = await ImagePicker().pickImage(
      source: source,
      imageQuality: 85,
    );
    if (photo == null || !mounted) return;

    setState(() => _busy = true);
    try {
      await ref.read(tasksApiProvider).attach(widget.taskId, photo.path);
      if (!mounted) return;
      await ref.read(taskDetailProvider(widget.taskId).notifier).refresh();
      _say(messenger, 'Đã đính kèm ảnh.');
    } on AppException catch (error) {
      _say(
        messenger,
        _failureText(error, 'Chưa gửi được ảnh. Thử lại khi có mạng.'),
      );
    } on Object {
      _say(messenger, 'Chưa gửi được ảnh. Vui lòng thử lại.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Hỏi chụp mới hay chọn từ máy. null = đóng lại, không đính gì.
  Future<ImageSource?> _pickSource() => showModalBottomSheet<ImageSource>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Chụp đứng trước: ở xưởng thì phần lớn là chụp ngay tại chỗ, và mục
          // đầu tiên là mục ngón tay bẩn chạm trúng.
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Chụp ảnh'),
            onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Chọn ảnh có sẵn'),
            onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
          ),
        ],
      ),
    ),
  );

  /// Lỗi mạng thì nhắc mạng; mọi lỗi khác là lời của API (422 phụ thuộc, 403
  /// chỉ xem, ảnh quá 25 MB…) — thợ cần biết VÌ SAO, không phải thử lại mãi
  /// (CV-I6). `NetworkException` có `code` (vd `file_unreadable`) là lỗi có
  /// lời riêng, không phải mất mạng.
  static String _failureText(AppException e, String networkText) =>
      (e is TimeoutException || (e is NetworkException && e.code == null))
      ? networkText
      : e.message;

  /// Messenger lấy TRƯỚC khi await, nên báo được cả khi màn đã đóng.
  void _say(ScaffoldMessengerState messenger, String message) {
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }
}

/// Nút máy ảnh vuông 46, bo 8, viền.
class _CameraButton extends StatelessWidget {
  const _CameraButton({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      label: 'Chụp ảnh',
      button: true,
      enabled: onTap != null,
      child: Material(
        color: scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: OmniColors.controlBorderOf(context)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: 46,
            height: 46,
            child: Icon(
              Icons.photo_camera_outlined,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

/// Nút chính cao 46, bo 8. MÀU THƯƠNG HIỆU, không phải màu "thành công".
///
/// Chữ trắng trên xanh lá #10B981 chỉ đạt 2,5:1 — trượt chuẩn 4,5:1 trên đúng
/// cái nút được bấm nhiều nhất trong ngày, ngoài xưởng ánh sáng xấu. Và đó là
/// màu xanh THỨ HAI đứng cạnh mòng két thương hiệu: hai xanh cạnh tranh nhau,
/// không cái nào thắng. Trắng trên primary ≈ 7:1; `test/design/contrast_test`
/// giữ cặp này. Đã xong thì nút lùi thành nền `surface` có viền, để "Mở lại"
/// không kêu to như "Hoàn thành".
class _MainButton extends StatelessWidget {
  const _MainButton({required this.done, required this.onTap});

  final bool done;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final duration = OmniMotion.enabled(context)
        ? const Duration(milliseconds: 350)
        : Duration.zero;
    final foreground = done ? scheme.onSurface : scheme.onPrimary;

    return Semantics(
      button: true,
      enabled: onTap != null,
      child: AnimatedContainer(
        duration: duration,
        curve: Curves.easeOut,
        height: 46,
        decoration: BoxDecoration(
          color: done ? scheme.surface : scheme.primary,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: done ? OmniColors.controlBorderOf(context) : scheme.primary,
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: Center(
              child: TweenAnimationBuilder<Color?>(
                tween: ColorTween(end: foreground),
                duration: duration,
                builder: (context, color, _) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      done ? Icons.undo_rounded : Icons.check_rounded,
                      size: 20,
                      color: color,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        done ? 'Mở lại công việc' : 'Hoàn thành công việc',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: OmniType.bodyStrong.copyWith(color: color),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
