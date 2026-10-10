import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../design/platform/omni_motion_scope.dart';
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
  /// null khi chưa về hoặc lượt gọi hỏng — lúc đó KHÔNG có chip so sánh. So
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
    // Nhưng MỘT DÒNG, không phải một khối: chỗ dễ thấy nhất của ngày thuộc về
    // việc xưởng vừa làm xong. Không có thanh chọn tháng ở nhánh này: chưa
    // cấu hình thì mọi tháng đều ra 0.
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

    final motion = OmniMotion.enabled(context);
    final hasTiers = kpi.tiers.isNotEmpty;

    // Số + thanh trượt vào khi đổi tháng (16px, 350ms); giảm chuyển động thì
    // đổi tức thì, không dựng AnimatedSwitcher.
    final figures = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _NumberRow(
          kpi: kpi,
          month: month,
          previousDelivered: previousDelivered,
        ),
        if (hasTiers) ...[
          const SizedBox(height: OmniSpacing.md),
          _TierBar(kpi: kpi),
          const SizedBox(height: OmniSpacing.sm),
          _PaceRow(kpi: kpi, isCurrentMonth: _isCurrentMonth),
        ],
      ],
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(OmniSpacing.md),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MonthBar(month: month, onPrev: onPrevMonth, onNext: onNextMonth),
          const SizedBox(height: OmniSpacing.md),
          if (motion)
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              transitionBuilder: (child, animation) => AnimatedBuilder(
                animation: animation,
                builder: (context, child) => Opacity(
                  opacity: animation.value,
                  child: Transform.translate(
                    offset: Offset(16 * (1 - animation.value), 0),
                    child: child,
                  ),
                ),
                child: child,
              ),
              child: KeyedSubtree(
                key: ValueKey(month.year * 12 + month.month),
                child: figures,
              ),
            )
          else
            figures,
          const SizedBox(height: OmniSpacing.md),
          if (hasTiers) ...[
            Divider(height: 1, thickness: 1, color: scheme.outlineVariant),
            const SizedBox(height: OmniSpacing.md),
          ],
          _BonusRow(kpi: kpi, isCurrentMonth: _isCurrentMonth),
        ],
      ),
    );
  }
}

/// Chọn tháng: [‹]  Tháng 9/2026  [›]
///
/// Cuối tháng chủ xưởng đọc con số để trao thưởng (§B4). Nhưng ngày mùng 1
/// con số đã về 0, và tháng vừa khép lại là thứ không còn xem được ở đâu cả.
///
/// Không đi tới TƯƠNG LAI: một tháng chưa tới luôn có `delivered = 0`, và một
/// số 0 ở đây trông y hệt "tháng này chưa ai xong cây nào". Nút mờ 0.35 chứ
/// không biến mất: một mũi tên biến mất làm hàng nút nhảy chỗ.
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
        _MonthButton(
          tooltip: 'Tháng trước',
          icon: Icons.chevron_left_rounded,
          onPressed: onPrev,
        ),
        Expanded(
          child: Text(
            'Tháng ${month.month}/${month.year}',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
              fontFeatures: OmniType.tabular,
            ),
          ),
        ),
        _MonthButton(
          tooltip: 'Tháng sau',
          icon: Icons.chevron_right_rounded,
          onPressed: onNext,
        ),
      ],
    );
  }
}

/// Nút 32 bo 6 viền mảnh, vùng chạm 44.
class _MonthButton extends StatelessWidget {
  const _MonthButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 44, height: 44),
      style: IconButton.styleFrom(
        // Giảm chuyển động: không gợn sóng khi chạm.
        splashFactory: OmniMotion.enabled(context)
            ? null
            : NoSplash.splashFactory,
        overlayColor: OmniMotion.enabled(context) ? null : Colors.transparent,
        animationDuration: OmniMotion.enabled(context) ? null : Duration.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        minimumSize: const Size(44, 44),
        fixedSize: const Size(44, 44),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      icon: Opacity(
        opacity: onPressed == null ? 0.35 : 1,
        child: Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: OmniColors.controlBorderOf(context)),
          ),
          child: Icon(icon, size: OmniIconSize.md, color: scheme.onSurface),
        ),
      ),
    );
  }
}

