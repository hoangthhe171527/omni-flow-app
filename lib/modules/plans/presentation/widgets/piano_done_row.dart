import 'package:flutter/material.dart';

import '../../../../core/utils/formatters.dart';
import '../../../../design/tokens/tokens.dart';
import '../../domain/feed_entry.dart';

/// Một cây đàn đã ra khỏi xưởng.
///
/// Nổi bật hơn dòng công đoạn vì nó là thứ ĐẾM ĐƯỢC: mỗi dòng này là một đơn vị
/// trên bảng thưởng cuối tháng (§B4). Một ngày có mười công đoạn xong và hai
/// cây xong thì hai dòng đó phải tìm thấy được khi lướt nhanh.
class PianoDoneRow extends StatelessWidget {
  const PianoDoneRow({super.key, required this.entry, this.onTap});

  final FeedEntry entry;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: OmniSpacing.sm),
      child: Material(
        color: scheme.primaryContainer,
        borderRadius: OmniRadius.mdAll,
        child: InkWell(
          onTap: onTap,
          borderRadius: OmniRadius.mdAll,
          child: Padding(
            padding: const EdgeInsets.all(OmniSpacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.verified_rounded,
                  size: OmniIconSize.md,
                  color: scheme.onPrimaryContainer,
                ),
                const SizedBox(width: OmniSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${entry.taskTitle} ĐÃ XONG',
                        style: text.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: scheme.onPrimaryContainer,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (entry.planName != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          entry.planName!,
                          style: text.labelSmall?.copyWith(
                            color: scheme.onPrimaryContainer,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: OmniSpacing.sm),
                Text(
                  Formatters.time(entry.at),
                  style: text.labelSmall?.copyWith(
                    color: scheme.onPrimaryContainer,
                    fontFeatures: OmniType.tabular,
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
