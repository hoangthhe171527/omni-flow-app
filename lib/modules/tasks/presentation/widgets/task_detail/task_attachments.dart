import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../../design/platform/omni_motion_scope.dart';
import '../../../../../design/tokens/tokens.dart';
import '../../../domain/task.dart';

/// Một ô vuông: ảnh thì hiện chính nó, tệp khác thì hiện tên.
class AttachmentThumb extends StatelessWidget {
  const AttachmentThumb({
    super.key,
    required this.attachment,
    required this.size,
    this.onLongPress,
    this.radius = 4,
  });

  final TaskAttachment attachment;

  /// Cạnh ô, dp. Cũng là cỡ giải mã (nhân tỉ lệ điểm ảnh).
  final double size;

  /// Bấm giữ (vd "Xoá tệp" ở màn Tệp của kế hoạch). null: không làm gì.
  final VoidCallback? onLongPress;

  /// Bo góc ô (thẻ Tệp của chi tiết việc: 6).
  final double radius;

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

    return Semantics(
      button: true,
      // Ảnh không có chữ nào nên nhãn là TÊN tệp; tệp khác đã có tên trong ô.
      label: attachment.isImage ? attachment.name : null,
      child: SizedBox(
        width: size,
        height: size,
        child: Material(
          // Ảnh: nền xám khi đang tải. Tệp khác: ô trắng viền (`TaskDetail.dc.html`).
          color: attachment.isImage
              ? scheme.surfaceContainerHighest
              : scheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
            side: attachment.isImage
                ? BorderSide.none
                : BorderSide(color: scheme.outlineVariant),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: _open,
            onLongPress: onLongPress,
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
    final pdf = name.toLowerCase().endsWith('.pdf');

    return ClipRect(
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              pdf
                  ? Icons.picture_as_pdf_outlined
                  : Icons.insert_drive_file_outlined,
              size: OmniIconSize.lg,
              color: pdf
                  ? OmniTaskTones.of(context).highPriority.foreground
                  : scheme.onSurfaceVariant,
            ),
            const SizedBox(height: 2),
            Text(
              name,
              maxLines: roomy ? 2 : 1,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: OmniType.micro.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
