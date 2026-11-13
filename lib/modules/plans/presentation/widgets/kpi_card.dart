import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/utils/formatters.dart';
import '../../../../design/components/components.dart';
import '../../../../design/platform/omni_motion_scope.dart';
import '../../../../design/tokens/tokens.dart';
import '../../domain/workshop_kpi.dart';

/// "Tháng này xong bao nhiêu cây, còn bao xa tới mốc thưởng."
///
/// §B4 của `TNP_PIANO_WORKSHOP_FLOW.md`: thẻ này thay hoàn toàn cái bảng đếm
/// tay trên Zalo, và cuối tháng chủ xưởng đọc nó để trao thưởng.
///
/// Liquid (đợt 2, duyệt 08/11/2026): không còn dải ô KPI — các con số là
/// những dòng "nhãn — số" trong một nhóm lồng, đủ số, không cắt.
///
/// Thưởng tính theo TEAM (§1), nên không có tên ai trên thẻ này — thêm một
/// bảng xếp hạng cá nhân là đổi cách xưởng làm việc, và tài liệu nói rõ họ
/// không làm vậy.
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
  /// là cùng một sự thật. Thẻ đọc nó để biết nên viết "còn bao xa tới mốc"
  /// (tháng đang chạy) hay "thiếu bao nhiêu so với mốc" (tháng đã khép).
  final VoidCallback? onNextMonth;

  /// Mở chỗ đánh dấu nhóm việc đích. Chỉ dùng khi KPI chưa cấu hình.
  final VoidCallback? onConfigure;

  bool get _isCurrentMonth => onNextMonth == null;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // Chưa dự án nào đánh dấu cột đích. Một số 0 ở đây trông y hệt "tháng này
    // chưa xong cây nào", nên vẫn phải nói ra là cái nào — nhưng MỘT DÒNG,
    // không phải một khối. Không có thanh chọn tháng ở nhánh này.
    if (!kpi.isConfigured) {
      return OmniGroupSection(
        children: [
          OmniGroupRow(
            icon: Icons.flag_outlined,
            title: 'Đánh dấu nhóm việc đích',
            onTap: onConfigure,
          ),
        ],
      );
    }

    final motion = OmniMotion.enabled(context);
    final tones = OmniTaskTones.of(context);
    final next = kpi.nextTier;
    final pace = kpi.perDayNeeded;
    final hasTiers = kpi.tiers.isNotEmpty;

    final rows = <Widget>[
      OmniGroupRow(
        icon: Icons.task_alt_rounded,
        // "trong tháng", không phải "tháng này": thanh ngay trên đã nói là
        // tháng nào, và từ khi lùi được về tháng trước thì "tháng này" là
        // một khẳng định sai.
        title: 'Việc xong trong tháng',
        trailing: Text(
          '${kpi.delivered}',
          style: OmniType.title.copyWith(
            color: scheme.onSurface,
            fontFeatures: OmniType.tabular,
          ),
        ),
      ),
      if (previousDelivered case final int previous)
        _deltaRow(
          delta: kpi.delivered - previous,
          previousMonth: DateTime(month.year, month.month - 1),
          tone: kpi.delivered > previous ? tones.today : tones.upcoming,
        ),
      if (hasTiers) ...[
        OmniGroupRow(
          icon: Icons.speed_rounded,
          title: 'Nhịp cần thiết',
          value: !_isCurrentMonth || kpi.daysLeft <= 0
              ? 'Đã hết tháng'
              // Một chữ số thập phân, dấu phẩy kiểu Việt: "2,1 việc/ngày".
              // Làm tròn lên thành số nguyên là nói dối về nhịp cần thiết.
              : pace != null
              ? '${pace.toStringAsFixed(1).replaceAll('.', ',')} việc/ngày · '
                    'còn ${kpi.daysLeft} ngày'
              : 'còn ${kpi.daysLeft} ngày',
        ),
        OmniGroupRow(
          key: const Key('kpi-tier-mark'),
          icon: Icons.flag_outlined,
          title: 'Mốc kế tiếp',
          value: next == null
              ? 'Đã đạt mốc cao nhất'
              : 'Mốc ${next.count} việc',
        ),
      ],
      if (kpi.reachedBonus > 0)
        OmniGroupRow(
          icon: Icons.emoji_events_outlined,
          title: 'Đã đạt thưởng',
          trailing: Text(
            _bonusMoney(kpi.reachedBonus),
            style: OmniType.bodyStrong.copyWith(
              color: scheme.onSurface,
              fontFeatures: OmniType.tabular,
            ),
          ),
        ),
      if (hasTiers && next == null)
        // Vượt mốc cao nhất là tin tốt. Một ô trống ở đây đọc như lỗi tải.
        const OmniGroupRow(
          icon: Icons.celebration_outlined,
          title: 'Đã đạt mốc cao nhất của tháng.',
          accent: true,
        )
      else if (next != null)
        // Tháng đã khép thì không còn gì để "chạy tới": "còn 5 việc tới mốc
        // 35" đọc như một lời động viên cho một tháng đã hết.
        OmniGroupRow(
          icon: Icons.card_giftcard_rounded,
          title: _isCurrentMonth
              ? 'Còn ${next.remaining} việc tới mốc ${next.count}'
              : 'Thiếu ${next.remaining} việc so với mốc ${next.count}',
          trailing: Text(
            _bonusMoney(next.bonus),
            style: OmniType.bodyStrong.copyWith(
              color: scheme.onSurface,
              fontFeatures: OmniType.tabular,
            ),
          ),
        ),
      // Số lần làm lại (§B3): cam khi > 1, phụ khi ≤ 1. Không kèm tên ai — nó
      // là thông tin để cải thiện chứ không phải một lời buộc tội.
      OmniGroupRow(
        icon: Icons.replay_rounded,
        title: 'Làm lại',
        trailing: Text(
          '${kpi.rework} lần làm lại',
          style: OmniType.bodySm.copyWith(
            color: kpi.rework > 1
                ? tones.late.foreground
                : scheme.onSurfaceVariant,
            fontFeatures: OmniType.tabular,
          ),
        ),
      ),
    ];

    final group = OmniGroupSection(
      // Workspace chưa khai bảng mốc thưởng: câu này dành cho người quản trị
      // đọc một lần — chữ nhỏ dưới nhóm, không tranh với con số.
      footer: hasTiers ? null : 'Workspace chưa khai bảng mốc thưởng.',
      children: rows,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _MonthBar(month: month, onPrev: onPrevMonth, onNext: onNextMonth),
        const SizedBox(height: 8),
        // Số trượt vào khi đổi tháng (16px, 350ms); giảm chuyển động thì đổi
        // tức thì, không dựng AnimatedSwitcher.
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
              child: group,
            ),
          )
        else
          group,
      ],
    );
  }

  /// "+6 so với tháng 8" — con số có một mốc để đọc là nhiều hay ít.
  ///
  /// Hướng đi nằm ở BIỂU TƯỢNG và dấu, không chỉ ở màu: đỏ/xanh vô hình với
  /// người mù màu lục-đỏ. Tăng dùng tông "hôm nay" (xanh ngọc), bằng/giảm dùng
  /// tông trung tính — giảm KHÔNG tô đỏ.
  Widget _deltaRow({
    required int delta,
    required DateTime previousMonth,
    required OmniTaskTone tone,
  }) {
    final label = 'tháng ${previousMonth.month}';
    final (icon, text) = switch (delta) {
      > 0 => (Icons.trending_up_rounded, '+$delta so với $label'),
      // Dấu trừ thật (U+2212), cùng bề rộng với dấu cộng.
      < 0 => (Icons.trending_down_rounded, '−${-delta} so với $label'),
      _ => (Icons.trending_flat_rounded, 'Bằng $label'),
    };

    // Dòng riêng (không dùng OmniGroupRow) vì chữ mang màu của tông; ô biểu
    // tượng vẫn giữ 1 tông trung tính thẳng trục 54px với các dòng khác.
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          children: [
            OmniIconTile(icon),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: OmniType.body.copyWith(
                  fontWeight: FontWeight.w500,
                  color: tone.foreground,
                  fontFeatures: OmniType.tabular,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Chọn tháng: [‹]  Tháng 9/2026  [›] — nút kính tròn.
///
/// Cuối tháng chủ xưởng đọc con số để trao thưởng (§B4). Nhưng ngày mùng 1
/// con số đã về 0, và tháng vừa khép lại là thứ không còn xem được ở đâu cả.
///
/// Không đi tới TƯƠNG LAI: một tháng chưa tới luôn có `delivered = 0`, và một
/// số 0 ở đây trông y hệt "tháng này chưa ai xong cây nào". Nút mờ chứ không
/// biến mất: một mũi tên biến mất làm hàng nút nhảy chỗ.
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

/// Nút kính tròn 44.
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

    return Opacity(
      opacity: onPressed == null ? 0.4 : 1,
      child: OmniGlassCircle(
        child: IconButton(
          tooltip: tooltip,
          onPressed: onPressed == null
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  onPressed!();
                },
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 44, height: 44),
          style: IconButton.styleFrom(
            // Giảm chuyển động: không gợn sóng khi chạm.
            splashFactory: OmniMotion.enabled(context)
                ? null
                : NoSplash.splashFactory,
            overlayColor: OmniMotion.enabled(context)
                ? null
                : Colors.transparent,
            animationDuration: OmniMotion.enabled(context)
                ? null
                : Duration.zero,
          ),
          icon: Icon(icon, size: OmniIconSize.md, color: scheme.onSurface),
        ),
      ),
    );
  }
}

/// Tiền thưởng đầy đủ (`3.000.000đ`, không `3 triệu`).
///
/// Bảng mốc trên web nhập theo đơn vị TRIỆU ("Bonus (millions)") nhưng có nơi
/// đã nhập thẳng số đồng (1500000) → app từng hiện "thưởng 1500000 triệu".
/// Dưới 1000 thì là triệu; từ 1000 trở lên coi là đã là đồng.
String _bonusMoney(int bonus) =>
    Formatters.vnd(bonus >= 1000 ? bonus : bonus * 1000000);
