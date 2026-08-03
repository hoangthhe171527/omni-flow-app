import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../../design/components/components.dart';
import '../../../design/tokens/tokens.dart';
import '../../customers/customers.dart';
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết cơ hội'),
        actions: [
          if (access.canUpdate)
            IconButton(
              tooltip: 'Sửa',
              onPressed: () => context.pushNamed(
                OpportunitiesModule.edit,
                pathParameters: {'id': opportunityId},
              ),
              icon: const Icon(Icons.edit_outlined, size: 20),
            ),
        ],
      ),
      body: OmniAsyncView(
        value: opportunity,
        onRetry: () => ref.invalidate(opportunityProvider(opportunityId)),
        data: (data) => ListView(
          padding: const EdgeInsets.fromLTRB(
            OmniSpacing.lg,
            OmniSpacing.md,
            OmniSpacing.lg,
            OmniSpacing.bottomSafe,
          ),
          children: [
            Text(
              data.title,
              style: OmniType.title.copyWith(color: scheme.onSurface),
            ),
            const SizedBox(height: OmniSpacing.sm),
            Text(
              Formatters.vnd(data.value),
              style: OmniType.moneyHero.copyWith(color: scheme.primary),
            ),
            const SizedBox(height: OmniSpacing.lg),
            _StageStepper(current: data.stage),
            const OmniSectionHeader(title: 'Thông tin', padding: _headerPadding),
            OmniCard(
              child: Column(
                children: [
                  OmniDetailRow(
                    label: 'Khách hàng',
                    value: data.customerName ?? '—',
                    icon: Icons.person_outline_rounded,
                    onTap: data.customerId == null
                        ? null
                        : () => context.pushNamed(
                              CustomersModule.detail,
                              pathParameters: {'id': data.customerId!},
                            ),
                  ),
                  OmniDetailRow(
                    label: 'Sản phẩm',
                    value: data.product ?? '—',
                    icon: Icons.inventory_2_outlined,
                  ),
                  OmniDetailRow(
                    label: 'Xác suất',
                    value: '${data.effectiveProbability}%',
                    icon: Icons.percent_rounded,
                  ),
                  OmniDetailRow(
                    label: 'Dự kiến chốt',
                    value: Formatters.date(data.expectedCloseAt),
                    icon: Icons.event_outlined,
                    valueColor: data.isOverdue ? scheme.error : null,
                  ),
                  OmniDetailRow(
                    label: 'Phụ trách',
                    value: data.ownerName ?? 'Chưa gán',
                    icon: Icons.badge_outlined,
                  ),
                  OmniDetailRow(
                    label: 'Giá trị kỳ vọng',
                    value: Formatters.vnd(data.weightedValue),
                    icon: Icons.calculate_outlined,
                  ),
                ],
              ),
            ),
            if (data.notes.isNotEmpty) ...[
              const OmniSectionHeader(title: 'Ghi chú', padding: _headerPadding),
              for (final note in data.notes)
                Padding(
                  padding: const EdgeInsets.only(bottom: OmniSpacing.sm),
                  child: OmniCard(
                    padding: const EdgeInsets.all(OmniSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(note.content, style: OmniType.body),
                        const SizedBox(height: OmniSpacing.xs),
                        Text(
                          '${note.author ?? "Thành viên"} · ${Formatters.relative(note.at)}',
                          style: OmniType.micro.copyWith(
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
      bottomNavigationBar: access.canUpdate
          ? OmniActionBar(
              children: [
                OutlinedButton(
                  onPressed: () => _markWon(context, ref),
                  child: const Text('Đánh dấu thắng'),
                ),
                FilledButton.icon(
                  onPressed: () => _moveStage(context, ref),
                  icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                  label: const Text('Đổi giai đoạn'),
                ),
              ],
            )
          : null,
    );
  }

  static const _headerPadding = EdgeInsets.only(
    top: OmniSpacing.xxl,
    bottom: OmniSpacing.md,
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
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _markWon(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Đánh dấu thắng?'),
        content: const Text(
          'Cơ hội sẽ chuyển sang giai đoạn Thắng và tính vào doanh thu.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Huỷ'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(opportunitiesApiProvider).markWon(opportunityId);
      ref.invalidate(opportunityProvider(opportunityId));
      ref.invalidate(pipelineSummaryProvider);
      ref.invalidate(stageOpportunitiesProvider);
    } on AppException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
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

    return Row(
      children: [
        for (var i = 0; i < path.length; i++) ...[
          if (i > 0)
            Expanded(
              child: Container(
                height: 2,
                color: i <= currentIndex ? scheme.primary : scheme.outline,
              ),
            ),
          Column(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: i <= currentIndex ? scheme.primary : scheme.surface,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: i <= currentIndex ? scheme.primary : scheme.outline,
                  ),
                ),
                child: i < currentIndex
                    ? const Icon(Icons.check_rounded, size: 13, color: Colors.white)
                    : null,
              ),
              const SizedBox(height: 4),
              Text(
                path[i].label,
                style: OmniType.micro.copyWith(
                  color: i <= currentIndex ? scheme.primary : scheme.onSurfaceVariant,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
