import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../../core/error/app_exception.dart';
import '../../../../../design/tokens/tokens.dart';
import '../../../application/task_controller.dart';
import '../../../data/tasks_api.dart';

/// Thanh đáy của chi tiết việc, nay CHỈ còn nút máy ảnh.
///
/// Nút "Hoàn thành / Mở lại công việc" đã chuyển thành ô tích ở tiêu đề
/// (`TaskTitleRow`, Việc mới Task 8). Máy ảnh ở lại đây tới khi thẻ Tệp và ô
/// bình luận đáy (Task 9) có nút tải lên của chúng; khi đó thanh này bị bỏ.
class TaskActionBar extends ConsumerStatefulWidget {
  const TaskActionBar({
    super.key,
    required this.canAttach,
    required this.taskId,
  });

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
    if (!widget.canAttach) return const SizedBox.shrink();

    // `padding` (đã trừ phần bàn phím che), không phải `viewPadding`: bàn phím
    // mở thì thanh nằm sát nó, không để thêm một khoảng hở bằng thanh home.
    final bottom = math.max(8.0, MediaQuery.paddingOf(context).bottom);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 8, 16, bottom),
        child: Row(
          children: [_CameraButton(onTap: _busy ? null : _attachPhoto)],
        ),
      ),
    );
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
        failureText(error, 'Chưa gửi được ảnh. Thử lại khi có mạng.'),
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
