import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../../design/platform/omni_motion_scope.dart';
import '../../../../../design/tokens/tokens.dart';
import '../../../domain/task.dart';

/// Thẻ tệp đính kèm (`TaskDetail.dc.html`): 3 ô vuông bo 4 — ba tệp đầu tiên,
/// và "+n" ở ô thứ ba khi có hơn 3. Tiêu đề "TỆP ĐÍNH KÈM (n)" do
/// `ScoreAndFilesRow` đặt ngoài thẻ.
///
/// Hiện cho MỌI người đọc được việc, không gắn với quyền đính kèm: người thợ
/// bị trả việc về cần nhìn lại tấm ảnh chỗ lỗi, kể cả khi họ không gửi thêm
/// ảnh mới. Trước đây app gửi ảnh lên rồi không xem lại được ở đâu cả.
///
/// Chạm "+n" mở danh sách ĐỦ mọi tệp: hàng cuộn ngang cũ cho thấy tất cả, nên
/// ba ô mà không có lối vào phần còn lại là mất khả năng.
class TaskAttachments extends StatelessWidget {
  const TaskAttachments({super.key, required this.attachments});

  final List<TaskAttachment> attachments;

  static const _visible = 3;
  static const _gap = 6.0;
  static const _maxTile = 96.0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: attachments.isEmpty
            ? ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Chưa có tệp',
                    style: OmniType.micro.copyWith(
                      color: OmniColors.byBrightness(
                        context,
                        OmniColors.mutedForeground,
                        scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              )
            : LayoutBuilder(
                builder: (context, box) {
                  // Sàn 44: ô nhỏ hơn không chạm được. Không đủ chỗ cho 3 ô 44
                  // thì hàng cuộn ngang.
                  final tile = ((box.maxWidth - 2 * _gap) / _visible).clamp(
                    44.0,
                    _maxTile,
                  );
                  final extra = attachments.length - _visible;

                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (
                          var i = 0;
                          i < attachments.length && i < _visible;
                          i++
                        )
                          Padding(
                            padding: EdgeInsets.only(
                              right: i < _visible - 1 ? _gap : 0,
                            ),
                            child: AttachmentThumb(
                              attachment: attachments[i],
                              size: tile,
                              overflow: i == _visible - 1 && extra > 0
                                  ? extra
                                  : 0,
                              onOverflow: () => _showAll(context, attachments),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }

  /// Mọi tệp, ô 96, trong một bảng đáy.
  static Future<void> _showAll(
    BuildContext context,
    List<TaskAttachment> all,
  ) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final a in all) AttachmentThumb(attachment: a, size: _maxTile),
          ],
        ),
      ),
    ),
  );
}

/// Một ô vuông: ảnh thì hiện chính nó, tệp khác thì hiện tên.
class AttachmentThumb extends StatelessWidget {
  const AttachmentThumb({
    super.key,
    required this.attachment,
    required this.size,
    this.overflow = 0,
    this.onOverflow,
  });

  final TaskAttachment attachment;

  /// Cạnh ô, dp. Cũng là cỡ giải mã (nhân tỉ lệ điểm ảnh).
  final double size;

  /// > 0: ô này mang "+n" và chạm vào là mở danh sách đủ, không mở tệp.
  final int overflow;
  final VoidCallback? onOverflow;

  /// Mở bản đầy đủ ra ngoài app, như module hộp thư vẫn làm với tệp đính kèm.
  /// Ô nhỏ đủ để nhận ra là tấm nào, không đủ để soi một vết xước.
  Future<void> _open() async {
    final uri = Uri.tryParse(attachment.url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final more = overflow > 0;

    return Semantics(
      button: true,
      // Ảnh không có chữ nào nên nhãn là TÊN tệp; tệp khác đã có tên trong ô.
      label: more
          ? 'Xem thêm $overflow tệp'
          : (attachment.isImage ? attachment.name : null),
      child: SizedBox(
        width: size,
        height: size,
        child: Material(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(4),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: more ? onOverflow : _open,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (attachment.isImage)
                  // Bộ nhớ đệm đĩa + giải mã ở đúng cỡ vẽ: ảnh chụp công đoạn
                  // là 3000×4000, và giải mã cỡ gốc cho một ô nhỏ là 48 MB
                  // bitmap mỗi tấm — ba tấm là màn chi tiết giật khi cuộn. Chỉ
                  // khoá chiều rộng để ảnh 3:4 giữ tỉ lệ rồi mới được `cover`
                  // cắt.
                  CachedNetworkImage(
                    imageUrl: attachment.url,
                    fit: BoxFit.cover,
                    memCacheWidth:
                        (size * MediaQuery.devicePixelRatioOf(context)).round(),
                    fadeInDuration: OmniMotion.of(context).fast,
                    // Mất mạng hay ảnh hỏng thì rơi về cái tên, chứ không để
                    // lại một ô xám không nói gì.
                    errorWidget: (_, _, _) =>
                        _AttachmentName(name: attachment.name, size: size),
                  )
                else
                  _AttachmentName(name: attachment.name, size: size),
                if (more)
                  ColoredBox(
                    color: Colors.black54,
                    child: Center(
                      child: Text(
                        '+$overflow',
                        style: OmniType.bodyStrong.copyWith(
                          color: Colors.white,
                        ),
                      ),
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

class _AttachmentName extends StatelessWidget {
  const _AttachmentName({required this.name, required this.size});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Ô nhỏ (≈ 48): một dòng dưới biểu tượng nhỏ; ô 96: hai dòng.
    final roomy = size >= 80;

    return ClipRect(
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.insert_drive_file_outlined,
              size: roomy ? OmniIconSize.lg : 18,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(height: 2),
            Text(
              name,
              maxLines: roomy ? 2 : 1,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: OmniType.micro,
            ),
          ],
        ),
      ),
    );
  }
}
