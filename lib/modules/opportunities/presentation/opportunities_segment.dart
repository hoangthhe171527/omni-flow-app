import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/module/extra_segment.dart';
import '../../../core/utils/formatters.dart';
import '../../../design/components/components.dart';
import '../../../design/tokens/tokens.dart';
import '../../../security/permissions/access_scope.dart';
import '../../../security/session/session_controller.dart';
import '../application/opportunities_providers.dart';
import '../domain/opportunity.dart';
import '../domain/pipeline_catalog.dart';
import '../opportunities_module.dart';
import 'widgets/opportunity_row.dart';
import 'widgets/stage_strip.dart';

/// Thân của đoạn "Cơ hội": dải ô giai đoạn, dòng mục và danh sách có vòng %.
/// Bộ lọc mở bằng menu neo ([showOpportunityFilterMenu]). Không có Scaffold — nhúng được vào màn Khách lẫn
/// [PipelinePage].
///
/// Cột là giai đoạn THẬT của quy trình tenant (`/pipelines`), không phải danh
/// sách cố định.
class OpportunitiesSegment extends ConsumerStatefulWidget {
  const OpportunitiesSegment({super.key});

  @override
  ConsumerState<OpportunitiesSegment> createState() =>
      _OpportunitiesSegmentState();
}

