import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/media_url.dart';
import '../../../../design/components/components.dart';
import '../../../../design/platform/omni_motion_scope.dart';
import '../../../../design/tokens/tokens.dart';
import '../../domain/feed_entry.dart';

/// Một công đoạn vừa xong, kèm ảnh bằng chứng.
///
/// Ba thứ người đọc cần, theo đúng thứ tự mắt đi: AI, LÀM GÌ, và BẰNG CHỨNG.
/// Giờ nằm bên phải vì nó là thứ được đối chiếu chứ không phải thứ được đọc.
class CompletionRow extends StatelessWidget {
  const CompletionRow({super.key, required this.entry, this.onTap});

  final FeedEntry entry;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final who = entry.userName ?? 'Ai đó';

    return InkWell(
      onTap: onTap,
      borderRadius: OmniRadius.smAll,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: OmniSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            OmniAvatar(name: who, imageUrl: entry.userAvatar, size: 32),
            const SizedBox(width: OmniSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    // Tên người đứng trước hành động: "Hằng Ni đã xong Body
                    // ngoài" đọc như một câu, còn "đã xong Body ngoài — Hằng
                    // Ni" đọc như một bản ghi.
                    '$who ${entry.summary}',
                    style: text.bodyMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      entry.taskTitle,
                      if (entry.planName != null) entry.planName!,
                    ].join(' · '),
                    style: text.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (entry.photos.isNotEmpty) ...[
                    const SizedBox(height: OmniSpacing.sm),
                    _Photos(urls: entry.photos),
                  ],
                ],
              ),
            ),
            const SizedBox(width: OmniSpacing.sm),
            // Giờ TUYỆT ĐỐI, không phải "2 giờ trước": quản đốc đối chiếu dòng
            // này với ca làm và với lời thợ nói, và "09:35" là thứ so được.
            Text(
              Formatters.time(entry.at),
              style: text.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontFeatures: OmniType.tabular,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dải ảnh bằng chứng, cuộn ngang.
///
/// §B2: ảnh CHÍNH LÀ bằng chứng của công đoạn, nên bắt mở từng cây đàn ra để
/// xem là bỏ mất lý do người ta lướt màn này.
class _Photos extends StatelessWidget {
  const _Photos({required this.urls});

  static const double _size = 88;

  final List<String> urls;

  @override
  Widget build(BuildContext context) {
    // Giải mã ở ĐÚNG cỡ vẽ. Ảnh chụp từ điện thoại là 3000×4000, ô này 88dp:
    // giải mã cỡ gốc là 48 MB bitmap cho một ô, nhân với hai chục công đoạn
    // xong kèm ảnh của một buổi sáng. Chỉ khoá chiều rộng — đặt cả hai chiều
    // là bóp ảnh 3:4 thành hình vuông trước khi `cover` cắt.
    final decodeWidth = (_size * MediaQuery.devicePixelRatioOf(context))
        .round();
    final fade = OmniMotion.of(context).fast;

    return SizedBox(
      height: _size,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: urls.length,
        separatorBuilder: (_, _) => const SizedBox(width: OmniSpacing.sm),
        itemBuilder: (context, index) => ClipRRect(
          // Khoá theo URL: một ảnh hỏng bị errorWidget thay bằng ô giữ chỗ,
          // nên đếm theo widget ảnh cho ra số khác nhau tuỳ ảnh nào tải xong
          // trước. Khoá là thứ ổn định để nói "ô ảnh này CÓ trên màn hình".
          key: ValueKey('photo:${urls[index]}'),
          borderRadius: OmniRadius.smAll,
          // Bộ nhớ đệm ĐĨA: quản đốc mở dòng việc mỗi sáng, và cùng những tấm
          // ảnh đó không việc gì phải tải lại mỗi lần cuộn.
          child: CachedNetworkImage(
            imageUrl: resolveMediaUrl(urls[index]),
            width: _size,
            height: _size,
            fit: BoxFit.cover,
            memCacheWidth: decodeWidth,
            fadeInDuration: fade,
            fadeOutDuration: fade,
            placeholderFadeInDuration: Duration.zero,
            // Ô GIỮ CHỖ cùng cỡ trong lúc tải và khi hỏng, không phải ô 0dp.
            // Bản đầu trả `SizedBox.shrink()` cho ảnh hỏng: dải ảnh co lại rồi
            // giãn ra khi ảnh tới, và ngoài xưởng sóng yếu thì người đọc
            // không biết là CÓ ảnh đang chờ. Kích thước cố định là thứ giữ cho
            // bố cục không nhảy (CLS) — ảnh tới hay không, ô vẫn ở đó.
            placeholder: (_, _) => const _PhotoPlaceholder(),
            errorWidget: (_, _, _) => const _PhotoPlaceholder(broken: true),
          ),
        ),
      ),
    );
  }
}

/// Ô 88dp thay cho ảnh chưa tới (biểu tượng ảnh) hoặc hỏng (ảnh vỡ).
class _PhotoPlaceholder extends StatelessWidget {
  const _PhotoPlaceholder({this.broken = false});

  final bool broken;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: _Photos._size,
      height: _Photos._size,
      color: scheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Icon(
        broken ? Icons.broken_image_outlined : Icons.image_outlined,
        size: OmniIconSize.md,
        color: scheme.onSurfaceVariant,
      ),
    );
  }
}
