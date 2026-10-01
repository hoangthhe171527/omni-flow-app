import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/formatters.dart';
import '../../../design/components/components.dart';
import '../../../design/tokens/tokens.dart';
import '../application/opportunities_providers.dart';
import '../domain/opportunity.dart';
import '../domain/pipeline_catalog.dart';
import '../opportunities_module.dart';
import 'widgets/opportunity_card.dart';

/// The pipeline as a mobile board: one stage at a time, with the totals for
/// every stage always visible in the tab strip.
///
/// A desktop kanban doesn't survive a 390pt screen — six columns become six
/// unreadable slivers. Stage tabs keep the same mental model while giving each
/// card room to be read and acted on.
///
/// The columns are the tenant's REAL pipeline stages (`/pipelines`), not a
/// fixed list: a retail pipeline with "Đã mua" shows "Đã mua".
class PipelinePage extends ConsumerStatefulWidget {
  const PipelinePage({super.key});

  @override
  ConsumerState<PipelinePage> createState() => _PipelinePageState();
}

class _PipelinePageState extends ConsumerState<PipelinePage> {
  final _scrollController = ScrollController();

  /// The column the list is showing — what [_loadMore] pages.
  String? _stageCode;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_loadMore);
  }

  void _loadMore() {
    final code = _stageCode;
    if (code == null || !_scrollController.hasClients) return;
    if (_scrollController.position.extentAfter < 400) {
      ref.read(stageOpportunitiesProvider(code).notifier).loadMore();
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
    final selected = ref.watch(selectedStageProvider);
    final summary = ref.watch(pipelineSummaryProvider);
    final mine = ref.watch(pipelineMineProvider);
    final access = ref.watch(opportunityAccessProvider);
    final scheme = Theme.of(context).colorScheme;

    // A code from another pipeline (or none yet) → the first open stage.
    final stage = pipeline?.stage(selected) ?? pipeline?.firstStage;
    _stageCode = stage?.code;
    final pipelines = catalog.valueOrNull?.pipelines ?? const <PipelineDef>[];

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: OmniAppBar(
        backgroundColor: scheme.surface,
        title: 'Cơ hội',
        titleSpacing: OmniSpacing.lg,
        toolbarHeight: 56,
        // The headline number lives in the bar. It used to be one of two big
        // stat tiles in a band of its own, above a two-line tab strip that
        // already carried every stage's count and value — roughly 150px of
        // summary before a single opportunity appeared, most of it saying the
        // same thing twice.
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: OmniSpacing.lg),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  Formatters.vndCompact(
                    pipeline == null
                        ? 0
                        : summary.valueOrNull?.openValue(pipeline) ?? 0,
                  ),
                  style: OmniType.money.copyWith(
                    height: 1.1,
                    color: scheme.onSurface,
                  ),
                ),
                Text(
                  'đang mở',
                  style: OmniChatType.meta.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(51),
          child: Column(
            children: [
              _StageTabs(
                stages: pipeline?.stages ?? const [],
                selected: stage?.code,
                summary: summary.valueOrNull,
                onSelected: (code) =>
                    ref.read(selectedStageProvider.notifier).state = code,
                leading: [
                  if (pipelines.length > 1 && pipeline != null)
                    OmniFilterPill(
                      label: pipeline.label,
                      selected: false,
                      onTap: () => _pickPipeline(pipelines, pipeline.code),
                    ),
                  OmniFilterPill(
                    label: 'Của tôi',
                    selected: mine,
                    onTap: () =>
                        ref.read(pipelineMineProvider.notifier).state = !mine,
                  ),
                ],
              ),
              Divider(height: 1, thickness: 1, color: scheme.outlineVariant),
            ],
          ),
        ),
      ),
      floatingActionButton: access.canCreate
          ? FloatingActionButton.extended(
              onPressed: () => context.pushNamed(OpportunitiesModule.create),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Cơ hội mới'),
            )
          : null,
      body: stage == null
          ? OmniAsyncView(
              value: catalog,
              onRetry: () => ref.invalidate(pipelineCatalogProvider),
              data: (_) => const OmniEmptyState(
                icon: Icons.trending_up_rounded,
                title: 'Quy trình chưa có giai đoạn',
                message: 'Thêm giai đoạn cho quy trình bán hàng trên web.',
              ),
            )
          : _StageList(
              stage: stage,
              controller: _scrollController,
              canMove: access.canUpdate,
            ),
    );
  }

  Future<void> _pickPipeline(
    List<PipelineDef> pipelines,
    String current,
  ) async {
    final code = await showOmniSheet<String>(
      context: context,
      builder: (_) =>
          _PipelinePickerSheet(pipelines: pipelines, current: current),
    );
    if (code == null || code == current) return;
    ref.read(selectedPipelineProvider.notifier).state = code;
  }
}

