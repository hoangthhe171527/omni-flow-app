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
  const KpiCard({
    super.key,
    required this.kpi,
    required this.month,
    this.onPrevMonth,
    this.onNextMonth,
  });

  final WorkshopKpi kpi;

  /// Tháng đang xem. Chỉ năm và tháng có nghĩa.
  final DateTime month;

  final VoidCallback? onPrevMonth;

  /// null nghĩa là KHÔNG đi tới được nữa — tức là đang ở tháng hiện tại.
  ///
  /// Một tín hiệu chứ không phải hai: mũi tên tắt và "đang ở tháng này" luôn
  /// là cùng một sự thật, và tách chúng ra là tạo chỗ cho hai cờ nói ngược
  /// nhau. Thẻ đọc nó để biết nên viết "còn bao xa tới mốc" (tháng đang chạy)
  /// hay "thiếu bao nhiêu so với mốc" (tháng đã khép).
  final VoidCallback? onNextMonth;

  bool get _isCurrentMonth => onNextMonth == null;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    // Chưa kế hoạch nào đánh dấu cột đích. Một số 0 ở đây trông y hệt "tháng
    // này chưa xong cây nào", nên thẻ phải nói ra là cái nào — và nói luôn
    // cách sửa.
    if (!kpi.isConfigured) {
      return _Shell(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thanh chọn tháng ở CẢ nhánh này: lùi về một tháng đã cấu hình
            // xong là cách nhanh nhất để thấy con số đáng lẽ trông ra sao.
            _MonthBar(month: month, onPrev: onPrevMonth, onNext: onNextMonth),
            const SizedBox(height: OmniSpacing.md),
            Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: OmniIconSize.lg,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: OmniSpacing.md),
                Expanded(
                  child: Text(
                    'Chưa có kế hoạch nào đánh dấu nhóm việc đích, nên chưa '
                    'đếm được việc nào hoàn thành. Đánh dấu trong phần nhóm '
                    'việc của kế hoạch.',
                    style: text.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return _Shell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MonthBar(month: month, onPrev: onPrevMonth, onNext: onNextMonth),
          const SizedBox(height: OmniSpacing.sm),
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
                // "trong tháng", không phải "tháng này": thanh ngay trên đã
                // nói là tháng nào, và từ khi lùi được về tháng trước thì
                // "tháng này" là một khẳng định sai.
                'việc xong trong tháng',
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
          _Milestone(kpi: kpi, isCurrentMonth: _isCurrentMonth),
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

/// Chọn tháng: ‹ Tháng 9/2026 ›
///
/// Cuối tháng chủ xưởng đọc con số để trao thưởng (§B4). Nhưng ngày mùng 1
/// con số đã về 0, và tháng vừa khép lại là thứ không còn xem được ở đâu cả —
/// nên số để trả thưởng phải đọc đúng trong ngày cuối cùng, hoặc chép tay ra
/// chỗ khác. API nhận `?month=` từ lâu; app thì chưa từng gửi.
///
/// Không đi tới TƯƠNG LAI: một tháng chưa tới luôn có `delivered = 0`, và một
/// số 0 ở đây trông y hệt "tháng này chưa ai xong cây nào".
class _MonthBar extends StatelessWidget {
  const _MonthBar({required this.month, this.onPrev, this.onNext});

  final DateTime month;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        IconButton(
          onPressed: onPrev,
          tooltip: 'Tháng trước',
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        Expanded(
          child: Text(
            'Tháng ${month.month}/${month.year}',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: scheme.onSurfaceVariant,
              fontFeatures: OmniType.tabular,
            ),
          ),
        ),
        IconButton(
          // null làm nút MỜ đi chứ không biến mất: một mũi tên biến mất làm
          // hàng nút nhảy chỗ, và người dùng mất mốc để biết mình đang ở đâu.
          onPressed: onNext,
          tooltip: 'Tháng sau',
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
    );
  }
}

/// Dòng dưới thanh tiến độ: còn bao xa, và cần nhịp nào để kịp.
class _Milestone extends StatelessWidget {
  const _Milestone({required this.kpi, required this.isCurrentMonth});

  final WorkshopKpi kpi;

  /// Tháng đã khép thì không còn gì để "chạy tới".
  final bool isCurrentMonth;

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
            // Tháng đã khép thì không còn gì để "chạy tới": "còn 5 việc tới
            // mốc 35" đọc như một lời động viên cho một tháng đã hết, và
            // người đọc nó là người sắp trả thưởng.
            isCurrentMonth
                ? 'Còn ${next.remaining} việc tới mốc ${next.count} — '
                      'thưởng ${next.bonus} triệu'
                : 'Thiếu ${next.remaining} việc so với mốc ${next.count} — '
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