/// Số lớn + "việc xong trong tháng" + chip so sánh với tháng trước.
class _NumberRow extends StatelessWidget {
  const _NumberRow({
    required this.kpi,
    required this.month,
    required this.previousDelivered,
  });

  final WorkshopKpi kpi;
  final DateTime month;
  final int? previousDelivered;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final tones = OmniTaskTones.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          '${kpi.delivered}',
          style: text.displayLarge?.copyWith(
            fontWeight: FontWeight.w600,
            height: 1,
            color: scheme.onSurface,
            fontFeatures: OmniType.tabular,
          ),
        ),
        const SizedBox(width: OmniSpacing.sm),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(
              // "trong tháng", không phải "tháng này": thanh ngay trên đã nói
              // là tháng nào, và từ khi lùi được về tháng trước thì "tháng
              // này" là một khẳng định sai.
              'việc xong trong tháng',
              style: text.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        ),
        if (previousDelivered case final int previous)
          _DeltaChip(
            delta: kpi.delivered - previous,
            previousMonth: DateTime(month.year, month.month - 1),
            tone: kpi.delivered > previous ? tones.today : tones.upcoming,
          ),
      ],
    );
  }
}

/// "+6 so với tháng 8" — con số có một mốc để đọc là nhiều hay ít.
///
/// Hướng đi nằm ở BIỂU TƯỢNG và dấu, không chỉ ở màu: đỏ/xanh vô hình với
/// người mù màu lục-đỏ. Tăng dùng tông "hôm nay" (xanh ngọc), bằng/giảm dùng
/// tông trung tính — giảm KHÔNG tô đỏ.
class _DeltaChip extends StatelessWidget {
  const _DeltaChip({
    required this.delta,
    required this.previousMonth,
    required this.tone,
  });

  final int delta;
  final DateTime previousMonth;
  final OmniTaskTone tone;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final month = 'tháng ${previousMonth.month}';

    final (icon, label) = switch (delta) {
      > 0 => (Icons.trending_up_rounded, '+$delta so với $month'),
      // Dấu trừ thật (U+2212), cùng bề rộng với dấu cộng.
      < 0 => (Icons.trending_down_rounded, '−${-delta} so với $month'),
      _ => (Icons.trending_flat_rounded, 'Bằng $month'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: tone.background,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: OmniIconSize.sm, color: tone.foreground),
          const SizedBox(width: OmniSpacing.xs),
          Text(
            label,
            style: text.labelSmall?.copyWith(
              color: tone.foreground,
              fontFeatures: OmniType.tabular,
            ),
          ),
        ],
      ),
    );
  }
}

/// Thanh 8px: phần đạt = `delivered / mốc cao nhất`, vạch 2×14 tại mỗi mốc.
class _TierBar extends StatelessWidget {
  const _TierBar({required this.kpi});

  final WorkshopKpi kpi;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final motion = OmniMotion.enabled(context);

