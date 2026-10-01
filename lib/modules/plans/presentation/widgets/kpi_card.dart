import 'package:flutter/material.dart';

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
    this.previousDelivered,
    this.onPrevMonth,
    this.onNextMonth,
    this.onConfigure,
  });

  final WorkshopKpi kpi;

  /// Tháng đang xem. Chỉ năm và tháng có nghĩa.
  final DateTime month;

  /// Số việc xong của tháng liền trước, để con số có một mốc so sánh.
  ///
  /// null khi chưa về hoặc lượt gọi hỏng — lúc đó KHÔNG có dòng so sánh. So
  /// với một con số không có là bịa ra một xu hướng.
  final int? previousDelivered;

  final VoidCallback? onPrevMonth;

  /// null nghĩa là KHÔNG đi tới được nữa — tức là đang ở tháng hiện tại.
  ///
  /// Một tín hiệu chứ không phải hai: mũi tên tắt và "đang ở tháng này" luôn
  /// là cùng một sự thật, và tách chúng ra là tạo chỗ cho hai cờ nói ngược
  /// nhau. Thẻ đọc nó để biết nên viết "còn bao xa tới mốc" (tháng đang chạy)
  /// hay "thiếu bao nhiêu so với mốc" (tháng đã khép).
  final VoidCallback? onNextMonth;

  /// Mở chỗ đánh dấu nhóm việc đích. Chỉ dùng khi KPI chưa cấu hình.
  final VoidCallback? onConfigure;

  bool get _isCurrentMonth => onNextMonth == null;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    // Chưa dự án nào đánh dấu cột đích. Một số 0 ở đây trông y hệt "tháng này
    // chưa xong cây nào", nên vẫn phải nói ra là cái nào.
    //
    // Nhưng MỘT DÒNG, không phải một khối. Bản trước dựng nguyên một thẻ cao
    // bằng thẻ KPI thật, đứng ở đầu màn Dòng việc — tức là chiếm đúng chỗ dễ
    // thấy nhất của ngày để nói một điều người thợ không làm gì được và người
    // quản đốc chỉ cần đọc một lần. Chỗ đó thuộc về việc xưởng vừa làm xong.
    //
    // Không có thanh chọn tháng ở nhánh này: chưa cấu hình thì mọi tháng đều
    // ra 0, và ba mũi tên qua lại giữa các số 0 chỉ tốn chỗ.
    if (!kpi.isConfigured) {
      return InkWell(
        onTap: onConfigure,
        borderRadius: OmniRadius.smAll,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: OmniSpacing.sm,
            vertical: OmniSpacing.sm,
          ),
          child: Row(
            children: [
              Icon(
                Icons.flag_outlined,
                size: OmniIconSize.sm,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: OmniSpacing.sm),
              Expanded(
                child: Text(
                  'Đánh dấu nhóm việc đích',
                  style: text.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: OmniIconSize.sm,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      );
    }

    return _Shell(
      builder: (context) {
        final scheme = Theme.of(context).colorScheme;
        final text = Theme.of(context).textTheme;

        return Column(
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
                  style: OmniType.moneyHero.copyWith(
                    fontSize: OmniType.moneyHero.fontSize! * 52 / 28,
                    fontWeight: FontWeight.w600,
                    height: 1,
                    letterSpacing: -1.5,
                    color: scheme.primary,
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
                  // Vàng chữ mực: mốc thưởng đã đạt là tin vui duy nhất trên thẻ.
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: const BoxDecoration(
                      color: OmniColors.sun,
                      borderRadius: OmniRadius.pillAll,
                    ),
                    child: Text(
                      'Đã đạt ${kpi.reachedBonus} triệu',
                      style: OmniType.micro.copyWith(
                        fontWeight: FontWeight.w600,
                        color: OmniColors.sunForeground,
                      ),
                    ),
                  ),
              ],
            ),
            if (previousDelivered case final int previous) ...[
              const SizedBox(height: OmniSpacing.xs),
              _Trend(
                delta: kpi.delivered - previous,
                previousMonth: DateTime(month.year, month.month - 1),
              ),
            ],
            const SizedBox(height: OmniSpacing.lg),
            // Không có mốc nào thì không có gì để chạy tới — một thanh đầy 100%
            // ở đây là một lời khen bịa ra.
            if (kpi.tiers.isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(OmniRadius.chip / 2),
                child: LinearProgressIndicator(
                  value: kpi.progressToNext,
                  minHeight: 10,
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
        );
      },
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
      //
      // Chữ NHỎ: câu này dành cho người quản trị đọc một lần, con số dành cho
      // cả xưởng đọc mỗi ngày. Cùng cỡ với dòng mốc thưởng thì nó tranh mắt
      // với thứ thẻ này sinh ra để nói.
      return Text(
        'Workspace chưa khai bảng mốc thưởng.',
        style: text.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
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

/// "+6 so với tháng 8" — con số có một mốc để đọc là nhiều hay ít.
///
/// Hướng đi nằm ở BIỂU TƯỢNG và dấu, không ở màu: đỏ/xanh ở đây vừa là màu
/// thương hiệu thứ hai (cùng lỗi đã sửa ở nút hoàn thành) vừa vô hình với
/// người mù màu lục-đỏ. Một dòng, cỡ nhỏ, cùng màu với ngữ cảnh — nó bổ nghĩa
/// cho con số, không phải một con số thứ hai.
class _Trend extends StatelessWidget {
  const _Trend({required this.delta, required this.previousMonth});

  final int delta;
  final DateTime previousMonth;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final month = 'tháng ${previousMonth.month}';

    final (icon, label) = switch (delta) {
      > 0 => (Icons.trending_up_rounded, '+$delta so với $month'),
      // Dấu trừ thật (U+2212), không phải gạch nối: cùng bề rộng với dấu
      // cộng nên hai dòng của hai tháng thẳng hàng nhau.
      < 0 => (Icons.trending_down_rounded, '−${-delta} so với $month'),
      _ => (Icons.trending_flat_rounded, 'Bằng $month'),
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: OmniIconSize.sm, color: scheme.onSurfaceVariant),
        const SizedBox(width: OmniSpacing.xs),
        Text(
          label,
          style: text.labelSmall?.copyWith(
            color: scheme.onSurfaceVariant,
            fontFeatures: OmniType.tabular,
          ),
        ),
      ],
    );
  }
}

/// Thẻ MỰC của Dòng việc (`MTimeline.dc.html`): bo 22, một vòng quỹ đạo mảnh
/// ở góc, số lớn quỹ đạo sáng.
///
/// Nội dung dựng dưới một Theme riêng cho nền mực — chữ chính trắng, chữ phụ
/// xám xanh, màu chính là quỹ đạo sáng, rãnh thanh tiến độ là mực sáng hơn
/// một bậc — nên các mảnh con (thanh tháng, mốc thưởng, xu hướng) đọc màu từ
/// theme như bình thường mà vẫn đúng trên nền tối, không phải tô tay từng chỗ.
class _Shell extends StatelessWidget {
  const _Shell({required this.builder});

  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final ink = theme.copyWith(
      colorScheme: theme.colorScheme.copyWith(
        surface: OmniColors.ink,
        onSurface: Colors.white,
        onSurfaceVariant: OmniColors.inkMutedForeground,
        primary: OmniColors.orbit,
        surfaceContainerHighest: OmniColors.inkRaised,
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          backgroundColor: OmniColors.inkRaised,
          foregroundColor: Colors.white,
          disabledBackgroundColor: OmniColors.inkRaised.withValues(alpha: 0.4),
          disabledForegroundColor: Colors.white.withValues(alpha: 0.4),
          fixedSize: const Size.square(36),
          minimumSize: const Size.square(36),
          shape: const RoundedRectangleBorder(borderRadius: OmniRadius.smAll),
        ),
      ),
    );

    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: dark ? OmniColors.darkMuted : OmniColors.ink,
        borderRadius: const BorderRadius.all(Radius.circular(22)),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -60,
            top: -60,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: OmniColors.inkLine, width: 1.5),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Theme(
              data: ink,
              child: Builder(builder: builder),
            ),
          ),
        ],
      ),
    );
  }
}
