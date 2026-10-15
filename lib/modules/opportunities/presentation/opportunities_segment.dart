import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/module/extra_segment.dart';
import '../../../core/utils/formatters.dart';
import '../../../design/components/components.dart';
import '../../../design/platform/omni_motion_scope.dart';
import '../../../design/tokens/tokens.dart';
import '../../../security/permissions/access_scope.dart';
import '../../../security/session/session_controller.dart';
import '../application/opportunities_providers.dart';
import '../domain/pipeline_catalog.dart';
import '../opportunities_module.dart';
import 'widgets/opportunity_row.dart';
import 'widgets/stage_strip.dart';

/// Thân của đoạn "Cơ hội": panel lọc (khi mở), dải ô giai đoạn, dòng mục và
/// danh sách có vòng %. Không có Scaffold — nhúng được vào màn Khách lẫn
/// [PipelinePage].
///
/// Cột là giai đoạn THẬT của quy trình tenant (`/pipelines`), không phải danh
/// sách cố định.
class OpportunitiesSegment extends ConsumerStatefulWidget {
  const OpportunitiesSegment({super.key, this.filtersOpen = false});

  /// Panel lọc (đổi quy trình, "Của tôi") đang mở.
  final bool filtersOpen;

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

    return Column(
      children: [
        OpportunityFilterPanel(open: widget.filtersOpen),
        Expanded(
          child: pipeline == null || pipeline.openStages.isEmpty
              ? OmniAsyncView(
                  value: catalog,
                  onRetry: () => ref.invalidate(pipelineCatalogProvider),
                  data: (_) => const OmniEmptyState(
                    icon: Icons.trending_up_rounded,
                    title: 'Quy trình chưa có giai đoạn',
                    message: 'Thêm giai đoạn cho quy trình bán hàng trên web.',
                  ),
                )
              : _Body(pipeline: pipeline, controller: _scrollController),
        ),
      ],
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
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
    } else if (data.items.isEmpty) {
      status = OmniEmptyState(
        icon: Icons.trending_up_rounded,
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

    return RefreshIndicator(
      onRefresh: () =>
          ref.read(segmentOpportunitiesProvider.notifier).refresh(),
      child: ListView.builder(
        controller: controller,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: OmniSpacing.bottomSafe),
        itemCount: 2 + tail,
        itemBuilder: (context, index) {
          if (index == 0) {
            return StageStrip(
              stages: closed ? closedStages : pipeline.openStages,
              summary: summary,
              selected: stageCode,
              onSelected: (code) {
                // Đã đóng: luôn có một giai đoạn được chọn, chạm lại không bỏ.
                if (closed && code == null) return;
                ref.read(segmentStageProvider.notifier).state = code;
              },
            );
          }
          if (index == 1) {
            return _SectionLine(
              title: [
                stage?.label ?? 'Đang mở',
                '$total',
                if (value > 0) Formatters.vndCompact(value),
              ].join(' · '),
              filtered: !closed && stageCode != null,
              onClear: () =>
                  ref.read(segmentStageProvider.notifier).state = null,
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
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          }
          return OpportunityRow(
            opportunity: items[at],
            pipeline: pipeline,
            canMove: access.canUpdate,
          );
        },
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
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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

/// Hàng tìm của đoạn "Cơ hội": ô tìm, nút lọc (huy hiệu đếm) và nút vuông
/// "Cơ hội mới" khi có quyền tạo. Cùng dáng với hàng tìm của danh sách khách.
class OpportunitySearchRow extends ConsumerWidget
    implements PreferredSizeWidget {
  const OpportunitySearchRow({
    super.key,
    required this.filtersOpen,
    this.onToggleFilters,
    this.onOpenFilters,
  }) : assert(onToggleFilters != null || onOpenFilters != null);

  final bool filtersOpen;
  final VoidCallback? onToggleFilters;
  final ValueChanged<Rect>? onOpenFilters;

  @override
  Size get preferredSize => const Size.fromHeight(46);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
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
      height: 46,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 2),
        child: Row(
          children: [
            const Expanded(child: _SearchField()),
            const SizedBox(width: 8),
            Builder(
              builder: (buttonContext) => _FilterButton(
                open: filtersOpen,
                count: count,
                onTap: () {
                  final anchored = onOpenFilters;
                  if (anchored == null) {
                    onToggleFilters?.call();
                    return;
                  }
                  final box = buttonContext.findRenderObject() as RenderBox?;
                  if (box == null || !box.hasSize) return;
                  anchored(box.localToGlobal(Offset.zero) & box.size);
                },
              ),
            ),
            if (access.canCreate) ...[
              IconButton(
                tooltip: 'Cơ hội mới',
                onPressed: () => context.pushNamed(OpportunitiesModule.create),
                style: IconButton.styleFrom(
                  fixedSize: const Size(36, 36),
                  tapTargetSize: MaterialTapTargetSize.padded,
                  visualDensity: VisualDensity.standard,
                  foregroundColor: scheme.onSurface,
                  backgroundColor: Colors.transparent,
                ),
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SearchField extends ConsumerStatefulWidget {
  const _SearchField();

  @override
  ConsumerState<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends ConsumerState<_SearchField> {
  late final TextEditingController _controller;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: ref.read(pipelineSearchProvider));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _changed(String value) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) ref.read(pipelineSearchProvider.notifier).state = value;
    });
  }

  void _clear() {
    _debounce?.cancel();
    _controller.clear();
    setState(() {});
    ref.read(pipelineSearchProvider.notifier).state = '';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final meta = scheme.onSurfaceVariant;

    return SizedBox(
      key: const Key('opportunity-search-flat'),
      height: 44,
      child: Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Row(
          children: [
            Icon(Icons.search_rounded, size: OmniIconSize.md, color: meta),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _controller,
                onChanged: _changed,
                textInputAction: TextInputAction.search,
                style: OmniType.search.copyWith(
                  color: scheme.onSurface,
                  fontStyle: FontStyle.normal,
                ),
                decoration: InputDecoration(
                  isDense: true,
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  hintText: 'Tìm cơ hội, khách hàng',
                  hintStyle: OmniType.searchHint.copyWith(color: meta),
                ),
              ),
            ),
            if (_controller.text.isNotEmpty)
              IconButton(
                tooltip: 'Xoá tìm kiếm',
                onPressed: _clear,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 44,
                  height: 44,
                ),
                iconSize: OmniIconSize.md,
                color: meta,
                icon: const Icon(Icons.close_rounded),
              )
            else
              const SizedBox(width: 10),
          ],
        ),
      ),
    );
  }
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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Icon phẳng, vùng chạm 44.
    return Semantics(
      button: true,
      label: 'Bộ lọc',
      expanded: open,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox.square(
          dimension: 44,
          child: Material(
            color: Colors.transparent,
            child: InkResponse(
              onTap: onTap,
              radius: 22,
              containedInkWell: true,
              highlightShape: BoxShape.circle,
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    Icons.tune_rounded,
                    size: OmniIconSize.md,
                    color: open ? scheme.primary : scheme.onSurface,
                  ),
                  if (count > 0)
                    Positioned(
                      right: 2,
                      top: 2,
                      child: IgnorePointer(
                        child: Container(
                          key: const Key('opportunity-filter-count'),
                          constraints: const BoxConstraints(minWidth: 16),
                          height: 16,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: OmniColors.destructive,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: scheme.surface,
                              width: 1.5,
                            ),
                          ),
                          child: Text(
                            '$count',
                            style: OmniType.micro.copyWith(
                              color: Colors.white,
                              height: 1,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Panel lọc của đoạn: đổi quy trình (khi có hơn một) và "Của tôi". Đóng thì
/// cao 0.
class OpportunityFilterPanel extends ConsumerWidget {
  const OpportunityFilterPanel({super.key, required this.open});

  final bool open;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!OmniMotion.enabled(context)) {
      return open ? const _PanelBody() : const SizedBox(width: double.infinity);
    }
    return AnimatedSize(
      duration: const Duration(milliseconds: 400),
      curve: OmniCurves.standard,
      alignment: Alignment.topCenter,
      child: open
          ? TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 300),
              builder: (context, value, child) =>
                  Opacity(opacity: value, child: child),
              child: const _PanelBody(),
            )
          : const SizedBox(width: double.infinity),
    );
  }
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
      Container(
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.only(left: 16, right: 6),
        color: Theme.of(
          menuContext,
        ).colorScheme.surfaceContainerLow.withValues(alpha: .7),
        child: Row(
          children: [
            Icon(
              Icons.tune_rounded,
              size: OmniIconSize.md,
              color: Theme.of(menuContext).colorScheme.primary,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text('Bộ lọc', style: OmniType.bodyStrong)),
            IconButton(
              tooltip: 'Đóng bộ lọc',
              onPressed: () => Navigator.of(menuContext).pop(),
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
      ),
      const OpportunityFilterMenuContent(),
      const SizedBox(height: 8),
    ],
  ),
);

/// Bản gọn của bộ lọc Cơ hội để đặt trong popover neo.
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
              icon: Icons.account_tree_outlined,
              label: 'Quy trình',
              value: pipeline.label,
              onTap: () => _pickOpportunityPipeline(
                context,
                ref,
                pipelines,
                pipeline.code,
              ),
            ),
          _OpportunityMenuRow(
            icon: Icons.person_outline_rounded,
            label: 'Chỉ cơ hội của tôi',
            selected: mine,
            onTap: () => ref.read(pipelineMineProvider.notifier).state = !mine,
          ),
          if (hasClosedStage)
            _OpportunityMenuRow(
              icon: Icons.inventory_2_outlined,
              label: 'Cơ hội đã đóng',
              selected: closed,
              onTap: () =>
                  ref.read(segmentClosedProvider.notifier).state = !closed,
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
    return Material(
      color: active
          ? scheme.primary.withValues(alpha: .08)
          : Colors.transparent,
      borderRadius: OmniRadius.mdAll,
      child: InkWell(
        onTap: onTap,
        borderRadius: OmniRadius.mdAll,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: OmniIconSize.md,
                  color: active ? scheme.primary : scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: OmniType.body.copyWith(
                      color: scheme.onSurface,
                      fontWeight: active ? FontWeight.w600 : FontWeight.w400,
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
                    Icons.chevron_right_rounded,
                    size: OmniIconSize.md,
                    color: scheme.onSurfaceVariant,
                  ),
                ] else
                  Icon(
                    active ? Icons.check_circle_rounded : Icons.circle_outlined,
                    size: OmniIconSize.md,
                    color: active ? scheme.primary : scheme.onSurfaceVariant,
                  ),
              ],
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

class _PanelBody extends ConsumerWidget {
  const _PanelBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final pipeline = ref.watch(boardPipelineProvider);
    final pipelines =
        ref.watch(pipelineCatalogProvider).valueOrNull?.pipelines ??
        const <PipelineDef>[];
    final mine = ref.watch(pipelineMineProvider);
    final closed = ref.watch(segmentClosedProvider);
    final hasClosedStage = pipeline?.stages.any((s) => s.isClosed) ?? false;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          if (pipelines.length > 1 && pipeline != null)
            OmniFilterPill(
              label: pipeline.label,
              selected: false,
              onTap: () =>
                  _pickPipeline(context, ref, pipelines, pipeline.code),
            ),
          OmniFilterPill(
            label: 'Của tôi',
            selected: mine,
            onTap: () => ref.read(pipelineMineProvider.notifier).state = !mine,
          ),
          // Xem cơ hội đã thắng/thua thay vì đang mở.
          if (hasClosedStage)
            OmniFilterPill(
              label: 'Đã đóng',
              selected: closed,
              onTap: () =>
                  ref.read(segmentClosedProvider.notifier).state = !closed,
            ),
        ],
      ),
    );
  }

  Future<void> _pickPipeline(
    BuildContext context,
    WidgetRef ref,
    List<PipelineDef> pipelines,
    String current,
  ) async {
    final container = ProviderScope.containerOf(context);
    final code = await showOmniSheet<String>(
      context: context,
      builder: (_) =>
          PipelinePickerSheet(pipelines: pipelines, current: current),
    );
    if (code == null || code == current) return;
    container.read(selectedPipelineProvider.notifier).state = code;
  }
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
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: OmniSpacing.xxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Text(
              'Quy trình bán hàng',
              style: OmniType.navTitle.copyWith(
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
              ),
            ),
          ),
          for (final pipeline in pipelines)
            Material(
              color: pipeline.code == current
                  ? scheme.primary.withValues(alpha: 0.05)
                  : Colors.transparent,
              child: InkWell(
                onTap: () => Navigator.pop(context, pipeline.code),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          pipeline.label,
                          style: OmniType.listTitle.copyWith(
                            fontWeight: pipeline.code == current
                                ? FontWeight.w600
                                : FontWeight.w500,
                            color: pipeline.code == current
                                ? scheme.onPrimaryContainer
                                : scheme.onSurface,
                          ),
                        ),
                      ),
                      if (pipeline.code == current)
                        Icon(
                          Icons.check_rounded,
                          color: scheme.onPrimaryContainer,
                        ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
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
  body: (_) => const OpportunitiesSegment(
    key: ValueKey('khach-seg-co-hoi'),
    filtersOpen: false,
  ),
);
