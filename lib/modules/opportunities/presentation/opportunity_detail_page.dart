import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../../design/components/components.dart';
import '../../../design/tokens/tokens.dart';
import '../../customers/routes.dart';
import '../application/opportunities_providers.dart';
import '../domain/opportunity.dart';
import '../domain/pipeline_catalog.dart';
import '../opportunities_module.dart';
import 'widgets/stage_picker_sheet.dart';

class OpportunityDetailPage extends ConsumerWidget {
  const OpportunityDetailPage({super.key, required this.opportunityId});

  final String opportunityId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final opportunity = ref.watch(opportunityProvider(opportunityId));
    final access = ref.watch(opportunityAccessProvider);
    final catalog = ref.watch(pipelineCatalogProvider).valueOrNull;
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
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    Formatters.vnd(data.value),
                    style: OmniType.moneyHero.copyWith(
                      fontWeight: FontWeight.w600,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 18),
                  _StageStepper(
                    opportunity: data,
                    pipeline: catalog?.pipelineOf(data.pipelineCode),
                  ),
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
                        value:
                            '${data.effectiveProbability(catalog?.pipelineOf(data.pipelineCode))}%',
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
                        value: Formatters.vnd(
                          data.weightedValue(
                            catalog?.pipelineOf(data.pipelineCode),
                          ),
                        ),
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

    try {
      final stage = await pickOpportunityStage(context, ref, current);
      if (stage == null) return;
      await moveOpportunityStage(ref, current, stage.code);
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
      final result = await ref
          .read(opportunityActionsProvider)
          .markWon(opportunityId);
      if (!context.mounted) return;
      // App chưa có màn đơn hàng nên không điều hướng — chỉ báo có đơn.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.orderCreated
                ? 'Đã đánh dấu thắng và tạo đơn hàng.'
                : result.orderId != null
                ? 'Đã đánh dấu thắng. Cơ hội đã có đơn hàng.'
                : 'Đã đánh dấu thắng.',
          ),
        ),
      );
    } on AppException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }
}

class _StageStepper extends StatelessWidget {
  const _StageStepper({required this.opportunity, required this.pipeline});

  final Opportunity opportunity;

  /// Quy trình của cơ hội; null khi danh mục chưa tải xong.
  final PipelineDef? pipeline;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // Thắng/thua theo `opportunity_status` của máy chủ — một quy trình tuỳ
    // biến gọi giai đoạn Thắng là `da_mua`, không phải `won`.
    if (opportunity.isCancelled) {
      return const OmniStatusChip(
        label: 'Đã huỷ',
        tone: OmniTone.neutral,
        icon: Icons.block_rounded,
      );
    }
    if (opportunity.isClosed) {
      final won = opportunity.isWon;
      return OmniStatusChip(
        label: won ? 'Đã thắng' : 'Đã thua',
        tone: won ? OmniTone.success : OmniTone.danger,
        icon: won ? Icons.emoji_events_outlined : Icons.cancel_outlined,
      );
    }

    // Won/lost are outcomes, not steps — the path a deal walks is the
    // pipeline's open stages.
    final path = pipeline?.openStages ?? const <PipelineStageDef>[];
    if (path.isEmpty) return const SizedBox(height: 46);
    final currentIndex = path.indexWhere(
      (stage) => stage.code == opportunity.stageCode,
    );

    // Dải giai đoạn: bước đã qua là chấm đặc có dấu tick, bước hiện tại là
    // vòng rỗng viền dày kèm quầng nhạt, bước sau là vòng mảnh. Đường nối
    // dày 3, tô màu chính tới bước hiện tại.
    return LayoutBuilder(
      builder: (context, constraints) => Row(
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
              // Quy trình nhiều giai đoạn mở hơn bốn vẫn vừa một hàng.
              width: math.min(64, constraints.maxWidth / path.length),
              child: Column(
                children: [
                  _Dot(state: i.compareTo(currentIndex)),
                  const SizedBox(height: 6),
                  Text(
                    path[i].label,
                    textAlign: TextAlign.center,
                    style: OmniType.micro.copyWith(
                      fontWeight: i == currentIndex
                          ? FontWeight.w600
                          : i < currentIndex
                          ? FontWeight.w500
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
      ),
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
