import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/error/app_exception.dart';
import '../../../design/components/components.dart';
import '../application/hr_providers.dart';
import '../data/hr_api.dart';
import '../domain/hr_format.dart';
import '../domain/hr_models.dart';
import '../routes.dart';
import 'widgets/hr_ui.dart';

IconData hrRequestIcon(HrRequestType type) => switch (type) {
  HrRequestType.phep => Icons.beach_access_outlined,
  HrRequestType.tangca => Icons.more_time_rounded,
  HrRequestType.giaitrinh => Icons.edit_note_rounded,
  HrRequestType.tamung => Icons.payments_outlined,
};

/// Viên trạng thái đơn.
Widget hrRequestPill(String status) => switch (status) {
  'cho' => const HrPill('Chờ duyệt', tone: OmniTone.warning),
  'duyet' => const HrPill('Đã duyệt', tone: OmniTone.success),
  'tuchoi' => const HrPill('Từ chối', tone: OmniTone.danger),
  _ => const HrPill('Đã huỷ'),
};

/// Màn **Đơn từ** của thợ: Chờ duyệt / Đã xử lý; nút + góc phải dưới mở Đơn
/// mới (form toàn màn).
class RequestsPage extends ConsumerStatefulWidget {
  const RequestsPage({super.key});

  @override
  ConsumerState<RequestsPage> createState() => _RequestsPageState();
}

class _RequestsPageState extends ConsumerState<RequestsPage> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(hrMyRequestsProvider);
    final all = data.valueOrNull?.requests ?? const <HrRequest>[];
    final pending = all.where((r) => r.pending).toList();
    final done = all.where((r) => !r.pending).toList();
    final list = _tab == 0 ? pending : done;
    final leave = data.valueOrNull?.leave;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: const OmniTopBar(allowBack: true, semanticsTitle: 'Đơn từ'),
      body: OmniFabLayer(
        fab: OmniLiquidFab(
          key: const ValueKey('hr-request-add'),
          tooltip: 'Tạo đơn',
          onPressed: (_) => context.pushNamed(HrRoutes.requestNew),
        ),
        body: OmniTopBarOverlap.wrap(
          child: Builder(
            builder: (context) {
              final top = OmniTopBarOverlap.of(context);
              return RefreshIndicator.adaptive(
                edgeOffset: top,
                onRefresh: () async {
                  ref.invalidate(hrMyRequestsProvider);
                  await ref
                      .read(hrMyRequestsProvider.future)
                      .then((_) {}, onError: (_) {});
                },
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: hrListPadding(context, top, fab: true),
                  children: [
                    OmniSegmented(
                      labels: [
                        pending.isEmpty
                            ? 'Chờ duyệt'
                            : 'Chờ duyệt · ${pending.length}',
                        'Đã xử lý',
                      ],
                      index: _tab,
                      onChanged: (i) => setState(() => _tab = i),
                    ),
                    const SizedBox(height: OmniGroupSection.gap),
                    if (data.hasError && !data.hasValue)
                      OmniErrorView(
                        error: data.error!,
                        onRetry: () => ref.invalidate(hrMyRequestsProvider),
                      )
                    else if (!data.hasValue)
                      const OmniSkeletonBox(height: 180, radius: 18)
                    else if (list.isEmpty)
                      const OmniGroupSection(
                        children: [OmniGroupRow(title: 'Không có đơn')],
                      )
                    else
                      OmniGroupSection(
                        footer: leave == null
                            ? null
                            : 'Phép còn ${HrFormat.decimal(leave.remaining)} ngày',
                        children: [
                          for (final r in list)
                            OmniGroupRow(
                              icon: hrRequestIcon(r.type),
                              title: r.typeLabel,
                              subtitle: [
                                r.detail,
                                if (r.status == 'tuchoi' &&
                                    r.decisionNote != null)
                                  r.decisionNote!,
                              ].join('\n'),
                              trailing: hrRequestPill(r.status),
                              onTap: r.pending ? () => _openPending(r) : null,
                            ),
                        ],
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _openPending(HrRequest r) async {
    final cancel = await showOmniSheet<bool>(
      context: context,
      builder: (sheet) => OmniSheetBody(
        header: OmniSheetHeader(title: r.typeLabel, subtitle: r.detail),
        children: [
          if (r.reason != null)
            OmniGroupSection(
              children: [OmniGroupRow(title: 'Lý do', subtitle: r.reason)],
            ),
          OmniGroupSection(
            children: [
              OmniGroupRow(
                title: 'Huỷ đơn',
                destructive: true,
                onTap: () => Navigator.of(sheet).pop(true),
              ),
            ],
          ),
        ],
      ),
    );
    if (cancel != true || !mounted) return;
    try {
      await ref.read(hrApiProvider).cancelRequest(r.id);
      ref.invalidate(hrMyRequestsProvider);
      if (mounted) hrToast(context, 'Đã huỷ đơn');
    } on AppException catch (e) {
      if (mounted) hrToast(context, e.message);
    }
  }
}
