import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../design/components/components.dart';
import '../../../../design/tokens/tokens.dart';
import '../../application/hr_providers.dart';
import '../../data/hr_api.dart';
import '../../domain/clock_state.dart';
import '../../domain/hr_format.dart';
import '../../routes.dart';
import '../clock_page.dart' show hrPressClock;
import 'hr_ui.dart';

/// Thẻ Nhân sự trên **Tổng quan** (spec 03 §5.1): thợ thấy "Chấm công hôm
/// nay" (chấm ngay, không cần mở màn khác), quản đốc thấy "Xưởng hôm nay".
/// Thiếu cờ / quyền thì không vẽ gì; lỗi mạng cũng không vẽ (Tổng quan không
/// bị một thẻ phụ làm ồn).
class HrHomeCard extends ConsumerWidget {
  const HrHomeCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final access = ref.watch(hrAccessProvider);
    if (access.workshop) return const _WorkshopCard();
    if (access.clock) return const _ClockCard();
    return const SizedBox.shrink();
  }
}

class _Title extends StatelessWidget {
  const _Title(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(minHeight: 44),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          style: OmniType.caption.copyWith(
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    ),
  );
}

/// Khối "nhãn nhỏ + chữ lớn | nút" ở đầu thẻ.
class _Lead extends StatelessWidget {
  const _Lead({
    required this.caption,
    required this.headline,
    required this.trailing,
    this.onTap,
  });

  final String caption;
  final String headline;
  final Widget trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final body = Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  caption,
                  style: OmniType.bodySm.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  headline,
                  style: OmniType.title.copyWith(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w600,
                    fontFeatures: OmniType.tabular,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          trailing,
        ],
      ),
    );
    if (onTap == null) return body;
    return InkWell(onTap: onTap, child: body);
  }
}

class _ClockCard extends ConsumerWidget {
  const _ClockCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(hrTodayProvider).valueOrNull;
    final ui = ref.watch(clockControllerProvider);
    if (today == null) return const SizedBox.shrink();
    final action = classifyClock(
      serverNext: today.next,
      queuedKinds: ui.queued,
      rejectCode: ui.rejection?.code,
    );
    final inAt = HrFormat.hm(today.day?.inAt);
    final outAt = HrFormat.hm(today.day?.outAt);
    final headline = switch (action) {
      ClockAction.done when inAt != null && outAt != null => '$inAt – $outAt',
      ClockAction.clockOut => inAt == null ? 'Đã chấm vào' : 'Vào $inAt',
      ClockAction.blocked => 'Chưa chấm được',
      _ => 'Chưa chấm',
    };
    final line = describeLocation(
      zone: today.zone,
      reading: ui.reading,
      rejection: ui.rejection,
      lastDistanceM: ui.lastDistanceM,
      offline: ui.offline || ui.queued.isNotEmpty,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: OmniGroupSection.gap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _Title('Chấm công hôm nay'),
          OmniGroupSection(
            dividerIndent: 14,
            children: [
              _Lead(
                caption: today.shift?.hours ?? 'Hôm nay',
                headline: headline,
                trailing: action == ClockAction.done
                    ? const HrPill('Đã xong ca', tone: OmniTone.info)
                    : HrClockButton(
                        action: action,
                        compact: true,
                        busy: ui.busy,
                        onPressed: () =>
                            hrPressClock(context, ref, today, action),
                      ),
              ),
              HrLocationRow(
                line: line,
                onTap: () => context.goNamed(HrRoutes.clock),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WorkshopCard extends ConsumerStatefulWidget {
  const _WorkshopCard();

  @override
  ConsumerState<_WorkshopCard> createState() => _WorkshopCardState();
}

class _WorkshopCardState extends ConsumerState<_WorkshopCard> {
  bool _reminded = false;

  Future<void> _remind() async {
    try {
      final sent = await ref.read(hrApiProvider).remind();
      if (!mounted) return;
      setState(() => _reminded = true);
      hrToast(
        context,
        sent > 0 ? 'Đã nhắc $sent người' : 'Vừa nhắc rồi, thử lại sau 15 phút',
      );
    } on AppException catch (e) {
      if (mounted) hrToast(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = ref.watch(hrWorkshopProvider).valueOrNull;
    final access = ref.watch(hrAccessProvider);
    final pending = ref.watch(hrPendingApprovalsProvider);
    if (w == null) return const SizedBox.shrink();
    final notIn = w.notClockedIn.length;
    final date = HrFormat.dateOf(w.date);
    return Padding(
      padding: const EdgeInsets.only(bottom: OmniGroupSection.gap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _Title('Xưởng hôm nay'),
          OmniGroupSection(
            dividerIndent: 14,
            children: [
              _Lead(
                caption: date == null ? 'Hôm nay' : HrFormat.dayLabel(date),
                headline: '${w.clockedIn} / ${w.total} đã chấm',
                onTap: () => context.goNamed(HrRoutes.workshop),
                trailing: notIn == 0
                    ? const HrPill('Đủ người', tone: OmniTone.success)
                    : _reminded
                    ? const HrPill('Đã nhắc', tone: OmniTone.success)
                    : FilledButton(
                        key: const ValueKey('hr-home-remind'),
                        onPressed: _remind,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 46),
                        ),
                        child: Text('Nhắc $notIn'),
                      ),
              ),
              if (access.approve)
                OmniGroupRow(
                  icon: LucideIcons.clipboardCheck,
                  title: 'Đơn chờ duyệt',
                  trailing: HrValue(
                    '$pending đơn',
                    tone: pending > 0 ? OmniTone.warning : null,
                  ),
                  chevron: true,
                  onTap: () => context.goNamed(HrRoutes.approvals),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Kéo làm mới Tổng quan: nạp lại số liệu của thẻ Nhân sự (provider không ai
/// nghe thì không gọi mạng).
void refreshHrHomeCard(WidgetRef ref) {
  ref
    ..invalidate(hrTodayProvider)
    ..invalidate(hrWorkshopProvider)
    ..invalidate(hrApprovalsProvider);
}
