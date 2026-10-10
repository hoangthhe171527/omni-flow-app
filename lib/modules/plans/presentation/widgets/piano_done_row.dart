import 'package:flutter/material.dart';

import '../../../../design/components/components.dart';
import '../../../../design/tokens/tokens.dart';
import '../../domain/feed_entry.dart';
import 'completion_row.dart' show feedMeta;

/// Một cây đàn đã ra khỏi xưởng.
///
/// Nổi bật hơn dòng công đoạn vì nó là thứ ĐẾM ĐƯỢC: mỗi dòng này là một đơn vị
/// trên bảng thưởng cuối tháng (§B4). Nổi bằng nhãn "{TÊN} ĐÃ XONG" màu chính
/// phía trên tên việc — không bằng một khối tô màu, vì thẻ bọc cả ngày đã là
/// khối rồi.
class PianoDoneRow extends StatelessWidget {
  const PianoDoneRow({super.key, required this.entry, this.onTap});

  final FeedEntry entry;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final who = entry.userName ?? 'Ai đó';

    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              OmniAvatar(name: who, imageUrl: entry.userAvatar, size: 28),
              const SizedBox(width: OmniSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${who.toUpperCase()} ĐÃ XONG',
                      style: text.labelSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                        color: scheme.primary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      entry.taskTitle,
                      style: text.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      feedMeta(entry),
                      style: text.labelSmall?.copyWith(
                        fontWeight: FontWeight.w400,
                        color: scheme.onSurfaceVariant,
                        fontFeatures: OmniType.tabular,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
