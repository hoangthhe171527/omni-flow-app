import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../../core/error/app_exception.dart';
import '../../../../../design/components/components.dart';
import '../../../../../design/tokens/tokens.dart';
import '../../../application/task_controller.dart';
import '../../../data/tasks_api.dart';
import '../../../domain/task.dart';
import 'detail_card.dart';
import 'menu_sheet.dart';
import 'task_attachments.dart';

/// Chọn một ảnh từ [source]; null = người dùng huỷ. Tiêm được để test không
/// gọi plugin máy ảnh.
typedef PhotoPicker = Future<String?> Function(ImageSource source);

Future<String?> _pickWithPlugin(ImageSource source) async =>
    (await ImagePicker().pickImage(source: source, imageQuality: 85))?.path;

/// Thẻ Tệp đính kèm (`TaskDetail.dc.html`): đầu thẻ có số tệp và nút "Tải tệp
/// lên" (chụp mới hoặc chọn ảnh có sẵn — năng lực của nút máy ảnh ở thanh đáy
/// cũ); thân là các ô 72 bo 6. Bấm giữ một ô: "Xoá tệp" (hỏi lại).
///
/// Hiện cho MỌI người đọc được việc: người thợ bị trả việc về cần nhìn lại
/// tấm ảnh chỗ lỗi, kể cả khi họ không gửi thêm ảnh mới.
class FilesCard extends ConsumerStatefulWidget {
  const FilesCard({
    super.key,
    required this.task,
    required this.canAttach,
    this.pickPhoto = _pickWithPlugin,
  });

  final Task task;

  /// Tải lên và xoá tệp (`taskAccess.canAttach`).
  final bool canAttach;
  final PhotoPicker pickPhoto;

  static const tile = 72.0;

  @override
  ConsumerState<FilesCard> createState() => _FilesCardState();
}

class _FilesCardState extends ConsumerState<FilesCard> {
  bool _busy = false;

  Task get task => widget.task;

  @override
  Widget build(BuildContext context) {
    final files = task.attachments;

    return DetailCard(
      flat: true,
      children: [
        DetailCardHeader(
          icon: Icons.attach_file_rounded,
          title: 'Tệp đính kèm',
          count: '${files.length}',
          actions: [
            if (widget.canAttach)
              _busy
                  ? const SizedBox.square(
                      dimension: 44,
                      child: Center(
                        child: SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    )
                  : Builder(
                      builder: (buttonContext) => DetailHeaderButton(
                        tooltip: 'Tải tệp lên',
                        icon: Icons.file_upload_outlined,
                        onPressed: () {
                          final box =
                              buttonContext.findRenderObject() as RenderBox?;
                          if (box == null || !box.hasSize) return;
                          _upload(box.localToGlobal(Offset.zero) & box.size);
                        },
                      ),
                    ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: files.isEmpty
              ? Text(
                  'Chưa có tệp',
                  style: OmniType.caption.copyWith(
                    color: detailSecondary(context),
                  ),
                )
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final file in files)
                      AttachmentThumb(
                        key: ValueKey('file-${file.id}'),
                        attachment: file,
                        size: FilesCard.tile,
                        radius: 6,
                        onLongPress: widget.canAttach
                            ? () => _fileOptions(file)
                            : null,
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  /// Đính ảnh: chụp mới, hoặc lấy ảnh đã có sẵn trong máy (người thợ thường
  /// đã chụp rồi — bắt chụp lại một cây đàn đã lắp xong thì không làm được).
  Future<void> _upload(Rect anchor) async {
    final messenger = ScaffoldMessenger.of(context);
    final source = await showDetailAnchoredMenu<ImageSource>(
      context,
      anchor: anchor,
      menuKey: const Key('task-attachment-source-menu'),
      semanticsLabel: 'Tải tệp lên',
      groups: const [
        [
          // Chụp đứng trước: ở xưởng phần lớn là chụp ngay tại chỗ.
          DetailMenuItem(
            value: ImageSource.camera,
            icon: Icons.photo_camera_outlined,
            label: 'Chụp ảnh',
          ),
          DetailMenuItem(
            value: ImageSource.gallery,
            icon: Icons.photo_library_outlined,
            label: 'Chọn ảnh có sẵn',
          ),
        ],
      ],
    );
    if (source == null) return;

    final path = await widget.pickPhoto(source);
    if (path == null || !mounted) return;

    setState(() => _busy = true);
    final container = ProviderScope.containerOf(context);
    try {
      await container.read(tasksApiProvider).attach(task.id, path);
      await container.read(taskDetailProvider(task.id).notifier).refresh();
      messenger.showSnackBar(const SnackBar(content: Text('Đã đính kèm ảnh.')));
    } on AppException catch (error) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            failureText(error, 'Chưa gửi được ảnh. Thử lại khi có mạng.'),
          ),
        ),
      );
    } on Object {
      messenger.showSnackBar(
        const SnackBar(content: Text('Chưa gửi được ảnh. Vui lòng thử lại.')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _fileOptions(TaskAttachment file) async {
    final messenger = ScaffoldMessenger.of(context);
    final controller = ref.read(taskDetailProvider(task.id).notifier);
    final remove = await showDetailMenuSheet<bool>(
      context,
      semanticsLabel: 'Tuỳ chọn tệp',
      title: file.name,
      groups: const [
        [
          DetailMenuItem(
            value: true,
            icon: Icons.delete_outline,
            label: 'Xoá tệp',
            danger: true,
          ),
        ],
      ],
    );
    if (remove != true || !mounted) return;

    final confirmed = await showOmniConfirm(
      context: context,
      title: 'Xoá tệp “${file.name}”?',
      message: 'Tệp sẽ bị gỡ khỏi việc “${task.title}”.',
      confirmLabel: 'Xoá tệp',
      destructive: true,
    );
    if (!confirmed) return;

    try {
      await controller.deleteAttachment(file.id);
      messenger.showSnackBar(const SnackBar(content: Text('Đã xoá tệp.')));
    } on AppException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    }
  }
}
