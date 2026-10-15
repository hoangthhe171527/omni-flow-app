import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../design/components/components.dart';
import '../../../../design/tokens/tokens.dart';
import '../../application/task_comments_controller.dart';
import '../../application/task_controller.dart';
import '../../domain/mention.dart';
import '../../domain/task.dart';
import 'task_detail/detail_card.dart';
import 'task_detail/menu_sheet.dart';
import 'task_detail/task_attachments.dart';

/// Thẻ Bình luận (`TaskDetail.dc.html`): avatar 30, bong bóng `#F5F7FA` bo 8,
/// "Tên · giờ", `@Tên` tô màu chính. Ô nhập nằm ở thanh đáy (`CommentBar`).
///
/// §B3: QC không đạt thì "@mention người phụ trách công đoạn lỗi, kéo về Đang
/// phục chế". Đây là chỗ duy nhất trong cả luồng ghi lại LÝ DO một cây bị trả
/// về — nhật ký hoạt động chỉ biết nó đã chuyển cột, không biết vì sao.
///
/// Bấm giữ bình luận của CHÍNH MÌNH (hoặc khi [canModerate], người giao việc)
/// hiện "Xoá bình luận" — đúng luật `DeleteTaskComment` của server: tác giả
/// hoặc quản lý kế hoạch.
class CommentSection extends ConsumerWidget {
  const CommentSection({
    super.key,
    required this.task,
    required this.taskId,
    this.myUserId,
    this.canWrite = false,
    this.canModerate = false,
  });

  final Task task;
  final String taskId;

  /// Người đang cầm máy: bình luận của họ xoá được.
  final String? myUserId;

  /// Có quyền ghi việc (server đòi `tasks.write` để xoá).
  final bool canWrite;

  /// Xoá được bình luận của người khác (người giao việc).
  final bool canModerate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Hạt giống là `task.comments`; provider cộng thêm những trang cũ đã xin.
    // Nó giữ mới nhất trước (thứ tự API); lật lại để đọc như trò chuyện: cũ
    // nhất trên, mới nhất dưới.
    final thread = ref.watch(taskCommentsProvider(taskId)).valueOrNull;
    final ready = thread != null && thread.seeded;
    final comments = ready ? thread.items.reversed.toList() : task.comments;

    return DetailCard(
      flat: true,
      children: [
        const DetailCardHeader(
          icon: Icons.chat_bubble_outline_rounded,
          title: 'Bình luận',
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Phần cũ đọc được NGAY ĐÂY: ở xưởng không ai mở web.
              if (ready && thread.hasMore)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: thread.loadingOlder
                        ? null
                        : () => _loadOlder(context, ref),
                    icon: thread.loadingOlder
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.history_rounded),
                    label: Text(
                      'Xem thêm ${thread.hiddenCount} bình luận cũ hơn',
                    ),
                  ),
                ),
              if (comments.isEmpty)
                Text(
                  'Chưa có bình luận',
                  style: OmniType.caption.copyWith(
                    color: detailSecondary(context),
                  ),
                ),
              for (var i = 0; i < comments.length; i++)
                Padding(
                  padding: EdgeInsets.only(top: i == 0 ? 0 : 10),
                  child: _Comment(
                    key: ValueKey('comment-${comments[i].id}'),
                    comment: comments[i],
                    onLongPress: _canDelete(comments[i])
                        ? () => _delete(context, ref, comments[i])
                        : null,
                    onFileLongPress: (file) => _canRemoveFile(comments[i], file)
                        ? () => _removeFile(context, ref, comments[i], file)
                        : null,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  bool _canDelete(TaskComment c) {
    if (!canWrite || c.id.isEmpty) return false;
    if (canModerate) return true;

    return myUserId != null && c.userId == myUserId;
  }

  /// Gỡ tệp kèm bình luận: người tải lên, hoặc người quản lý việc (server:
  /// `DeleteCommentAttachment`, người khác 403).
  bool _canRemoveFile(TaskComment c, TaskAttachment f) {
    if (!canWrite || c.id.isEmpty || f.id.isEmpty) return false;
    if (canModerate) return true;

    // Chỉ người tải lên (server so `uploaded_by`); không rõ thì không gỡ.
    return myUserId != null && f.userId == myUserId;
  }

  Future<void> _removeFile(
    BuildContext context,
    WidgetRef ref,
    TaskComment comment,
    TaskAttachment file,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final container = ProviderScope.containerOf(context);
    final remove = await showDetailMenuSheet<bool>(
      context,
      semanticsLabel: 'Tuỳ chọn tệp',
      title: file.name,
      groups: const [
        [
          DetailMenuItem(
            value: true,
            icon: Icons.delete_outline,
            label: 'Gỡ tệp',
            danger: true,
          ),
        ],
      ],
    );
    if (remove != true || !context.mounted) return;
    final confirmed = await showOmniConfirm(
      context: context,
      title: 'Gỡ tệp “${file.name}”?',
      message: 'Tệp sẽ bị gỡ khỏi bình luận và xoá hẳn.',
      confirmLabel: 'Gỡ tệp',
      destructive: true,
    );
    if (!confirmed) return;

    try {
      await container
          .read(taskDetailProvider(taskId).notifier)
          .deleteCommentAttachment(comment.id, file.id);
      container.invalidate(taskCommentsProvider(taskId));
      messenger.showSnackBar(const SnackBar(content: Text('Đã gỡ tệp.')));
    } on AppException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _loadOlder(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(taskCommentsProvider(taskId).notifier).loadOlder();
    } on AppException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } on Object {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Chưa tải được bình luận cũ. Thử lại khi có mạng.'),
        ),
      );
    }
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    TaskComment comment,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final container = ProviderScope.containerOf(context);
    final remove = await showDetailMenuSheet<bool>(
      context,
      semanticsLabel: 'Tuỳ chọn bình luận',
      groups: const [
        [
          DetailMenuItem(
            value: true,
            icon: Icons.delete_outline,
            label: 'Xoá bình luận',
            danger: true,
          ),
        ],
      ],
    );
    if (remove != true || !context.mounted) return;
    final confirmed = await showOmniConfirm(
      context: context,
      title: 'Xoá bình luận này?',
      message: 'Mọi người sẽ không còn thấy bình luận này.',
      confirmLabel: 'Xoá bình luận',
      destructive: true,
    );
    if (!confirmed) return;

