import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/error/app_exception.dart';
import '../../../design/components/components.dart';
import '../application/hr_providers.dart';
import '../data/hr_api.dart';
import '../domain/hr_format.dart';
import '../domain/hr_models.dart';
import '../routes.dart';
import 'widgets/hr_ui.dart';
import 'widgets/wifi_capture_sheet.dart';

/// Màn **Xưởng hôm nay** của quản đốc (spec 03 §5.2): đã chấm / tổng, chưa
/// chấm (Nhắc cả, Gọi), tăng ca chưa đăng ký (Bỏ qua / Duyệt), bốc cont.
class WorkshopTodayPage extends ConsumerStatefulWidget {
  const WorkshopTodayPage({super.key});

  @override
  ConsumerState<WorkshopTodayPage> createState() => _WorkshopTodayPageState();
}

class _WorkshopTodayPageState extends ConsumerState<WorkshopTodayPage> {
  bool _reminded = false;
  final _busyOt = <String>{};

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(hrWorkshopProvider);
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: const OmniTopBar(
        allowBack: true,
        semanticsTitle: 'Xưởng hôm nay',
      ),
      body: OmniTopBarOverlap.wrap(
        child: Builder(
          builder: (context) {
            final top = OmniTopBarOverlap.of(context);
            return RefreshIndicator.adaptive(
              edgeOffset: top,
              onRefresh: () async {
                ref.invalidate(hrWorkshopProvider);
                await ref
                    .read(hrWorkshopProvider.future)
                    .then((_) {}, onError: (_) {});
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: hrListPadding(context, top),
                children: switch (data) {
                  AsyncData(:final value) => _content(context, value),
                  AsyncError(:final error) when !data.isLoading => [
                    OmniErrorView(
                      error: error,
                      onRetry: () => ref.invalidate(hrWorkshopProvider),
                    ),
                  ],
                  _ => const [OmniSkeletonBox(height: 320, radius: 18)],
                },
              ),
            );
          },
        ),
      ),
    );
  }

  List<Widget> _content(BuildContext context, HrWorkshopToday w) {
    final access = ref.watch(hrAccessProvider);
    final prices = {
      for (final t
          in ref.watch(hrContTypesProvider).valueOrNull ?? const <HrContType>[])
        t.code: t.price,
    };
    final pendingApprovals = ref.watch(hrPendingApprovalsProvider);
    final notIn = w.notClockedIn;
    final date = HrFormat.dateOf(w.date);
    return [
      OmniGroupSection(
        dividerIndent: 14,
        children: [
          HrHero(
            label: date == null ? 'Hôm nay' : HrFormat.dayLabel(date),
            pill: notIn.isEmpty
                ? const HrPill('Đủ người', tone: OmniTone.success)
                : HrPill('${notIn.length} chưa chấm', tone: OmniTone.warning),
            number: '${w.clockedIn}',
            unit: '/ ${w.total} đã chấm',
            progress: w.total <= 0 ? 0 : w.clockedIn / w.total,
          ),
          HrStatRow(
            title: 'Nghỉ phép',
            value: '${w.onLeave.length} người',
            subtitle: w.onLeave.isEmpty
                ? null
                : w.onLeave.map((r) => r.name).join(', '),
          ),
          if (access.approve)
            HrStatRow(
              title: 'Đơn chờ duyệt',
              value: '$pendingApprovals đơn',
              tone: pendingApprovals > 0 ? OmniTone.warning : null,
              onTap: () => context.goNamed(HrRoutes.approvals),
            ),
        ],
      ),
      const SizedBox(height: OmniGroupSection.gap),
      OmniGroupSection(
        title: 'Chưa chấm vào · ${notIn.length}',
        trailingTitle: notIn.isEmpty
            ? null
            : _reminded
            ? const HrPill('Đã nhắc', tone: OmniTone.success)
            : TextButton(
                key: const ValueKey('hr-remind'),
                onPressed: () => _remind(notIn.length),
                child: Text('Nhắc cả ${notIn.length}'),
              ),
        children: notIn.isEmpty
            ? const [OmniGroupRow(title: 'Mọi người đã chấm')]
            : [
                for (final r in notIn)
                  OmniGroupRow(
                    leading: HrInitialTile(r.name),
                    title: r.name,
                    subtitle: r.orgUnitName,
                    trailing: r.phone == null
                        ? null
                        : OutlinedButton(
                            onPressed: () =>
                                launchUrl(Uri(scheme: 'tel', path: r.phone)),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 36),
                            ),
                            child: const Text('Gọi'),
                          ),
                  ),
              ],
      ),
      if (w.otPending.isNotEmpty && access.approve) ...[
        const SizedBox(height: OmniGroupSection.gap),
        OmniGroupSection(
          title: 'Tăng ca chưa đăng ký',
          children: [for (final r in w.otPending) _otRow(r, w)],
        ),
      ],
      const SizedBox(height: OmniGroupSection.gap),
      OmniGroupSection(
        title: 'Bốc cont hôm nay',
        trailingTitle: access.approve
            ? TextButton.icon(
                key: const ValueKey('hr-cont-add'),
                onPressed: () async {
                  final saved = await context.pushNamed<bool>(
                    HrRoutes.contLoad,
                  );
                  if (saved == true) ref.invalidate(hrWorkshopProvider);
                },
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Ghi lượt'),
              )
            : null,
        children: w.contLoads.isEmpty
            ? const [OmniGroupRow(title: 'Chưa có lượt nào')]
            : [
                for (final c in w.contLoads)
                  OmniGroupRow(
                    icon: Icons.inventory_2_outlined,
                    title: prices[c.type] == null
                        ? 'Loại ${c.type}'
                        : 'Loại ${c.type} · ${HrFormat.money(prices[c.type]!)}',
                    subtitle: c.names.where((n) => n.isNotEmpty).join(', '),
                    trailing: c.time == null ? null : HrValue(c.time!),
                  ),
              ],
      ),
      if (access.wifiCapture) ...[
        const SizedBox(height: OmniGroupSection.gap),
        OmniGroupSection(
          children: [
            OmniGroupRow(
              icon: Icons.wifi_rounded,
              title: 'Thêm WiFi đang kết nối',
              onTap: () => showWifiCaptureSheet(context),
            ),
          ],
        ),
      ],
    ];
  }

  Widget _otRow(HrWorkshopRow r, HrWorkshopToday w) {
    final busy = _busyOt.contains(r.membershipId);
    final hours = HrFormat.decimal(r.otPendingYesterday);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HrInitialTile(r.name),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _RowTitle(r.name),
                _RowSubtitle('Hôm qua · $hours giờ, chưa có đơn'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: busy ? null : () => _decideOt(r, w, false),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 36),
                      ),
                      child: const Text('Bỏ qua'),
                    ),
                    FilledButton(
                      onPressed: busy ? null : () => _decideOt(r, w, true),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 36),
                      ),
                      child: Text('Duyệt $hours giờ'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _remind(int count) async {
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

  Future<void> _decideOt(
    HrWorkshopRow r,
    HrWorkshopToday w,
    bool approve,
  ) async {
    final date = w.yesterday;
    if (date == null) return;
    setState(() => _busyOt.add(r.membershipId));
    try {
      await ref
          .read(hrApiProvider)
          .decideOtPending(r.membershipId, date, approve: approve);
      ref.invalidate(hrWorkshopProvider);
      if (mounted) {
        hrToast(
          context,
          approve
              ? 'Đã duyệt ${HrFormat.decimal(r.otPendingYesterday)} giờ cho ${r.shortName}'
              : 'Đã bỏ qua',
        );
      }
    } on AppException catch (e) {
      if (mounted) hrToast(context, e.message);
    } finally {
      if (mounted) setState(() => _busyOt.remove(r.membershipId));
    }
  }
}

/// Tiêu đề dòng tự vẽ, cùng kiểu chữ [OmniGroupRow].
class _RowTitle extends StatelessWidget {
  const _RowTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: Theme.of(
      context,
    ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
  );
}

class _RowSubtitle extends StatelessWidget {
  const _RowSubtitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: Theme.of(context).textTheme.bodySmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    ),
  );
}
