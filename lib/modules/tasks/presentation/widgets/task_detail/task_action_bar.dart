import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../../design/tokens/tokens.dart';
import '../../../application/task_controller.dart';
import '../../../application/tasks_providers.dart';
import '../../../data/tasks_api.dart';
import '../../../domain/task.dart';

/// The bar that stays put while the stages scroll.
///
/// It sits above the home indicator rather than under it, and its buttons are
/// 52dp tall — this is the last thing a worker taps with a dirty thumb before
/// putting the phone down.
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

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(OmniSpacing.lg),
          child: Row(
            children: [
              if (widget.canAttach) ...[
                _SquareButton(
                  icon: Icons.photo_camera_outlined,
                  tooltip: 'Chụp ảnh đính kèm',
                  onPressed: _busy ? null : _attachPhoto,
                ),
                const SizedBox(width: OmniSpacing.md),
              ],
              if (widget.canComplete)
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: _busy ? null : () => _setStatus(!done),
                      // Màu THƯƠNG HIỆU, không phải màu "thành công".
                      //
                      // Chữ trắng trên xanh lá #10B981 chỉ đạt 2,5:1 — trượt
                      // chuẩn 4,5:1 trên đúng cái nút được bấm nhiều nhất trong
                      // ngày, ngoài xưởng ánh sáng xấu. Và đó là màu xanh THỨ
                      // HAI đứng cạnh mòng két thương hiệu: hai xanh cạnh tranh
                      // nhau, không cái nào thắng. Trắng trên primary ≈ 7:1.
                      // `test/design/contrast_test.dart` giữ cặp này.
                      style: FilledButton.styleFrom(
                        backgroundColor: done
                            ? scheme.surfaceContainerHighest
                            : scheme.primary,
                        foregroundColor: done
                            ? scheme.onSurface
                            : scheme.onPrimary,
                      ),
                      icon: Icon(
                        done
                            ? Icons.undo_rounded
                            : Icons.check_circle_outline_rounded,
                      ),
                      label: Text(
                        done ? 'Mở lại công việc' : 'Hoàn thành công việc',
                        style: OmniType.bodyStrong,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _setStatus(bool done) async {
    // Finishing a whole task is a heavier act than ticking one stage, so it
    // gets the heavier haptic.
    await HapticFeedback.mediumImpact();
    setState(() => _busy = true);
    try {
      await ref
          .read(taskDetailProvider(widget.taskId).notifier)
          .setStatus(done ? 'done' : 'in_progress');
      // The list behind this screen is showing the old progress until told.
      ref.read(myTasksProvider.notifier).refresh();
      if (mounted && done) {
        _say('Đã báo hoàn thành. Quản lý sẽ nhận thông báo.');
      }
    } on Object {
      if (mounted) _say('Chưa lưu được. Kiểm tra mạng rồi thử lại.');
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
    final source = await _pickSource();
    if (source == null) return;

    final photo = await ImagePicker().pickImage(
      source: source,
      imageQuality: 85,
    );
    if (photo == null) return;

    setState(() => _busy = true);
    try {
      await ref.read(tasksApiProvider).attach(widget.taskId, photo.path);
      await ref.read(taskDetailProvider(widget.taskId).notifier).refresh();
      if (mounted) _say('Đã đính kèm ảnh.');
    } on Object {
      if (mounted) _say('Chưa gửi được ảnh. Thử lại khi có mạng.');
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
          // Chụp đứng trước: ở xưởng thì phần lớn là chụp ngay tại chỗ, và
          // mục đầu tiên là mục ngón tay bẩn chạm trúng.
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

  void _say(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _SquareButton extends StatelessWidget {
  const _SquareButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: 52,
        height: 52,
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            padding: EdgeInsets.zero,
            side: BorderSide(color: scheme.outlineVariant),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(OmniRadius.md),
            ),
          ),
          // Never icon-only to a screen reader: the tooltip names it aloud.
          child: Icon(icon, color: scheme.onSurfaceVariant),
        ),
      ),
    );
  }
}
