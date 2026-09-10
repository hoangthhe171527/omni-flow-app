import 'package:flutter/material.dart';

import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/media_url.dart';
import '../../../../design/components/components.dart';
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
    return SizedBox(
      height: _size,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: urls.length,
        separatorBuilder: (_, _) => const SizedBox(width: OmniSpacing.sm),
        itemBuilder: (context, index) => ClipRRect(
          // Khoá theo URL: một ảnh hỏng bị errorBuilder thay bằng ô rỗng, nên
          // đếm theo `Image` cho ra số khác nhau tuỳ ảnh nào tải xong trước.
          // Khoá là thứ ổn định để nói "ô ảnh này CÓ trên màn hình".
          key: ValueKey('photo:${urls[index]}'),
          borderRadius: OmniRadius.smAll,
          child: Image.network(
            resolveMediaUrl(urls[index]),
            width: _size,
            height: _size,
            fit: BoxFit.cover,
            // Một ảnh hỏng không được để lại ô vỡ giữa dòng chữ.
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}
