import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../../design/components/components.dart';
import '../../../design/platform/omni_motion_scope.dart';
import '../../../design/tokens/tokens.dart';
import '../../customers/routes.dart';
import '../../team/team.dart';
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

    // Liquid (đợt 2): nền xám, tên + số tiền một nhóm, dải giai đoạn nhóm thứ
    // hai, "Thông tin" nhóm lồng có vạch thụt, ghi chú nhóm riêng.
    return Scaffold(
      appBar: OmniAppBar(
        title: 'Chi tiết cơ hội',
        fallbackBack: () => context.go('/opportunities'),
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
        data: (data) => RefreshIndicator.adaptive(
          onRefresh: () =>
              ref.refresh(opportunityProvider(opportunityId).future),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              16,
              12,
              16,
              OmniSpacing.bottomSafe,
            ),
            children: [
              OmniGroupSection(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
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
                          // Số tiền là DỮ LIỆU, chữ mực — màu chính chỉ cho
                          // hành động.
                          style: OmniType.moneyHero.copyWith(
                            color: scheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: OmniGroupSection.gap),
              OmniGroupSection(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 16, 12, 14),
                    child: _StageStepper(
                      opportunity: data,
                      pipeline: catalog?.pipelineOf(data.pipelineCode),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: OmniGroupSection.gap),
              OmniGroupSection(
                title: 'Thông tin',
                dividerIndent: 54,
                children: [
                  OmniGroupRow(
                    icon: Icons.person_outline_rounded,
                    title: 'Khách hàng',
                    value: data.customerName ?? '—',
                    onTap: data.customerId == null
                        ? null
                        : () => context.pushNamed(
                            CustomerRoutes.detail,
                            pathParameters: {'id': data.customerId!},
                          ),
                  ),
                  OmniGroupRow(
                    icon: Icons.inventory_2_outlined,
                    title: 'Sản phẩm',
                    value: data.product ?? '—',
                  ),
                  OmniGroupRow(
                    icon: Icons.donut_large_rounded,
                    title: 'Xác suất',
                    value:
                        '${data.displayPercent(catalog?.pipelineOf(data.pipelineCode))}%',
                  ),
                  OmniGroupRow(
                    icon: Icons.calendar_today_outlined,
                    title: 'Dự kiến chốt',
                    trailing: Text(
                      Formatters.date(data.expectedCloseAt),
                      style: OmniType.bodySm.copyWith(
                        color: data.isOverdue
                            ? OmniColors.dangerTextOf(context)
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  OmniGroupRow(
                    icon: Icons.badge_outlined,
                    title: 'Phụ trách',
                    value: _ownerLabel(ref, data),
                  ),
                  OmniGroupRow(
                    icon: Icons.payments_outlined,
                    title: 'Giá trị kỳ vọng',
                    trailing: Text(
                      Formatters.vnd(
                        data.weightedValue(
                          catalog?.pipelineOf(data.pipelineCode),
                        ),
                      ),
                      style: OmniType.body.copyWith(
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                        fontFeatures: OmniType.tabular,
                      ),
                    ),
                  ),
                ],
              ),
              if (data.notes.isNotEmpty) ...[
                const SizedBox(height: OmniGroupSection.gap),
                OmniGroupSection(
                  title: 'Ghi chú',
                  trailingTitle: Text(
                    '${data.notes.length}',
                    style: OmniType.caption.copyWith(
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurfaceVariant,
                      fontFeatures: OmniType.tabular,
                    ),
                  ),
                  dividerIndent: 14,
                  children: [
                    for (final note in data.notes)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
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
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
      bottomNavigationBar: _actionBar(
        context,
        ref,
        canUpdate: access.canUpdate,
        data: opportunity.valueOrNull,
      ),
    );
  }

  /// Đợt 5 (OPP-X2): cơ hội đã HUỶ thì API từ chối (422) cả Thắng lẫn đổi giai
  /// đoạn — không bày nút nào ra. Đã Thắng/Thua thì như web: không còn "Đánh
  /// dấu thắng", nhưng vẫn "Đổi giai đoạn" — đó là đường mở lại cơ hội.
  Widget? _actionBar(
    BuildContext context,
    WidgetRef ref, {
    required bool canUpdate,
    required Opportunity? data,
  }) {
    if (!canUpdate || (data?.isCancelled ?? false)) return null;
    final closed = data?.isClosed ?? false;

    // Viên kính nổi, hai nút kính theo theme (không viền xanh).
    return Padding(
      padding: EdgeInsets.fromLTRB(
        12,
        8,
        12,
        14 + MediaQuery.paddingOf(context).bottom,
      ),
      child: OmniGlass(
        radius: 30,
        padding: const EdgeInsets.all(7),
        child: Row(
          children: [
            if (!closed) ...[
              OutlinedButton(
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 46)),
                onPressed: () => _markWon(context, ref),
                child: const Text('Đánh dấu thắng'),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: FilledButton(
                onPressed: () => _moveStage(context, ref),
                child: const Text('Đổi giai đoạn'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _moveStage(BuildContext context, WidgetRef ref) async {
    final current = ref.read(opportunityProvider(opportunityId)).valueOrNull;
    if (current == null) return;
    HapticFeedback.selectionClick();

    try {
      final stage = await pickOpportunityStage(context, ref, current);
      if (stage == null) return;
      HapticFeedback.selectionClick();
      await moveOpportunityStage(ref, current, stage.code);
    } on AppException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  /// Người phụ trách là `owner_user_id`, tên tra trong danh bạ. `metadata.
  /// owner_name` không ai ghi (OPP-X7) — chỉ còn là dự phòng cho bản ghi cũ.
  /// Có người phụ trách mà không tra được tên thì "—", không nói "Chưa gán".
  static String _ownerLabel(WidgetRef ref, Opportunity data) {
    final ownerId = data.ownerId;
    if (ownerId == null || ownerId.isEmpty) return data.ownerName ?? 'Chưa gán';
    // Tra MỘT tên (`teamUserNameProvider`), không kéo cả danh bạ (review I2).
    return ref.watch(teamUserNameProvider(ownerId)).valueOrNull ??
        data.ownerName ??
        '—';
  }

  Future<void> _markWon(BuildContext context, WidgetRef ref) async {
    HapticFeedback.selectionClick();
    final confirmed = await showOmniConfirm(
      context: context,
      title: 'Đánh dấu thắng?',
      message:
          'Cơ hội sẽ chuyển sang Thắng và tạo đơn hàng. Doanh thu chỉ tính khi ghi nhận thu tiền.',
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
    final motion = OmniMotion.of(context);

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
                  child: AnimatedContainer(
                    duration: motion.fast,
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
                          ? scheme.primary
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
    final motion = OmniMotion.of(context);

    return AnimatedContainer(
      duration: motion.fast,
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
