import 'package:flutter/material.dart';

import '../../../../design/components/components.dart';
import '../../../../design/tokens/tokens.dart';
import '../../domain/workshop_kpi.dart';

/// "Tháng này xong bao nhiêu cây, còn bao xa tới mốc thưởng."
///
/// §B4 của `TNP_PIANO_WORKSHOP_FLOW.md`: thẻ này thay hoàn toàn cái bảng đếm
/// tay trên Zalo, và cuối tháng chủ xưởng đọc nó để trao thưởng.
///
/// Con số dẫn, mọi thứ khác là ngữ cảnh của nó. Thưởng tính theo TEAM (§1),
/// nên không có tên ai trên thẻ này — thêm một bảng xếp hạng cá nhân là đổi
/// cách xưởng làm việc, và tài liệu nói rõ họ không làm vậy.
class KpiCard extends StatelessWidget {
  const KpiCard({super.key, required this.kpi});

  final WorkshopKpi kpi;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    // Chưa kế hoạch nào đánh dấu cột đích. Một số 0 ở đây trông y hệt "tháng
    // này chưa xong cây nào", nên thẻ phải nói ra là cái nào — và nói luôn
    // cách sửa.
    if (!kpi.isConfigured) {
      return _Shell(
        child: Row(
          children: [
            Icon(
              Icons.info_outline_rounded,
              size: OmniIconSize.lg,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(width: OmniSpacing.md),
            Expanded(
              child: Text(
                'Chưa có kế hoạch nào đánh dấu công đoạn đích, nên chưa đếm '
                'được cây nào hoàn thành. Đánh dấu trong phần nhóm việc của '
                'kế hoạch.',
                style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      );
    }

    return _Shell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${kpi.delivered}',
                style: text.displaySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: scheme.primary,
                  fontFeatures: OmniType.tabular,
                ),
              ),
              const SizedBox(width: OmniSpacing.sm),
              Text(
                'cây xong tháng này',
                style: text.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              if (kpi.reachedBonus > 0)
                OmniStatusChip(
                  icon: Icons.emoji_events_outlined,
                  label: 'Đã đạt ${kpi.reachedBonus} triệu',
                  tone: OmniTone.success,
                ),
            ],
          ),
          const SizedBox(height: OmniSpacing.lg),
          ClipRRect(
            borderRadius: BorderRadius.circular(OmniRadius.chip / 2),
            child: LinearProgressIndicator(
              value: kpi.progressToNext,
              minHeight: 8,
              backgroundColor: scheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation(scheme.primary),
            ),
          ),
          const SizedBox(height: OmniSpacing.sm),
          _Milestone(kpi: kpi),
        ],
      ),
    );
  }
}

/// Dòng dưới thanh tiến độ: còn bao xa, và cần nhịp nào để kịp.
class _Milestone extends StatelessWidget {
  const _Milestone({required this.kpi});

  final WorkshopKpi kpi;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final next = kpi.nextTier;

    if (next == null) {
      // Vượt mốc cao nhất là tin tốt. Một ô trống ở đây đọc như lỗi tải.
      return Text(
        'Đã đạt mốc cao nhất của tháng.',
        style: text.labelMedium?.copyWith(color: scheme.primary),
      );
    }

    final pace = kpi.perDayNeeded;

    return Row(
      children: [
        Expanded(
          child: Text(
            'Còn ${next.remaining} cây tới mốc ${next.count} — '
            'thưởng ${next.bonus} triệu',
            style: text.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
        if (pace != null) ...[
          const SizedBox(width: OmniSpacing.sm),
          Text(
            // Một chữ số thập phân: "0.5 cây/ngày" đọc được, "0.4545…" thì
            // không, và làm tròn lên thành 1 là nói dối về nhịp cần thiết.
            '${pace.toStringAsFixed(1)} cây/ngày · còn ${kpi.daysLeft} ngày',
            style: text.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontFeatures: OmniType.tabular,
            ),
          ),
        ],
      ],
    );
  }
}

class _Shell extends StatelessWidget {
  const _Shell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(OmniSpacing.lg),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: OmniRadius.lgAll,
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: child,
    );
  }
}