class _StageList extends ConsumerWidget {
  const _StageList({
    required this.stage,
    required this.controller,
    required this.canMove,
  });

  final PipelineStageDef stage;
  final ScrollController controller;
  final bool canMove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = stageOpportunitiesProvider(stage.code);
    final opportunities = ref.watch(provider);
    final scheme = Theme.of(context).colorScheme;

    return RefreshIndicator(
      onRefresh: () => ref.read(provider.notifier).refresh(),
      child: OmniAsyncView(
        value: opportunities,
        onRetry: () => ref.invalidate(provider),
        isEmpty: (state) => state.items.isEmpty,
        empty: OmniEmptyState(
          icon: Icons.trending_up_rounded,
          title: 'Chưa có cơ hội ở "${stage.label}"',
          message: 'Cơ hội chuyển sang giai đoạn này sẽ hiện ở đây.',
        ),
        data: (state) => ListView.separated(
          controller: controller,
          padding: const EdgeInsets.only(bottom: OmniSpacing.bottomSafe),
          itemCount: state.items.length + (state.hasMore ? 1 : 0),
          separatorBuilder: (_, _) => Divider(
            height: 1,
            thickness: 1,
            indent: 0,
            endIndent: 0,
            color: scheme.outlineVariant,
          ),
          itemBuilder: (context, index) {
            if (index >= state.items.length) {
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
            return OpportunityCard(
              opportunity: state.items[index],
              canMove: canMove,
            );
          },
        ),
      ),
    );
  }
}

class _StageTabs extends StatelessWidget {
  const _StageTabs({
    required this.stages,
    required this.selected,
    required this.onSelected,
    this.leading = const [],
    this.summary,
  });

  final List<PipelineStageDef> stages;
  final String? selected;
  final ValueChanged<String> onSelected;
  final PipelineSummary? summary;

  /// Bộ lọc đứng trước các giai đoạn (quy trình, "Của tôi"), ngăn bằng một
  /// vạch dọc mảnh.
  final List<Widget> leading;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;

    // Cùng kiểu viên với hộp thư (`MPipeline.dc.html`): viên đang chọn là
    // khối mực, và chỉ nó mang thêm TỔNG TIỀN của giai đoạn — màu quỹ đạo
    // sáng. Người bán đọc tiền của giai đoạn mình đang đứng, không phải cả hàng.
    Widget stagePill(PipelineStageDef stage) {
      final total = summary?.totalFor(stage.code);
      final isSelected = stage.code == selected;
      final hasCount = total != null && total.count > 0;
      final foreground = isSelected
          ? (dark ? scheme.surface : Colors.white)
          : scheme.onSurface;

      return Center(
        child: Material(
          color: isSelected
              ? (dark ? scheme.onSurface : OmniColors.ink)
              : scheme.surfaceContainerHighest,
          shape: const StadiumBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => onSelected(stage.code),
            child: Container(
              constraints: const BoxConstraints(minHeight: 34),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: stage.label),
                    if (hasCount) TextSpan(text: ' ${total.count}'),
                    if (hasCount && isSelected)
                      TextSpan(
                        text: ' · ${Formatters.vndCompact(total.value)}',
                        style: TextStyle(
                          color: dark ? OmniColors.primary : OmniColors.orbit,
                        ),
                      ),
                  ],
                ),
                style: OmniType.caption.copyWith(
                  height: 1.2,
                  color: foreground,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  fontFeatures: OmniType.tabular,
                ),
              ),
            ),
          ),
        ),
      );
    }

    final items = <Widget>[
      for (final filter in leading) Center(child: filter),
      if (leading.isNotEmpty)
        Center(
          child: Container(width: 1, height: 22, color: scheme.outlineVariant),
        ),
      for (final stage in stages) stagePill(stage),
    ];

    return SizedBox(
      height: 50,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 2),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: OmniSpacing.sm),
        itemBuilder: (context, index) => items[index],
      ),
    );
  }
}

/// Chọn quy trình khi tenant có nhiều hơn một. Trả về mã quy trình.
class _PipelinePickerSheet extends StatelessWidget {
  const _PipelinePickerSheet({required this.pipelines, required this.current});

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
