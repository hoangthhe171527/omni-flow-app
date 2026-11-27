import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../design/components/components.dart';
import '../../../design/tokens/tokens.dart';
import '../application/hr_providers.dart';
import '../domain/hr_format.dart';
import '../domain/hr_models.dart';
import '../routes.dart';
import 'widgets/hr_ui.dart';

/// Màn **Công tháng** (spec 03 §5.2): bộ chọn tháng, thẻ "19 / 26 công", lịch
/// chấm màu, chạm ngày mở sheet giờ vào/ra và nút Giải trình.
class TimesheetPage extends ConsumerStatefulWidget {
  const TimesheetPage({super.key, this.initialMonth, this.openDate});

  final String? initialMonth;

  /// Ngày mở sẵn sheet (từ thông báo thiếu chấm).
  final String? openDate;

  @override
  ConsumerState<TimesheetPage> createState() => _TimesheetPageState();
}

class _TimesheetPageState extends ConsumerState<TimesheetPage> {
  late String _month;
  bool _openedFromLink = false;

  @override
  void initState() {
    super.initState();
    final fromDate = widget.openDate != null && widget.openDate!.length >= 7
        ? widget.openDate!.substring(0, 7)
        : null;
    _month = widget.initialMonth ?? fromDate ?? ref.read(hrThisMonthProvider);
  }