    return LayoutBuilder(
      builder: (context, c) {
        final maxTier = kpi.tiers.map((t) => t.count).reduce(math.max);
        final pct = (kpi.delivered / maxTier).clamp(0.0, 1.0);

        return SizedBox(
          height: 14,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: 3,
                height: 8,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: OmniColors.trackOf(context),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              AnimatedPositioned(
                duration: motion
                    ? const Duration(milliseconds: 600)
                    : Duration.zero,
                curve: const Cubic(.2, .8, .2, 1),
                left: 0,
                top: 3,
                height: 8,
                width: c.maxWidth * pct,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              for (final tier in kpi.tiers)
                Positioned(
                  key: ValueKey('kpi-tier-${tier.count}'),
                  left: (c.maxWidth * tier.count / maxTier - 1).clamp(
                    0.0,
                    c.maxWidth - 2,
                  ),
                  top: 0,
                  width: 2,
                  height: 14,
                  child: DecoratedBox(
                    key: const Key('kpi-tier-mark'),
                    decoration: BoxDecoration(
                      color: tier.count <= kpi.delivered
                          ? scheme.primary
                          : OmniColors.mutedBarOf(context),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Dưới thanh: nhịp cần thiết bên trái, mốc kế tiếp bên phải.
class _PaceRow extends StatelessWidget {
  const _PaceRow({required this.kpi, required this.isCurrentMonth});

  final WorkshopKpi kpi;

  /// Tháng đã khép thì không còn nhịp nào để chạy.
  final bool isCurrentMonth;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final style = text.labelSmall?.copyWith(
      color: scheme.onSurfaceVariant,
      fontFeatures: OmniType.tabular,
    );
    final next = kpi.nextTier;
    final pace = kpi.perDayNeeded;

    // Một chữ số thập phân, dấu phẩy kiểu Việt: "2,1 việc/ngày". Làm tròn lên
    // thành số nguyên là nói dối về nhịp cần thiết.
    final left = !isCurrentMonth || kpi.daysLeft <= 0
        ? 'Đã hết tháng'
        : pace != null
        ? '${pace.toStringAsFixed(1).replaceAll('.', ',')} việc/ngày · '
              'còn ${kpi.daysLeft} ngày'
        : 'còn ${kpi.daysLeft} ngày';

    return Row(
      children: [
        Expanded(child: Text(left, style: style)),
        const SizedBox(width: OmniSpacing.sm),
        Text(
          next == null ? 'Đã đạt mốc cao nhất' : 'Mốc ${next.count} việc',
          style: style,
        ),
      ],
    );
  }
}

/// "Mốc thưởng tiếp: Còn n việc tới mốc X · thưởng Y triệu" + số lần làm lại.
class _BonusRow extends StatelessWidget {
  const _BonusRow({required this.kpi, required this.isCurrentMonth});

  final WorkshopKpi kpi;
  final bool isCurrentMonth;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final next = kpi.nextTier;

    final Widget left;
    if (kpi.tiers.isEmpty) {
      // Workspace chưa khai bảng mốc thưởng. `nextTier` cũng null lúc này, nên
      // nhánh dưới sẽ chúc mừng một xưởng chưa ai nhập bảng thưởng — hai
      // chuyện khác hẳn nhau mà nhìn từ `nextTier` thì giống hệt.
      //
      // Chữ NHỎ: câu này dành cho người quản trị đọc một lần.
      left = Text(
        'Workspace chưa khai bảng mốc thưởng.',
        style: text.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
      );
    } else if (next == null) {
      // Vượt mốc cao nhất là tin tốt. Một ô trống ở đây đọc như lỗi tải.
      left = Text(
        'Đã đạt mốc cao nhất của tháng.',
        style: text.labelMedium?.copyWith(color: scheme.primary),
      );
    } else {
      // Tháng đã khép thì không còn gì để "chạy tới": "còn 5 việc tới mốc 35"
      // đọc như một lời động viên cho một tháng đã hết.
      left = Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: 'Mốc thưởng tiếp: ',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            TextSpan(
              text: isCurrentMonth
                  ? 'Còn ${next.remaining} việc tới mốc ${next.count} · '
                        'thưởng ${next.bonus} triệu'
                  : 'Thiếu ${next.remaining} việc so với mốc ${next.count} · '
                        'thưởng ${next.bonus} triệu',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
              ),
            ),
          ],
        ),
        style: text.labelSmall,
      );
    }

    // Số lần làm lại (§B3): cam khi > 1, phụ khi ≤ 1. Không kèm tên ai — nó là
    // thông tin để cải thiện chứ không phải một lời buộc tội.
    final reworkColor = kpi.rework > 1
        ? OmniTaskTones.of(context).late.foreground
        : scheme.onSurfaceVariant;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (kpi.reachedBonus > 0) ...[
          // Vàng chữ mực: mốc thưởng đã đạt là tin vui duy nhất trên thẻ.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
          const SizedBox(height: OmniSpacing.sm),
        ],
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: left),
            const SizedBox(width: OmniSpacing.sm),
            Text(
              '${kpi.rework} lần làm lại',
              style: text.labelSmall?.copyWith(
                color: reworkColor,
                fontFeatures: OmniType.tabular,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
