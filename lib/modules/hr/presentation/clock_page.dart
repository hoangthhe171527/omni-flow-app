import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/formatters.dart';
import '../../../design/components/components.dart';
import '../application/hr_providers.dart';
import '../domain/clock_state.dart';
import '../domain/hr_format.dart';
import '../domain/hr_models.dart';
import '../routes.dart';
import 'widgets/hr_ui.dart';

/// Bấm nút chấm: dùng chung cho màn Chấm công và thẻ trên Tổng quan.
Future<void> hrPressClock(
  BuildContext context,
  WidgetRef ref,
  HrToday today,
  ClockAction action,
) async {
  if (action == ClockAction.done) {
    hrToast(context, 'Hôm nay đã chấm đủ');
    return;
  }
  final ui = ref.read(clockControllerProvider);
  final kind = effectiveNext(today.next, ui.queued) == 'out' ? 'out' : 'in';
  final outcome = await ref
      .read(clockControllerProvider.notifier)
      .punch(kind: kind, zone: today.zone);
  if (context.mounted) hrToast(context, outcome.message);
}

/// Màn **Chấm công** (spec 03 §5.2): thẻ giờ lớn + nút Chấm vào/ra + dòng vị
/// trí; nhóm Hôm nay; nhóm tháng (nút "Xem công").
class ClockPage extends ConsumerStatefulWidget {
  const ClockPage({super.key});

  @override
  ConsumerState<ClockPage> createState() => _ClockPageState();
}

class _ClockPageState extends ConsumerState<ClockPage> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    // Giờ lớn trên thẻ chạy theo phút.
    _tick = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    final controller = ref.read(clockControllerProvider.notifier);
    ref.invalidate(hrTodayProvider);
    ref.invalidate(hrMyRequestsProvider);
    await Future.wait([
      controller.flush(),
      controller.refreshReading(),
      ref.read(hrTodayProvider.future).then((_) {}, onError: (_) {}),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final today = ref.watch(hrTodayProvider);
    final ui = ref.watch(clockControllerProvider);
    final leave = ref.watch(hrMyRequestsProvider).valueOrNull?.leave;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: const OmniTopBar(allowBack: true, semanticsTitle: 'Chấm công'),
      body: OmniTopBarOverlap.wrap(
        child: Builder(
          builder: (context) {
            final top = OmniTopBarOverlap.of(context);
            return RefreshIndicator.adaptive(
              edgeOffset: top,
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: hrListPadding(context, top),
                children: switch (today) {
                  AsyncData(:final value) => _content(
                    context,
                    value,
                    ui,
                    leave,
                  ),
                  AsyncError(:final error) when !today.isLoading => [
                    OmniErrorView(
                      error: error,
                      onRetry: () => ref.invalidate(hrTodayProvider),
                    ),
                  ],
                  _ => const [OmniSkeletonBox(height: 260, radius: 18)],
                },
              ),
            );
          },
        ),
      ),
    );
  }

  List<Widget> _content(
    BuildContext context,
    HrToday today,
    ClockUiState ui,
    HrLeaveBalance? leave,
  ) {
    final action = classifyClock(
      serverNext: today.next,
      queuedKinds: ui.queued,
      rejectCode: ui.rejection?.code,
    );
    final day = today.day;
    final inAt = HrFormat.hm(day?.inAt);
    final outAt = HrFormat.hm(day?.outAt);
    final queuedIn = ui.queued.contains('in') && inAt == null;
    final shownIn = inAt ?? (queuedIn ? 'Đang gửi' : null);
    final location = describeLocation(
      zone: today.zone,
      reading: ui.reading,
      rejection: ui.rejection,
      lastDistanceM: ui.lastDistanceM,
      offline: ui.offline || ui.queued.isNotEmpty,
    );
    final date = HrFormat.dateOf(today.date);
    final number = switch (action) {
      ClockAction.done when inAt != null && outAt != null => '$inAt – $outAt',
      ClockAction.clockOut when inAt != null => inAt,
      _ => HrFormat.nowHm(ref.watch(hrClockProvider)),
    };
    final pill = switch (action) {
      ClockAction.done => const HrPill('Đã xong ca', tone: OmniTone.info),
      ClockAction.clockOut => const HrPill(
        'Đang trong ca',
        tone: OmniTone.success,
      ),
      _ => const HrPill('Chưa chấm'),
    };
    final month = today.month;
    final monthNo = date?.month ?? VnTime.now().month;

    return [
      OmniGroupSection(
        dividerIndent: 14,
        children: [
          HrHero(
            label: date == null ? 'Hôm nay' : HrFormat.dayLabel(date),
            pill: pill,
            number: number,
            subtitle: today.shift?.label,
            bottom: HrClockButton(
              action: action,
              busy: ui.busy,
              onPressed: () => hrPressClock(context, ref, today, action),
            ),
          ),
          HrLocationRow(line: location),
        ],
      ),
      if (ui.rejection?.code == 'OUT_OF_ZONE') ...[
        const SizedBox(height: OmniGroupSection.gap),
        OmniGroupSection(
          children: [
            OmniGroupRow(
              icon: Icons.edit_note_rounded,
              title: 'Đang làm ngoài xưởng?',
              subtitle: 'Gửi giải trình để quản đốc xác nhận',
              onTap: () => context.pushNamed(
                HrRoutes.requestNew,
                queryParameters: {'type': 'giaitrinh', 'date': today.date},
              ),
            ),
          ],
        ),
      ],
      if (ui.rejection?.code == 'DEVICE_NOT_BOUND') ...[
        const SizedBox(height: OmniGroupSection.gap),
        const OmniGroupSection(
          children: [
            OmniGroupRow(
              icon: Icons.phonelink_lock_outlined,
              title: 'Vừa đổi điện thoại?',
              subtitle: 'Nhờ quản đốc gỡ máy cũ, rồi chấm lại',
            ),
          ],
        ),
      ],
      const SizedBox(height: OmniGroupSection.gap),
      OmniGroupSection(
        title: 'Hôm nay',
        children: [
          HrStatRow(title: 'Vào', value: shownIn ?? '—', strong: true),
          HrStatRow(title: 'Ra', value: outAt ?? '—', strong: true),
          HrStatRow(
            title: 'Giờ làm',
            value: _worked(day, inAt != null && outAt == null),
          ),
        ],
      ),
      const SizedBox(height: OmniGroupSection.gap),
      OmniGroupSection(
        title: 'Tháng $monthNo',
        trailingTitle: TextButton(
          onPressed: () => context.goNamed(HrRoutes.timesheet),
          child: const Text('Xem công'),
        ),
        children: [
          HrStatRow(
            title: 'Công',
            value:
                '${HrFormat.decimal(month.j)} / ${month.scheduledMonth ?? month.scheduled}',
            strong: true,
          ),
          HrStatRow(title: 'Đi muộn', value: month.lateLabel),
          if (leave != null)
            HrStatRow(
              title: 'Phép còn',
              value: '${HrFormat.decimal(leave.remaining)} ngày',
            ),
        ],
      ),
    ];
  }

  String _worked(HrDay? day, bool running) {
    final a = HrFormat.minuteOfDay(day?.inAt);
    if (a == null) return '—';
    final b = running
        ? () {
            final n = VnTime.now(ref.read(hrClockProvider));
            return n.hour * 60 + n.minute;
          }()
        : HrFormat.minuteOfDay(day?.outAt);
    if (b == null || b <= a) return '—';
    return HrFormat.duration(b - a);
  }
}