  @override
  Widget build(BuildContext context) {
    final thisMonth = ref.watch(hrThisMonthProvider);
    final data = ref.watch(hrMonthProvider(_month));
    final leave = ref.watch(hrMyRequestsProvider).valueOrNull?.leave;
    final canNext = _month.compareTo(thisMonth) < 0;

    if (!_openedFromLink && widget.openDate != null && data.hasValue) {
      _openedFromLink = true;
      final d = data.value!.days.where((d) => d.date == widget.openDate);
      if (d.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => mounted ? _openDay(d.first) : null,
        );
      }
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: const OmniTopBar(allowBack: true, semanticsTitle: 'Công tháng'),
      body: OmniTopBarOverlap.wrap(
        child: Builder(
          builder: (context) {
            final top = OmniTopBarOverlap.of(context);
            return RefreshIndicator.adaptive(
              edgeOffset: top,
              onRefresh: () async {
                ref.invalidate(hrMonthProvider(_month));
                await ref
                    .read(hrMonthProvider(_month).future)
                    .then((_) {}, onError: (_) {});
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: hrListPadding(context, top),
                children: [
                  HrMonthSwitcher(
                    label: HrFormat.monthLabel(_month),
                    onPrev: () => setState(
                      () => _month = HrFormat.shiftMonth(_month, -1),
                    ),
                    onNext: canNext
                        ? () => setState(
                            () => _month = HrFormat.shiftMonth(_month, 1),
                          )
                        : null,
                  ),
                  const SizedBox(height: OmniGroupSection.gap),
                  ...switch (data) {
                    AsyncData(:final value) => _content(
                      context,
                      value,
                      leave,
                      current: _month == thisMonth,
                    ),
                    AsyncError(:final error) when !data.isLoading => [
                      OmniErrorView(
                        error: error,
                        onRetry: () => ref.invalidate(hrMonthProvider(_month)),
                      ),
                    ],
                    _ => const [OmniSkeletonBox(height: 420, radius: 18)],
                  },
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  List<Widget> _content(
    BuildContext context,
    HrMonth month,
    HrLeaveBalance? leave, {
    required bool current,
  }) {
    final t = month.totals;
    final scheduled = t.scheduled;
    final todayLabel = HrFormat.dayMonthOf(
      HrFormat.ymd(DateTime.now().toUtc().add(const Duration(hours: 7))),
    );
    return [
      OmniGroupSection(
        dividerIndent: 14,
        children: [
          HrHero(
            label: current ? 'Công tháng này' : 'Công tháng',
            pill: month.locked
                ? const HrPill('Đã khoá')
                : current
                ? HrPill('Tạm tính tới $todayLabel', tone: OmniTone.info)
                : null,
            number: HrFormat.decimal(t.j),
            unit: '/ $scheduled công',
            progress: scheduled <= 0 ? 0 : t.j / scheduled,
          ),
          HrStatRow(title: 'Đi muộn', value: t.lateLabel),
          HrStatRow(
            title: 'Tăng ca',
            value: '${HrFormat.decimal(t.otHours)} giờ',
          ),
          HrStatRow(
            title: 'Nghỉ phép',
            value: '${HrFormat.decimal(month.leaveDays)} ngày',
          ),
          if (t.missing > 0)
            HrStatRow(
              title: 'Thiếu chấm',
              value: '${HrFormat.decimal(t.missing)} ngày',
              tone: OmniTone.danger,
            ),
          if (leave != null)
            HrStatRow(
              title: 'Phép còn',
              value: '${HrFormat.decimal(leave.remaining)} ngày',
            ),
        ],
      ),
      const SizedBox(height: OmniGroupSection.gap),
      OmniGroupSection(
        children: [HrCalendar(month: month, onDay: _openDay)],
      ),
      const SizedBox(height: 8),
      const HrCalendarLegend(),
    ];
  }

  Future<void> _openDay(HrDay day) async {
    final shift = ref.read(hrTodayProvider).valueOrNull?.shift;
    await showOmniSheet<void>(
      context: context,
      builder: (sheet) => HrDaySheet(
        day: day,
        shiftLabel: shift?.label,
        onExplain: () {
          Navigator.of(sheet).pop();
          context.pushNamed(
            HrRoutes.requestNew,
            queryParameters: {'type': 'giaitrinh', 'date': day.date},
          );
        },
      ),
    );
  }
}

/// Màu chấm của một ngày trên lịch; null = không chấm.
Color? hrDayDot(BuildContext context, HrDay? day) {
  if (day == null) return null;
  final scheme = Theme.of(context).colorScheme;
  return switch (day.status) {
    'w' when day.isLate => OmniColors.warningTextOf(context),
    'w' when day.hasOt => OmniTaskTones.of(context).violet.foreground,
    'w' => OmniColors.successTextOf(context),
    // Phép / lễ: tông thông tin, không màu nhấn (Màu bốn nghĩa).
    'p' || 'le' => _infoMark(context),
    'k' => scheme.onSurfaceVariant,
    'x' => OmniColors.dangerTextOf(context),
    _ => null,
  };
}

Color _infoMark(BuildContext context) => OmniTone.info
    .resolve(
      Theme.of(context).colorScheme,
      dark: Theme.of(context).brightness == Brightness.dark,
    )
    .$1;

/// Nghĩa của chấm ngày cho trình đọc màn hình (không chỉ dựa màu).
String? _dayMeaning(HrDay? day) => switch (day?.status) {
  'w' when day!.isLate => 'đi muộn',
  'w' when day!.hasOt => 'tăng ca',
  'w' => 'đủ công',
  'p' => 'nghỉ phép',
  'le' => 'ngày lễ',
  'k' => 'nghỉ không lương',
  'x' => 'thiếu chấm',
  _ => null,
};

/// Lịch tháng: hàng T2…CN, mỗi ô một số ngày + chấm màu.
class HrCalendar extends StatelessWidget {
  const HrCalendar({super.key, required this.month, required this.onDay});

  final HrMonth month;
  final ValueChanged<HrDay> onDay;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final first = HrFormat.dateOf('${month.month}-01');
    if (first == null) return const SizedBox.shrink();
    final daysInMonth = DateTime.utc(first.year, first.month + 1, 0).day;
    final lead = first.weekday - 1;
    final todayYmd = HrFormat.ymd(
      DateTime.now().toUtc().add(const Duration(hours: 7)),
    );
    final cells = <Widget>[
      for (final h in const ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'])
        Center(
          child: Text(
            h,
            style: OmniType.caption.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      for (var i = 0; i < lead; i++) const SizedBox.shrink(),
      for (var d = 1; d <= daysInMonth; d++)
        _cell(context, d, month.dayOf(d), todayYmd),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
      child: GridView.count(
        crossAxisCount: 7,
        padding: EdgeInsets.zero,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 1,
        mainAxisSpacing: 2,
        children: cells,
      ),
    );
  }

  Widget _cell(BuildContext context, int d, HrDay? day, String todayYmd) {
    final scheme = Theme.of(context).colorScheme;
    final dot = hrDayDot(context, day);
    final ymd = '${month.month}-${d.toString().padLeft(2, '0')}';
    final isToday = ymd == todayYmd;
    final future = day == null
        ? ymd.compareTo(todayYmd) > 0
        : day.status == 'fut';
    final sunday = HrFormat.dateOf(ymd)?.weekday == DateTime.sunday;
    final tappable =
        day != null && !future && (day.status != 'off' || day.inAt != null);
    final color = future || sunday
        ? scheme.onSurfaceVariant.withValues(alpha: future ? .5 : 1)
        : scheme.onSurface;
    final content = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '$d',
          // Hôm nay: chữ mực đậm (không màu nhấn).
          style: OmniType.body.copyWith(
            color: isToday ? scheme.onSurface : color,
            fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
            fontFeatures: OmniType.tabular,
          ),
        ),
        const SizedBox(height: 3),
        Container(
          width: 5,
          height: 5,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: dot ?? Colors.transparent,
          ),
        ),
      ],
    );
    if (!tappable) return content;
    return Semantics(
      button: true,
      label: ['Ngày $d', if (isToday) 'hôm nay', ?_dayMeaning(day)].join(', '),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => onDay(day),
        child: content,
      ),
    );
  }
}

class HrCalendarLegend extends StatelessWidget {
  const HrCalendarLegend({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final items = [
      ('Đủ', OmniColors.successTextOf(context)),
      ('Muộn', OmniColors.warningTextOf(context)),
      ('Tăng ca', OmniTaskTones.of(context).violet.foreground),
      ('Phép', _infoMark(context)),
      ('Thiếu chấm', OmniColors.dangerTextOf(context)),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Wrap(
        spacing: 12,
        runSpacing: 4,
        children: [
          for (final (label, color) in items)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  label,
                  style: OmniType.caption.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Sheet một ngày: giờ vào/ra, cách chấm, nút Giải trình khi muộn / thiếu.
class HrDaySheet extends StatelessWidget {
  const HrDaySheet({
    super.key,
    required this.day,
    required this.onExplain,
    this.shiftLabel,
  });

  final HrDay day;
  final String? shiftLabel;
  final VoidCallback onExplain;

  @override
  Widget build(BuildContext context) {
    final method = switch (day.method) {
      'wifi' => 'WiFi xưởng',
      'gps' => 'GPS',
      'explain' => 'Giải trình',
      'manual' => 'Quản lý sửa',
      _ => null,
    };
    final status = switch (day.status) {
      'p' => 'Nghỉ phép',
      'k' => 'Nghỉ không lương',
      'le' => day.holidayName ?? 'Ngày lễ',
      'x' => 'Thiếu chấm',
      'off' => 'Không có ca',
      _ => null,
    };
    return OmniSheetBody(
      semanticsLabel: HrFormat.dayLabelOf(day.date),
      header: OmniSheetHeader(
        title: HrFormat.dayLabelOf(day.date),
        subtitle: shiftLabel,
      ),
      footer: day.needsExplain
          ? FilledButton(onPressed: onExplain, child: const Text('Giải trình'))
          : null,
      children: [
        OmniGroupSection(
          dividerIndent: 14,
          children: [
            if (status != null)
              HrStatRow(
                title: 'Trạng thái',
                value: status,
                tone: day.status == 'x' ? OmniTone.danger : null,
              ),
            HrStatRow(
              title: 'Vào',
              value: HrFormat.hm(day.inAt) ?? '—',
              strong: !day.isLate,
              tone: day.isLate ? OmniTone.warning : null,
              subtitle: day.isLate ? 'Muộn ${day.lateMin} phút' : null,
            ),
            HrStatRow(
              title: 'Ra',
              value: HrFormat.hm(day.outAt) ?? '—',
              strong: true,
              subtitle: day.hasOt
                  ? 'Tăng ca ${HrFormat.decimal(day.otHours)} giờ'
                  : day.otPendingHours > 0
                  ? 'Tăng ca ${HrFormat.decimal(day.otPendingHours)} giờ · chờ duyệt'
                  : null,
            ),
            if (method != null) HrStatRow(title: 'Chấm bằng', value: method),
            if (day.status == 'x' && day.explainDue != null)
              HrStatRow(
                title: 'Hạn giải trình',
                value: HrFormat.dayMonthOf(day.explainDue),
              ),
          ],
        ),
      ],
    );
  }
}
