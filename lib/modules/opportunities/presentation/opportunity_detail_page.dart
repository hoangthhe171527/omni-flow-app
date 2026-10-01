import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../../design/components/components.dart';
import '../../../design/tokens/tokens.dart';
import '../../customers/routes.dart';
import '../application/opportunities_providers.dart';
import '../data/opportunities_api.dart';
import '../domain/opportunity.dart';
import '../opportunities_module.dart';
import 'widgets/stage_picker_sheet.dart';

class OpportunityDetailPage extends ConsumerWidget {
  const OpportunityDetailPage({super.key, required this.opportunityId});

  final String opportunityId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final opportunity = ref.watch(opportunityProvider(opportunityId));
    final access = ref.watch(opportunityAccessProvider);
    final scheme = Theme.of(context).colorScheme;

    // Bố cục `MOppDetail.dc.html`: khối trắng (tên, số tiền lớn, dải giai
    // đoạn), rồi trên nền xám là thẻ thông tin và ghi chú.
    return Scaffold(
      appBar: AppBar(
        backgroundColor: scheme.surface,
        title: const Text('Chi tiết cơ hội'),
        actions: [
          if (access.canUpdate)
            TextButton(
              onPressed: () => context.pushNamed(
                OpportunitiesModule.edit,
                pathParameters: {'id': opportunityId},
              ),
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 44),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              child: const Text('Sửa'),
            ),
        ],
      ),
      body: OmniAsyncView(
        value: opportunity,
        onRetry: () => ref.invalidate(opportunityProvider(opportunityId)),
        data: (data) => ListView(
          padding: const EdgeInsets.only(bottom: OmniSpacing.bottomSafe),
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
              decoration: BoxDecoration(
                color: scheme.surface,
                border: Border(
                  bottom: BorderSide(color: scheme.outlineVariant),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.title,
                    style: OmniType.title.copyWith(
                      fontWeight: FontWeight.w800,
                      height: 30 / 22,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    Formatters.vnd(data.value),
                    style: OmniType.moneyHero.copyWith(
                      fontWeight: FontWeight.w800,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 18),
                  _StageStepper(current: data.stage),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const OmniSectionHeader(
                    title: 'Thông tin',
                    padding: _headerPadding,
                  ),
                  OmniDetailCard(
                    rows: [
                      OmniDetailRow(
                        label: 'Khách hàng',
                        value: data.customerName ?? '—',
                        onTap: data.customerId == null
                            ? null
                            : () => context.pushNamed(
                                CustomerRoutes.detail,
                                pathParameters: {'id': data.customerId!},
                              ),
                      ),
                      OmniDetailRow(
                        label: 'Sản phẩm',
                        value: data.product ?? '—',
                      ),
                      OmniDetailRow(
                        label: 'Xác suất',
                        value: '${data.effectiveProbability}%',
                      ),
                      OmniDetailRow(
                        label: 'Dự kiến chốt',
                        value: Formatters.date(data.expectedCloseAt),
                        valueColor: data.isOverdue
                            ? OmniColors.dangerTextOf(context)
                            : null,
                      ),
                      OmniDetailRow(
                        label: 'Phụ trách',
                        value: data.ownerName ?? 'Chưa gán',
                      ),
                      OmniDetailRow(
                        label: 'Giá trị kỳ vọng',
                        value: Formatters.vnd(data.weightedValue),
                        strong: true,
                      ),
                    ],
                  ),
                  if (data.notes.isNotEmpty) ...[
                    const OmniSectionHeader(
                      title: 'Ghi chú',
                      padding: _headerPadding,
                    ),
                    for (final note in data.notes)
                      Padding(
                        padding: const EdgeInsets.only(bottom: OmniSpacing.sm),
                        child: OmniCard(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                note.content,
                                style: OmniType.bodyStrong.copyWith(
                                  fontWeight: FontWeight.w400,
                                  height: 22 / 15,
                                  color: scheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${note.author ?? "Thành viên"} · ${Formatters.relative(note.at)}',
                                style: OmniType.micro.copyWith(
                                  fontWeight: FontWeight.w400,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: access.canUpdate
          ? OmniActionBar(
              children: [
                OutlinedButton(
                  onPressed: () => _markWon(context, ref),
                  child: const Text('Đánh dấu thắng'),
                ),
                FilledButton(
                  onPressed: () => _moveStage(context, ref),
                  child: const Text('Đổi giai đoạn'),
                ),
              ],
            )
          : null,
    );
  }

  static const _headerPadding = EdgeInsets.only(
    top: OmniSpacing.lg,
    bottom: OmniSpacing.sm,
    left: OmniSpacing.xs,
  );

  Future<void> _moveStage(BuildContext context, WidgetRef ref) async {
    final current = ref.read(opportunityProvider(opportunityId)).valueOrNull;
    if (current == null) return;

    final stage = await showOmniSheet<PipelineStage>(
      context: context,
      builder: (_) => StagePickerSheet(current: current.stage),
    );
    if (stage == null || stage == current.stage) return;

    try {
      await moveOpportunityStage(ref, opportunityId, stage);
    } on AppException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _markWon(BuildContext context, WidgetRef ref) async {
    final confirmed = await showOmniConfirm(
      context: context,
      title: 'Đánh dấu thắng?',
      message: 'Cơ hội sẽ chuyển sang giai đoạn Thắng và tính vào doanh thu.',
      confirmLabel: 'Xác nhận',
    );
    if (!confirmed) return;

    try {
      await ref.read(opportunitiesApiProvider).markWon(opportunityId);
      ref.invalidate(opportunityProvider(opportunityId));
      ref.invalidate(pipelineSummaryProvider);
      ref.invalidate(stageOpportunitiesProvider);
    } on AppException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }
}

class _StageStepper extends StatelessWidget {
  const _StageStepper({required this.current});

  final PipelineStage current;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Won/lost are outcomes, not steps — the path a deal walks is the four
    // working stages.
    const path = [
      PipelineStage.fresh,
      PipelineStage.consulted,
      PipelineStage.quoted,
      PipelineStage.negotiating,
    ];
    final currentIndex = path.indexOf(current);

    if (current.isClosed) {
      return OmniStatusChip(
        label: current == PipelineStage.won ? 'Đã thắng' : 'Đã thua',
        tone: current == PipelineStage.won ? OmniTone.success : OmniTone.danger,
        icon: current == PipelineStage.won
            ? Icons.emoji_events_outlined
            : Icons.cancel_outlined,
      );
    }

    // Dải giai đoạn: bước đã qua là chấm đặc có dấu tick, bước hiện tại là
    // vòng rỗng viền dày kèm quầng nhạt, bước sau là vòng mảnh. Đường nối
    // dày 3, tô màu chính tới bước hiện tại.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < path.length; i++) ...[
          if (i > 0)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 10.5),
                child: Container(
                  height: 3,
                  color: i <= currentIndex
                      ? scheme.primary
                      : scheme.outlineVariant,
                ),
              ),
            ),
          SizedBox(
            width: 64,
            child: Column(
              children: [
                _Dot(state: i.compareTo(currentIndex)),
                const SizedBox(height: 6),
                Text(
                  path[i].label,
                  textAlign: TextAlign.center,
                  style: OmniType.micro.copyWith(
                    fontWeight: i == currentIndex
                        ? FontWeight.w800
                        : i < currentIndex
                        ? FontWeight.w600
                        : FontWeight.w400,
                    color: i == currentIndex
                        ? scheme.onPrimaryContainer
                        : i < currentIndex
                        ? scheme.onSurface
                        : scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.state});

  /// < 0 đã qua, 0 hiện tại, > 0 chưa tới.
  final int state;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: state < 0 ? scheme.primary : scheme.surface,
        border: state < 0
            ? null
            : Border.all(
                color: state == 0 ? scheme.primary : scheme.outlineVariant,
                width: state == 0 ? 3 : 2,
              ),
        boxShadow: state == 0
            ? [BoxShadow(color: scheme.primaryContainer, spreadRadius: 4)]
            : null,
      ),
      child: state < 0
          ? Icon(
              Icons.check_rounded,
              size: OmniIconSize.sm,
              color: scheme.onPrimary,
            )
          : null,
    );
  }
}
