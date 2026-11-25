import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_exception.dart';
import '../../../design/components/components.dart';
import '../application/hr_providers.dart';
import '../data/hr_api.dart';
import '../domain/hr_format.dart';
import '../domain/hr_models.dart';
import 'requests_page.dart' show hrRequestPill;
import 'widgets/hr_ui.dart';

/// Màn **Duyệt đơn** của quản đốc (spec 03 §5.2): Chờ duyệt (số) / Đã xử lý;
/// chạm đơn mở sheet chi tiết, Từ chối / Duyệt.
class ApprovalsPage extends ConsumerStatefulWidget {
  const ApprovalsPage({super.key, this.openId});

  /// Đơn mở sẵn (từ thông báo `hr_request`).
  final String? openId;

  @override
  ConsumerState<ApprovalsPage> createState() => _ApprovalsPageState();
}

class _ApprovalsPageState extends ConsumerState<ApprovalsPage> {
  int _tab = 0;
  bool _opened = false;

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(hrApprovalsProvider);
    final all = data.valueOrNull ?? const <HrRequest>[];
    final pending = all.where((r) => r.pending).toList();
    final done = all.where((r) => !r.pending).toList();
    final list = _tab == 0 ? pending : done;

    if (!_opened && widget.openId != null && data.hasValue) {
      _opened = true;
      final hit = pending.where((r) => r.id == widget.openId);
      if (hit.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => mounted ? _open(hit.first) : null,
        );
      }
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: const OmniTopBar(allowBack: true, semanticsTitle: 'Duyệt đơn'),
      body: OmniTopBarOverlap.wrap(
        child: Builder(
          builder: (context) {
            final top = OmniTopBarOverlap.of(context);
            return RefreshIndicator.adaptive(
              edgeOffset: top,
              onRefresh: () async {
                ref.invalidate(hrApprovalsProvider);
                await ref
                    .read(hrApprovalsProvider.future)
                    .then((_) {}, onError: (_) {});
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: hrListPadding(context, top),
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
                      onRetry: () => ref.invalidate(hrApprovalsProvider),
                    )
                  else if (!data.hasValue)
                    const OmniSkeletonBox(height: 220, radius: 18)
                  else if (list.isEmpty)
                    OmniGroupSection(
                      children: [
                        OmniGroupRow(
                          title: _tab == 0
                              ? 'Không còn đơn chờ'
                              : 'Chưa có đơn đã xử lý',
                        ),
                      ],
                    )
                  else
                    OmniGroupSection(
                      children: [
                        for (final r in list)
                          OmniGroupRow(
                            leading: HrInitialTile(r.name ?? ''),
                            title: r.name ?? '—',
                            subtitle: '${r.typeLabel} · ${r.detail}',
                            trailing: r.pending
                                ? HrValue(HrFormat.hm(r.createdAt) ?? '')
                                : hrRequestPill(r.status),
                            onTap: r.pending ? () => _open(r) : null,
                          ),
                      ],
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _open(HrRequest r) async {
    final decision = await showOmniSheet<bool>(
      context: context,
      builder: (sheet) => OmniSheetBody(
        semanticsLabel: r.typeLabel,
        header: OmniSheetHeader(
          title: r.typeLabel,
          subtitle: [
            r.name ?? '',
            if (r.sentLabel.isNotEmpty) 'gửi ${r.sentLabel}',
          ].where((s) => s.isNotEmpty).join(' · '),
        ),
        footer: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                key: const ValueKey('hr-reject'),
                onPressed: () => Navigator.of(sheet).pop(false),
                child: const Text('Từ chối'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(
                key: const ValueKey('hr-approve'),
                onPressed: () => Navigator.of(sheet).pop(true),
                child: const Text('Duyệt'),
              ),
            ),
          ],
        ),
        children: [
          OmniGroupSection(
            dividerIndent: 14,
            children: [
              HrStatRow(
                title: r.type == HrRequestType.tamung ? 'Số tiền' : 'Ngày',
                value: r.detail,
                strong: true,
              ),
              if (r.reason != null)
                OmniGroupRow(title: 'Lý do', subtitle: r.reason),
              if (r.type == HrRequestType.tamung && r.payrollPeriod != null)
                HrStatRow(
                  title: 'Trừ vào lương',
                  value: HrFormat.monthLabel(r.payrollPeriod!),
                ),
            ],
          ),
        ],
      ),
    );
    if (decision == null || !mounted) return;
    String? note;
    if (!decision) {
      note = await showOmniPrompt(
        context: context,
        title: 'Từ chối đơn',
        hintText: 'Lý do từ chối',
        confirmLabel: 'Từ chối',
        maxLength: 500,
      );
      if (note == null || !mounted) return;
    }
    try {
      await ref
          .read(hrApiProvider)
          .decide(
            r.id,
            approve: decision,
            note: note?.trim().isEmpty ?? true ? null : note!.trim(),
          );
      ref.invalidate(hrApprovalsProvider);
      if (mounted) {
        hrToast(
          context,
          '${decision ? 'Đã duyệt' : 'Đã từ chối'} · ${(r.name ?? '').split(' ').last}',
        );
      }
    } on AppException catch (e) {
      if (mounted) hrToast(context, e.message);
    }
  }
}
