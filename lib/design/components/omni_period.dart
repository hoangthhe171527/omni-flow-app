import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../tokens/tokens.dart';
import 'omni_group.dart';
import 'omni_inputs.dart';

/// Đơn vị kỳ của [OmniPeriod].
enum OmniPeriodUnit {
  week('Tuần'),
  month('Tháng'),
  quarter('Quý'),
  year('Năm');

  const OmniPeriodUnit(this.label);
  final String label;
}

/// Một kỳ báo cáo: [unit] + ngày đầu kỳ [start] (00:00 giờ máy).
///
/// Tuần bắt đầu thứ Hai. [end] là ngày đầu kỳ SAU (không bao gồm) — lọc dữ
/// liệu bằng `start <= t < end`.
@immutable
class OmniPeriod {
  const OmniPeriod._(this.unit, this.start);

  /// Kỳ [unit] chứa ngày [day].
  factory OmniPeriod.containing(OmniPeriodUnit unit, DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    return switch (unit) {
      OmniPeriodUnit.week => OmniPeriod._(
        unit,
        d.subtract(Duration(days: d.weekday - DateTime.monday)),
      ),
      OmniPeriodUnit.month => OmniPeriod._(unit, DateTime(d.year, d.month)),
      OmniPeriodUnit.quarter => OmniPeriod._(
        unit,
        DateTime(d.year, ((d.month - 1) ~/ 3) * 3 + 1),
      ),
      OmniPeriodUnit.year => OmniPeriod._(unit, DateTime(d.year)),
    };
  }

  final OmniPeriodUnit unit;
  final DateTime start;

  DateTime get end => _shift(1);

  OmniPeriod get next => OmniPeriod._(unit, _shift(1));
  OmniPeriod get previous => OmniPeriod._(unit, _shift(-1));

  /// Quý 1–4 của kỳ (chỉ có nghĩa khi [unit] là quý).
  int get quarter => (start.month - 1) ~/ 3 + 1;

  bool contains(DateTime t) => !t.isBefore(start) && t.isBefore(end);

  DateTime _shift(int n) => switch (unit) {
    OmniPeriodUnit.week => DateTime(start.year, start.month, start.day + 7 * n),
    OmniPeriodUnit.month => DateTime(start.year, start.month + n),
    OmniPeriodUnit.quarter => DateTime(start.year, start.month + 3 * n),
    OmniPeriodUnit.year => DateTime(start.year + n),
  };

  /// "24/11 – 30/11" · "Tháng 11/2026" · "Quý 4 · 2026" · "Năm 2026".
  String get label {
    String dm(DateTime d) =>
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
    return switch (unit) {
      OmniPeriodUnit.week =>
        '${dm(start)} – ${dm(end.subtract(const Duration(days: 1)))}',
      OmniPeriodUnit.month => 'Tháng ${start.month}/${start.year}',
      OmniPeriodUnit.quarter => 'Quý $quarter · ${start.year}',
      OmniPeriodUnit.year => 'Năm ${start.year}',
    };
  }

  @override
  bool operator ==(Object other) =>
      other is OmniPeriod && other.unit == unit && other.start == start;

  @override
  int get hashCode => Object.hash(unit, start);

  @override
  String toString() => 'OmniPeriod($label)';
}

/// Bộ chọn kỳ DUY NHẤT của app (Chuẩn Mobile UI — PeriodPicker):
/// tên kỳ 17/600 bên trái (chạm → sheet chọn loại kỳ khi có hơn một
/// [units]), hai nút tròn ‹ › bên phải. Kỳ sau [latest] (mặc định: hôm nay)
/// không đi tới được — nút › mờ.
///
/// Thay cho: thanh chọn Tháng · Quý · Năm, sheet chọn tháng, popover chọn
/// tháng, hai nút rời.
class OmniPeriodPicker extends StatelessWidget {
  const OmniPeriodPicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.units = const [OmniPeriodUnit.month],
    this.latest,
  });

  final OmniPeriod value;
  final ValueChanged<OmniPeriod> onChanged;

  /// Loại kỳ được chọn; một phần tử thì tên kỳ không chạm được.
  final List<OmniPeriodUnit> units;

  /// Ngày muộn nhất được xem. `null` = hôm nay.
  final DateTime? latest;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final limit = latest ?? DateTime.now();
    final canNext = !value.next.start.isAfter(limit);
    final choosable = units.length > 1;

    final title = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            value.label,
            style: OmniType.navTitle.copyWith(
              color: scheme.onSurface,
              fontFeatures: OmniType.tabular,
            ),
          ),
        ),
        if (choosable) ...[
          const SizedBox(width: 4),
          Icon(
            LucideIcons.chevronDown,
            size: OmniIconSize.sm,
            color: scheme.onSurfaceVariant,
          ),
        ],
      ],
    );

    return SizedBox(
      height: 44,
      child: Row(
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Semantics(
                button: choosable,
                label: choosable ? 'Chọn kỳ, ${value.label}' : value.label,
                excludeSemantics: true,
                child: InkWell(
                  onTap: choosable ? () => _chooseUnit(context) : null,
                  borderRadius: OmniRadius.mdAll,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 10,
                    ),
                    child: title,
                  ),
                ),
              ),
            ),
          ),
          _StepButton(
            icon: LucideIcons.chevronLeft,
            label: 'Kỳ trước, ${value.previous.label}',
            onTap: () => onChanged(value.previous),
          ),
          const SizedBox(width: 4),
          _StepButton(
            icon: LucideIcons.chevronRight,
            label: 'Kỳ sau, ${value.next.label}',
            onTap: canNext ? () => onChanged(value.next) : null,
          ),
        ],
      ),
    );
  }

  Future<void> _chooseUnit(BuildContext context) async {
    final picked = await showOmniSheet<OmniPeriodUnit>(
      context: context,
      builder: (sheet) => OmniSheetBody(
        header: const OmniSheetHeader(title: 'Chọn kỳ'),
        children: [
          OmniGroupSection(
            dividerIndent: 16,
            children: [
              for (final u in units)
                OmniGroupRow(
                  title: u.label,
                  selected: u == value.unit,
                  onTap: () => Navigator.of(sheet).pop(u),
                ),
            ],
          ),
        ],
      ),
    );
    if (picked == null || picked == value.unit) return;
    // Giữ mốc ngày đang xem, đổi cỡ kỳ: Tháng 11/2026 → Quý 4 · 2026.
    var next = OmniPeriod.containing(picked, value.start);
    final limit = latest ?? DateTime.now();
    if (next.start.isAfter(limit)) next = OmniPeriod.containing(picked, limit);
    onChanged(next);
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        radius: 22,
        child: SizedBox.square(
          dimension: 44,
          child: Center(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: SizedBox.square(
                dimension: 32,
                child: Icon(
                  icon,
                  size: OmniIconSize.md,
                  color: enabled
                      ? scheme.onSurface
                      : scheme.onSurfaceVariant.withValues(alpha: .45),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