class _OpportunitiesSegmentState extends ConsumerState<OpportunitiesSegment> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_loadMore);
    // Danh mục quy trình đã nạp từ lần mở trước: đọc lại, vì web có thể vừa
    // thêm/đổi giai đoạn (APP-I12). Lần mở đầu thì provider đang nạp rồi.
    if (ref.exists(pipelineCatalogProvider)) {
      Future.microtask(() {
        if (mounted) ref.invalidate(pipelineCatalogProvider);
      });
    }
  }

  void _loadMore() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.extentAfter < 400) {
      ref.read(segmentOpportunitiesProvider.notifier).loadMore();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(pipelineCatalogProvider);
    final pipeline = ref.watch(boardPipelineProvider);
    final canCreate = ref.watch(opportunityAccessProvider).canCreate;

    // Cơ hội mới: nút + kính góc phải dưới (rà soát 12/11), không nằm trong ô
    // tìm nữa.
    return OmniFabLayer(
      fab: canCreate
          ? OmniLiquidFab(
              tooltip: 'Cơ hội mới',
              onPressed: (_) => context.pushNamed(OpportunitiesModule.create),
            )
          : null,
      body: Column(
        children: [
          Expanded(
            child: pipeline == null || pipeline.openStages.isEmpty
                ? OmniAsyncView(
                    value: catalog,
                    onRetry: () => ref.invalidate(pipelineCatalogProvider),
                    data: (_) => const OmniEmptyState(
                      icon: LucideIcons.trendingUp,
                      title: 'Quy trình chưa có giai đoạn',
                      message:
                          'Thêm giai đoạn cho quy trình bán hàng trên web.',
                    ),
                  )
                : _Body(pipeline: pipeline, controller: _scrollController),
          ),
        ],
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.pipeline, required this.controller});

  final PipelineDef pipeline;
  final ScrollController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final closed = ref.watch(segmentClosedProvider);
    final picked = ref.watch(segmentStageProvider);
    final closedStages = pipeline.stages.where((s) => s.isClosed).toList();
    // Chế độ đã đóng luôn nhắm một giai đoạn đóng (mặc định cái đầu).
    final stageCode = closed
        ? (picked ?? closedStages.firstOrNull?.code)
        : picked;
    final summary = ref.watch(pipelineSummaryProvider).valueOrNull;
    final list = ref.watch(segmentOpportunitiesProvider);
    final access = ref.watch(opportunityAccessProvider);
    final stage = pipeline.stage(stageCode);
    final data = list.valueOrNull;

    // Số hiển thị: tổng của danh sách đã nạp, chưa có thì lấy từ tóm tắt.
    final total =
        data?.pagination.total ??
        (stage == null
            ? summary?.openCount(pipeline)
            : summary?.totalFor(stage.code).count) ??
        0;
    // Tổng tiền: của giai đoạn đang lọc, hoặc của mọi giai đoạn mở.
    final value = summary == null
        ? 0.0
        : (stage == null
              ? summary.openValue(pipeline)
              : summary.totalFor(stage.code).value);

    final Widget? status;
    if (data == null) {
      status = list.hasError
          ? OmniErrorView(
              error: list.error!,
              onRetry: () => ref.invalidate(segmentOpportunitiesProvider),
            )
          : const Padding(
              padding: EdgeInsets.all(OmniSpacing.xl),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                ),
              ),
            );
    } else if (data.items.isEmpty) {
      status = OmniEmptyState(
        icon: LucideIcons.trendingUp,
        title: stage == null
            ? 'Chưa có cơ hội đang mở'
            : 'Chưa có cơ hội ở "${stage.label}"',
        message: 'Cơ hội mới hoặc vừa chuyển giai đoạn sẽ hiện ở đây.',
      );
    } else {
      status = null;
    }
    final items = data?.items ?? const [];
    final tail = status != null ? 1 : items.length + (data!.hasMore ? 1 : 0);

    return RefreshIndicator.adaptive(
      onRefresh: () =>
          ref.read(segmentOpportunitiesProvider.notifier).refresh(),
      child: ListView.builder(
        controller: controller,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.only(
          bottom: OmniFabLayer.listBottom(context, hasFab: access.canCreate),
        ),
        itemCount: 2 + tail,
        itemBuilder: (context, index) {
          if (index == 0) {
            return StageStrip(
              stages: closed ? closedStages : pipeline.openStages,
              summary: summary,
              // Chip "Tất cả" chỉ khi xem giai đoạn mở; đã đóng luôn nhắm
              // một giai đoạn.
              allCount: closed ? null : summary?.openCount(pipeline),
              showAll: !closed,
              selected: stageCode,
              onSelected: (code) {
                // Đã đóng: luôn có một giai đoạn được chọn, chạm lại không bỏ.
                if (closed && code == null) return;
                ref.read(segmentStageProvider.notifier).state = code;
              },
            );
          }
          if (index == 1 && !closed && stage == null && summary != null) {
            // Khối tổng chuẩn (Chuẩn Mobile UI — TotalCard, Đợt B): một số
            // chính + thanh tỉ lệ theo TIỀN của từng giai đoạn mở; số phụ là
            // hai giai đoạn cuối, chạm để lọc đúng giai đoạn đó.
            final open = pipeline.openStages;
            final tail2 = open.length <= 2
                ? open
                : open.sublist(open.length - 2);
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
              child: OmniTotalCard(
                key: const ValueKey('opp-total'),
                label: 'Đang mở',
                trailingLabel: '$total cơ hội',
                amount: Formatters.vnd(value),
                stats: [
                  for (final s in tail2.reversed)
                    OmniTotalStat(
                      value: Formatters.vnd(summary.totalFor(s.code).value),
                      label: s.label,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        ref.read(segmentStageProvider.notifier).state = s.code;
                      },
                    ),
                ],
                child: value > 0
                    ? _StageBar(stages: open, summary: summary)
                    : null,
              ),
            );
          }
          if (index == 1) {
            return _SectionLine(
              title: [
                stage?.label ?? 'Đang mở',
                '$total',
                if (value > 0) Formatters.vnd(value),
              ].join(' · '),
              filtered: !closed && stageCode != null,
              onClear: () {
                HapticFeedback.selectionClick();
                ref.read(segmentStageProvider.notifier).state = null;
              },
              color: scheme.onSurfaceVariant,
            );
          }
          if (status != null) return status;
          final at = index - 2;
          if (at >= items.length) {
            return const Padding(
              padding: EdgeInsets.all(OmniSpacing.lg),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                ),
              ),
            );
          }
          // Nhóm lồng (viomni-apple-uiux.html "Cơ hội" `.group`): danh sách
          // là một thẻ bo 16 cách mép 16 trên nền xám.
          const r = Radius.circular(16);
          final last = at == items.length - 1 && tail == items.length;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ClipRRect(
              borderRadius: BorderRadius.vertical(
                top: at == 0 ? r : Radius.zero,
                bottom: last ? r : Radius.zero,
              ),
              child: OpportunityRow(
                opportunity: items[at],
                pipeline: pipeline,
                canMove: access.canUpdate,
                divider: at > 0,
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Thanh tỉ lệ theo tiền của các giai đoạn mở: nhạt → đậm dần về giai đoạn
/// cuối (gần chốt). Trình đọc màn hình đọc tiền từng giai đoạn.
class _StageBar extends StatelessWidget {
  const _StageBar({required this.stages, required this.summary});

  final List<PipelineStageDef> stages;
  final PipelineSummary summary;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final parts = [
      for (final s in stages)
        if (summary.totalFor(s.code).value > 0)
          (s, summary.totalFor(s.code).value),
    ];
    final n = parts.length;
    return Semantics(
      label: [
        for (final (s, v) in parts) '${s.label} ${Formatters.vnd(v)}',
      ].join(', '),
      excludeSemantics: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: SizedBox(
          height: 8,
          child: Row(
            children: [
              for (var i = 0; i < n; i++) ...[
                if (i > 0) const SizedBox(width: 2),
                Expanded(
                  flex: (parts[i].$2 / 1000).round().clamp(1, 1 << 30),
                  child: ColoredBox(
                    // Không bấm được → thang chữ phụ → mực (mọi đoạn ≥ 3:1),
                    // không màu nhấn.
                    color: Color.lerp(
                      scheme.onSurfaceVariant,
                      scheme.onSurface,
                      n == 1 ? 1 : i / (n - 1),
                    )!,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLine extends StatelessWidget {
  const _SectionLine({
    required this.title,
    required this.filtered,
    required this.onClear,
    required this.color,
  });

  final String title;
  final bool filtered;
  final VoidCallback onClear;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 8, 0),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Row(
          children: [
            Expanded(
              // Số tiền không cắt "…": hẹp / chữ lớn thì xuống dòng 2.
              child: Text(
                title,
                maxLines: 2,
                style: OmniType.micro.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontFeatures: OmniType.tabular,
                ),
              ),
            ),
            if (filtered)
              TextButton(
                onPressed: onClear,
                style: TextButton.styleFrom(
                  minimumSize: const Size(44, 44),
                  foregroundColor: scheme.primary,
                ),
                child: const Text('Bỏ lọc'),
              ),
          ],
        ),
      ),
    );
  }
}

/// Hàng tìm của đoạn "Cơ hội": ô tìm và nút lọc (huy hiệu đếm). "Cơ hội mới"
/// là nút + kính của [OpportunitiesSegment]. Cùng dáng với hàng tìm khách.
class OpportunitySearchRow extends ConsumerWidget
    implements PreferredSizeWidget {
  const OpportunitySearchRow({
    super.key,
    required this.filtersOpen,
    required this.onOpenFilters,
  });

  final bool filtersOpen;
  final ValueChanged<Rect> onOpenFilters;

  @override
  // Nằm trong viên kính của OmniTopBar: cao 44, lề ngang nhỏ.
  Size get preferredSize => const Size.fromHeight(44);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final access = ref.watch(opportunityAccessProvider);
    final mine = ref.watch(pipelineMineProvider);
    final pipelineChosen = ref.watch(selectedPipelineProvider) != null;
    final defaultMine = access.readScope == AccessScope.own;
    final closed = ref.watch(segmentClosedProvider);
    final searching = ref.watch(pipelineSearchProvider).isNotEmpty;
    final count =
        (mine != defaultMine ? 1 : 0) +
        (pipelineChosen ? 1 : 0) +
        (closed ? 1 : 0) +
        (searching ? 1 : 0);

    return SizedBox(
      height: 44,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 0, 2, 0),
        child: Row(
          children: [
            const Expanded(child: _SearchField()),
            const SizedBox(width: 8),
            Builder(
              builder: (buttonContext) => _FilterButton(
                open: filtersOpen,
                count: count,
                onTap: () {
                  HapticFeedback.selectionClick();
                  final box = buttonContext.findRenderObject() as RenderBox?;
                  if (box == null || !box.hasSize) return;
                  onOpenFilters(box.localToGlobal(Offset.zero) & box.size);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ô tìm chuẩn (Chuẩn Mobile UI — SearchBar) theo `pipelineSearchProvider`.
class _SearchField extends ConsumerWidget {
  const _SearchField();

  @override
  Widget build(BuildContext context, WidgetRef ref) => OmniSearchField(
    key: const Key('opportunity-search-flat'),
    hint: 'Tìm cơ hội, khách hàng',
    // Gợi ý quay như máy đánh số (kiểu "Biến hình", duyệt 26/11/2026).
    hints: const [
      'Tìm cơ hội, khách hàng',
      'Tìm tên cơ hội…',
      'Tìm tên khách hàng…',
    ],
    flat: true,
    dense: true,
    debounce: const Duration(milliseconds: 300),
    value: ref.watch(pipelineSearchProvider),
    onChanged: (v) => ref.read(pipelineSearchProvider.notifier).state = v,
  );
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({
    required this.open,
    required this.count,
    required this.onTap,
  });

  final bool open;
  final int count;
  final VoidCallback onTap;

  /// Nút lọc chung của ô tìm (duyệt 26/11/2026, rà soát mục 6): xám khi chưa
  /// lọc; đang lọc = viên mực/trắng đặc kèm số bộ lọc. Vùng chạm 44.
  @override
  Widget build(BuildContext context) => OmniSearchFilterButton(
    onPressed: onTap,
    activeFilters: count,
    open: open,
    semanticsLabel: 'Bộ lọc',
    countKey: const Key('opportunity-filter-count'),
  );
}

/// Mở bộ lọc Cơ hội tại đúng nút đã chạm. Dùng chung cho màn độc lập và đoạn
/// Cơ hội trong tab Khách để danh sách không bị đẩy xuống khi bật lọc.
Future<void> showOpportunityFilterMenu({
  required BuildContext context,
  required Rect anchor,
}) => showOmniAnchoredMenu<void>(
  context: context,
  anchor: anchor,
  width: 320,
  menuKey: const Key('opportunity-filter-menu'),
  semanticsLabel: 'Bộ lọc cơ hội',
  builder: (menuContext) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      // Đầu bảng lọc dùng chung như Khách / Hộp thư: "Lọc" + "Đặt lại".
      const _OpportunityFilterHeader(),
      const OpportunityFilterMenuContent(),
      const SizedBox(height: 8),
    ],
  ),
);

/// Bản gọn của bộ lọc Cơ hội để đặt trong popover neo.
/// "Đặt lại" bỏ "Chỉ của tôi" và "Đã đóng"; không có gì để đặt lại thì mờ.
class _OpportunityFilterHeader extends ConsumerWidget {
  const _OpportunityFilterHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active =
        ref.watch(pipelineMineProvider) || ref.watch(segmentClosedProvider);
    return OmniFilterHeader(
      resetKey: const Key('opportunity-filter-reset'),
      onReset: active
          ? () {
              ref.read(pipelineMineProvider.notifier).state = false;
              ref.read(segmentClosedProvider.notifier).state = false;
            }
          : null,
    );
  }
}

class OpportunityFilterMenuContent extends ConsumerWidget {
  const OpportunityFilterMenuContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pipeline = ref.watch(boardPipelineProvider);
    final pipelines =
        ref.watch(pipelineCatalogProvider).valueOrNull?.pipelines ??
        const <PipelineDef>[];
    final mine = ref.watch(pipelineMineProvider);
    final closed = ref.watch(segmentClosedProvider);
    final hasClosedStage = pipeline?.stages.any((s) => s.isClosed) ?? false;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (pipelines.length > 1 && pipeline != null)
            _OpportunityMenuRow(
              icon: LucideIcons.network,
              label: 'Quy trình',
              value: pipeline.label,
              onTap: () {
                HapticFeedback.selectionClick();
                _pickOpportunityPipeline(
                  context,
                  ref,
                  pipelines,
                  pipeline.code,
                );
              },
            ),
          _OpportunityMenuRow(
            icon: LucideIcons.user,
            label: 'Chỉ cơ hội của tôi',
            selected: mine,
            onTap: () {
              HapticFeedback.selectionClick();
              ref.read(pipelineMineProvider.notifier).state = !mine;
            },
          ),
          if (hasClosedStage)
            _OpportunityMenuRow(
              icon: LucideIcons.package,
              label: 'Cơ hội đã đóng',
              selected: closed,
              onTap: () {
                HapticFeedback.selectionClick();
                ref.read(segmentClosedProvider.notifier).state = !closed;
              },
            ),
        ],
      ),
    );
  }
}

class _OpportunityMenuRow extends StatelessWidget {
  const _OpportunityMenuRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.value,
    this.selected,
  });

  final IconData icon;
  final String label;
  final String? value;
  final bool? selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final active = selected == true;
    // Bật = ✓ xanh cuối dòng, không tô cả dòng (spec phong cách iOS §3.4);
    // tắt giữ vòng rỗng.
    return Semantics(
      button: true,
      selected: selected,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            customBorder: RoundedRectangleBorder(
              borderRadius: OmniRadius.mdAll,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                child: Row(
                  children: [
                    Icon(
                      icon,
                      size: OmniIconSize.md,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        label,
                        style: OmniType.body.copyWith(
                          color: scheme.onSurface,
                          fontWeight: active
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                    ),
                    if (value != null) ...[
                      Flexible(
                        child: Text(
                          value!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: OmniType.caption.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        LucideIcons.chevronRight,
                        size: OmniIconSize.md,
                        color: scheme.onSurfaceVariant,
                      ),
                    ] else
                      Icon(
                        active ? LucideIcons.check : LucideIcons.circle,
                        size: OmniIconSize.md,
                        color: active
                            ? scheme.primary
                            : scheme.onSurfaceVariant,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _pickOpportunityPipeline(
  BuildContext context,
  WidgetRef ref,
  List<PipelineDef> pipelines,
  String current,
) async {
  final container = ProviderScope.containerOf(context);
  final code = await showOmniSheet<String>(
    context: context,
    builder: (_) => PipelinePickerSheet(pipelines: pipelines, current: current),
  );
  if (code == null || code == current) return;
  container.read(selectedPipelineProvider.notifier).state = code;
}

/// Chọn quy trình khi tenant có nhiều hơn một. Trả về mã quy trình.
class PipelinePickerSheet extends StatelessWidget {
  const PipelinePickerSheet({
    super.key,
    required this.pipelines,
    required this.current,
  });

  final List<PipelineDef> pipelines;
  final String current;

  @override
  Widget build(BuildContext context) {
    return OmniSheetBody(
      // Đầu sheet tự có nút ✕ tròn xám (spec phong cách iOS §3.4).
      header: const OmniSheetHeader(title: 'Quy trình bán hàng'),
      children: [
        OmniGroupSection(
          dividerIndent: 14,
          children: [
            for (final pipeline in pipelines)
              OmniGroupRow(
                title: pipeline.label,
                selected: pipeline.code == current,
                chevron: false,
                onTap: () => Navigator.pop(context, pipeline.code),
              ),
          ],
        ),
      ],
    );
  }
}

/// Đoạn "Cơ hội" của tab Khách, cắm vào `khachExtraSegmentProvider` ở gốc app.
/// Chỉ hiện khi đọc được cơ hội VÀ workspace bật tính năng `opportunities`.
final opportunitiesKhachSegment = ExtraSegment(
  visible: (ref) =>
      ref.watch(opportunityAccessProvider).canRead &&
      ref.watch(sessionProvider).featureEnabled('opportunities'),
  label: (ref) {
    final pipeline = ref.watch(boardPipelineProvider);
    final summary = ref.watch(pipelineSummaryProvider).valueOrNull;
    if (pipeline == null || summary == null) return 'Cơ hội';
    return 'Cơ hội · ${summary.openCount(pipeline)}';
  },
  searchRow: (open, onOpen) =>
      OpportunitySearchRow(filtersOpen: open, onOpenFilters: onOpen),
  filterContent: () => const OpportunityFilterMenuContent(),
  body: (_) => const OpportunitiesSegment(key: ValueKey('khach-seg-co-hoi')),
);
