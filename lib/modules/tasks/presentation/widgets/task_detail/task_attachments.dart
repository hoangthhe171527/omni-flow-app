import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../../design/platform/omni_motion_scope.dart';
import '../../../../../design/tokens/tokens.dart';
import '../../../domain/task.dart';

/// Ảnh và tệp đã đính trên công việc.
///
/// Hiện cho MỌI người đọc được việc, không gắn với quyền đính kèm: người thợ
/// bị trả việc về cần nhìn lại tấm ảnh chỗ lỗi, kể cả khi họ không gửi thêm
/// ảnh mới. Trước đây app gửi ảnh lên rồi không xem lại được ở đâu cả.
class TaskAttachments extends StatelessWidget {
  const TaskAttachments({super.key, required this.attachments});

  final List<TaskAttachment> attachments;

  @override
  Widget build(BuildContext context) {
    // Chưa có tệp nào thì không chiếm chỗ: mỗi khối rỗng đẩy nút "Hoàn thành"
    // xa thêm một quãng trên màn hình cầm một tay giữa xưởng.
    if (attachments.isEmpty) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: OmniSpacing.sm),
      color: scheme.surface,
      padding: const EdgeInsets.all(OmniSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.attachment_outlined,
                size: OmniIconSize.sm,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: OmniSpacing.xs),
              Text(
                'Tệp đính kèm (${attachments.length})',
                style: OmniType.overline.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: OmniSpacing.sm),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final attachment in attachments)
                  Padding(
                    padding: const EdgeInsets.only(right: OmniSpacing.sm),
                    child: _AttachmentThumb(attachment: attachment),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Một ô 96dp: ảnh thì hiện chính nó, tệp khác thì hiện tên.
class _AttachmentThumb extends StatelessWidget {
  const _AttachmentThumb({required this.attachment});

  final TaskAttachment attachment;

  /// Cạnh ô, dp. Cũng là cỡ giải mã (nhân tỉ lệ điểm ảnh).
  static const double _size = 96;

  /// Mở bản đầy đủ ra ngoài app, như module hộp thư vẫn làm với tệp đính kèm.
  /// Ô 96dp đủ để nhận ra là tấm nào, không đủ để soi một vết xước.
  Future<void> _open() async {
    final uri = Uri.tryParse(attachment.url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: _size,
      height: _size,
      child: Material(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(OmniRadius.sm),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: _open,
          child: attachment.isImage
              // Bộ nhớ đệm đĩa + giải mã ở đúng cỡ vẽ: ảnh chụp công đoạn là
              // 3000×4000, và giải mã cỡ gốc cho một ô 96dp là 48 MB bitmap
              // mỗi tấm — ba tấm là màn chi tiết giật khi cuộn. Chỉ khoá
              // chiều rộng để ảnh 3:4 giữ tỉ lệ rồi mới được `cover` cắt.
              ? CachedNetworkImage(
                  imageUrl: attachment.url,
                  fit: BoxFit.cover,
                  memCacheWidth:
                      (_size * MediaQuery.devicePixelRatioOf(context)).round(),
                  fadeInDuration: OmniMotion.of(context).fast,
                  // Mất mạng hay ảnh hỏng thì rơi về cái tên, chứ không để lại
                  // một ô xám không nói gì.
                  errorWidget: (_, _, _) =>
                      _AttachmentName(name: attachment.name),
                )
              : _AttachmentName(name: attachment.name),
        ),
      ),
    );
  }
}

class _AttachmentName extends StatelessWidget {
  const _AttachmentName({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(OmniSpacing.sm),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.insert_drive_file_outlined,
            size: OmniIconSize.lg,
            color: scheme.onSurfaceVariant,
          ),
          const SizedBox(height: OmniSpacing.xs),
          Text(
            name,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: OmniType.micro,
          ),
        ],
      ),
    );
  }
}
