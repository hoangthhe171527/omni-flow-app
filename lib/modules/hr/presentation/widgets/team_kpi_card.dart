import 'package:flutter/material.dart';

import '../../../../design/components/components.dart';
import '../../domain/hr_format.dart';
import '../../domain/hr_models.dart';
import 'hr_ui.dart';

/// Thẻ thưởng đội (spec 02 §6): số cây / mục tiêu, thanh tiến độ và mốc,
/// thưởng đội (đã trừ lỗi), "Thêm x cây". Không có bảng xếp hạng cá nhân.
///
/// Dùng ở màn Thưởng đội và thay thẻ KPI cũ ở Dòng việc khi người xem thuộc
/// một đội có cấu hình KPI đội (`/kpi/me` có `team`).
class TeamKpiCard extends StatelessWidget {
  const TeamKpiCard({super.key, required this.kpi, this.onTap});

  final KpiMe kpi;

  /// Có thì cả thẻ có dòng "Xem thưởng đội ›" ở cuối.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final next = kpi.next ?? kpi.nextTier;
    final ticks = [for (final t in kpi.tiers) '${t.at}'];
    return OmniGroupSection(
      dividerIndent: 14,
      children: [
        HrHero(
          label: kpi.closed
              ? '${kpi.teamName} · đã chốt'
              : '${kpi.teamName} · đã tính',
          pill: kpi.closed
              ? const HrPill('Đã chốt', tone: OmniTone.success)
              : const HrPill('Tạm tính', tone: OmniTone.info),
          number: HrFormat.decimal(kpi.n),
          unit: kpi.scale > 0 ? '/ ${kpi.scale} cây' : 'cây',
          progress: kpi.scale > 0 ? kpi.progress : null,
          ticks: ticks.length > 1 ? ticks : const [],
        ),
        HrStatRow(
          title: 'Thưởng đội',
          value: HrFormat.money(kpi.pool),
          strong: true,
          subtitle: kpi.deducted > 0
              ? 'Theo mốc ${HrFormat.money(kpi.gross)} · trừ lỗi ${HrFormat.money(kpi.deducted)}'
              : null,
        ),
        if (next != null && !kpi.closed && next.gain > 0)
          HrStatRow(
            title: 'Thêm ${next.need} cây',
            // Số tiền màu mực (spec §3.5); dấu + đã nói là được thêm.
            value: '+${HrFormat.money(next.gain)}',
            strong: true,
            subtitle: 'Thưởng cả đội khi đạt ${next.at} cây',
          ),
        if (onTap != null) OmniGroupRow(title: 'Xem thưởng đội', onTap: onTap),
      ],
    );
  }
}
