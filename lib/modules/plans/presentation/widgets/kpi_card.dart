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
                'Chưa có kế hoạch nào đánh dấu nhóm việc đích, nên chưa đếm '
                'được việc nào hoàn thành. Đánh dấu trong phần nhóm việc của '
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
                'việc xong tháng này',
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
          // Không có mốc nào thì không có gì để chạy tới — một thanh đầy 100%
          // ở đây là một lời khen bịa ra.
          if (kpi.tiers.isNotEmpty) ...[
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
          ],
          _Milestone(kpi: kpi),
          // Số lần làm lại (§B3). Chữ nhỏ, không tô đỏ, không kèm tên ai: nó
          // là thông tin để cải thiện chứ không phải một lời buộc tội. Ẩn khi
          // bằng 0 thay vì khoe một số 0.
          if (kpi.rework > 0) ...[
            const SizedBox(height: OmniSpacing.sm),
            Text(
              '${kpi.rework} lần phải làm lại trong tháng',
              style: text.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontFeatures: OmniType.tabular,
              ),
            ),
          ],
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

    if (kpi.tiers.isEmpty) {
      // Workspace chưa khai bảng mốc thưởng. `nextTier` cũng null lúc này, nên
      // nhánh dưới sẽ chúc mừng một xưởng chưa ai nhập bảng thưởng — hai
      // chuyện khác hẳn nhau mà nhìn từ `nextTier` thì giống hệt.
      //
      // Trước đây không xảy ra vì bảng nằm trong config của bản triển khai và
      // luôn có sẵn. Từ khi nó là cấu hình của từng workspace, đây là trạng
      // thái bình thường của mọi workspace mới.
      return Text(
        'Workspace chưa khai bảng mốc thưởng.',
        style: text.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
      );
    }

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
            'Còn ${next.remaining} việc tới mốc ${next.count} — '
            'thưởng ${next.bonus} triệu',
            style: text.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
        if (pace != null) ...[
          const SizedBox(width: OmniSpacing.sm),
          Text(
            // Một chữ số thập phân: "0.5 cây/ngày" đọc được, "0.4545…" thì
            // không, và làm tròn lên thành 1 là nói dối về nhịp cần thiết.
            '${pace.toStringAsFixed(1)} việc/ngày · còn ${kpi.daysLeft} ngày',
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