    try {
      await container
          .read(taskDetailProvider(taskId).notifier)
          .deleteComment(comment.id);
      // Trang cũ đã xin giữ trong provider riêng: gieo lại từ bản mới.
      container.invalidate(taskCommentsProvider(taskId));
      messenger.showSnackBar(
        const SnackBar(content: Text('Đã xoá bình luận.')),
      );
    } on AppException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }
}

/// Giờ bình luận: `HH:mm` trong ngày, `dd/MM HH:mm` ngày khác (giờ VN).
String commentStamp(DateTime at, {DateTime? now}) {
  final sameDay = VnTime.day(at) == VnTime.today(now);
  final time = Formatters.time(at);

  return sameDay ? time : '${Formatters.dayMonth(at)} $time';
}

class _Comment extends StatelessWidget {
  const _Comment({
    super.key,
    required this.comment,
    this.onLongPress,
    this.onFileLongPress,
  });

  final TaskComment comment;
  final VoidCallback? onLongPress;

  /// Bấm giữ một tệp kèm; trả null = tệp đó không gỡ được.
  final VoidCallback? Function(TaskAttachment file)? onFileLongPress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final secondary = detailSecondary(context);
    // Màu chữ CHÍNH, đặt tường minh: thân bình luận — lý do một cây đàn bị
    // trả về — từng in mờ hơn cả tên người.
    final body = OmniType.bodySm.copyWith(height: 1.45);

    final bubble = Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: comment.author,
                  style: OmniType.micro.copyWith(
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
                if (comment.createdAt case final at?)
                  TextSpan(
                    text: ' · ${commentStamp(at)}',
                    style: OmniType.micro.copyWith(
                      fontWeight: FontWeight.w400,
                      color: secondary,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          // `@Tên` được nhắc tô màu chính, ngay trong câu. Style TƯỜNG MINH
          // trên từng đoạn: span ngoài mang màu phụ mặc định. Bình luận chỉ
          // có tệp thì không có dòng chữ.
          if (comment.body.trim().isNotEmpty)
            Text.rich(
              TextSpan(
                children: [
                  for (final part in Mentions.split(
                    comment.body,
                    comment.mentionedUserNames,
                  ))
                    TextSpan(
                      text: part.text,
                      style: part.isMention
                          ? body.copyWith(
                              color: scheme.primary,
                              fontWeight: FontWeight.w500,
                            )
                          : body.copyWith(color: scheme.onSurface),
                    ),
                ],
              ),
            ),
          // Bình luận từ web nhắc bằng nút, không có `@` trong chữ: dòng này là
          // kênh duy nhất báo cho người thợ biết họ được nhắc.
          if (comment.mentionedUserNames.where(
                (n) => !comment.body.contains('@$n'),
              )
              case final missing when missing.isNotEmpty) ...[
            const SizedBox(height: OmniSpacing.xs),
            Text(
              'Nhắc: ${missing.join(', ')}',
              style: OmniType.micro.copyWith(color: scheme.primary),
            ),
          ],
          // Ảnh / tệp gửi kèm: ô 72 bo 6 như thẻ Tệp; chạm mở bản đầy đủ.
          if (comment.attachments.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final file in comment.attachments)
                  AttachmentThumb(
                    key: ValueKey('comment-file-${file.id}'),
                    attachment: file,
                    size: 72,
                    radius: 6,
                    onLongPress: onFileLongPress?.call(file),
                  ),
              ],
            ),
          ],
        ],
      ),
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OmniAvatar(
          name: comment.author,
          imageUrl: comment.userAvatar,
          size: 30,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: onLongPress == null
              ? bubble
              : Material(
                  type: MaterialType.transparency,
                  child: InkWell(
                    onLongPress: onLongPress,
                    borderRadius: BorderRadius.circular(8),
                    child: bubble,
                  ),
                ),
        ),
      ],
    );
  }
}
