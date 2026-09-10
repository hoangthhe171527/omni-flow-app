import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../design/components/components.dart';
import '../../../design/tokens/tokens.dart';
import '../../tasks/application/tasks_providers.dart';
import '../../tasks/routes.dart';
import '../application/plans_providers.dart';
import '../domain/day_group.dart';
import '../domain/feed_entry.dart';
import '../routes.dart';
import 'widgets/completion_row.dart';
import 'widgets/day_header.dart';
import 'widgets/kpi_card.dart';
import 'widgets/piano_done_row.dart';

/// "Hôm nay ai xong cái gì", và "tháng này xong bao nhiêu cây".
///
/// Hai câu hỏi của chủ xưởng. §B4 nói rõ màn này thay hoàn toàn cái bảng đếm
/// tay trên Zalo: con số đứng trên cùng vì nó là thứ được hỏi hằng ngày, và
/// những việc đã đánh dấu xong ở dưới trả lời "vì sao con số đó".
///
/// Chỉ VIỆC ĐÃ XONG. Tạo việc, đổi hạn, đổi người và chuyển nhóm việc không
/// hiện ở đây — chúng đẩy đúng thứ người ta vào xem ra khỏi màn hình, và mỗi
/// công việc đã có nhật ký riêng đầy đủ.
///
/// Thẻ KPI chỉ hiện với người GIAO việc. Thợ mở màn này để xem việc của team
/// đang chạy tới đâu, không phải để theo dõi mốc thưởng — §1 nói rõ thưởng
/// theo team, nên bày nó ra trước mặt từng người là đổi cách xưởng làm việc.
class TimelinePage extends ConsumerStatefulWidget {
  const TimelinePage({super.key});

  @override
  ConsumerState<TimelinePage> createState() => _TimelinePageState();
}

class _TimelinePageState extends ConsumerState<TimelinePage> {
  /// Id những dòng đã vẽ ở lần dựng trước.
  ///
  /// Dòng KHÔNG nằm trong tập này là dòng vừa tới qua realtime, và chỉ nó được
  /// chạy hiệu ứng. Animate cả danh sách mỗi lần tải lại thì màn hình nhấp nháy
  /// mỗi khi ai đó tick một việc — khó chịu hơn là không có hiệu ứng gì.
  final Set<String> _seen = {};

  @override
  Widget build(BuildContext context) {
    final feed = ref.watch(workshopFeedProvider);
    final isAssigner = ref.watch(taskAccessProvider).isAssigner;

    // `valueOrNull`, KHÔNG `when(loading: …)`: khi realtime bơm tín hiệu,
    // provider chuyển sang loading và cả màn sẽ nháy sang vòng xoay trong khi
    // không ai yêu cầu gì cả. Kéo-để-tải-lại thì VẪN thấy vòng xoay của
    // RefreshIndicator, vì người dùng vừa yêu cầu nó nên phải thấy nó chạy.
    final data = feed.valueOrNull;
    final groups = DayGroup.from(data?.entries ?? const []);

    return Scaffold(
      appBar: AppBar(title: const Text('Dòng việc')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(workshopFeedProvider);
          ref.invalidate(workshopKpiProvider);
          await ref.read(workshopFeedProvider.future);
        },
        child: switch ((data, feed)) {
          // Chưa có gì để vẽ và đang tải lần đầu.
          (null, AsyncLoading()) => const Center(
            child: CircularProgressIndicator(),
          ),
          (null, AsyncError(:final error)) => OmniErrorView(
            error: error,
            onRetry: () => ref.invalidate(workshopFeedProvider),
          ),
          _ => _Feed(
            groups: groups,
            isAssigner: isAssigner,
            truncated: data?.truncated ?? false,
            seen: _seen,
          ),
        },
      ),
    );
  }
}

class _Feed extends ConsumerWidget {
  const _Feed({
    required this.groups,
    required this.isAssigner,
    required this.truncated,
    required this.seen,
  });

  final List<DayGroup> groups;
  final bool isAssigner;
  final bool truncated;
  final Set<String> seen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CustomScrollView(
      // Luôn cuộn được, kể cả khi rỗng — nếu không thì kéo-để-tải-lại không
      // hoạt động đúng ở màn trống, mà đó là lúc người ta muốn kéo nhất.
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        if (isAssigner)
          const SliverPadding(
            padding: EdgeInsets.fromLTRB(
              OmniSpacing.lg,
              OmniSpacing.lg,
              OmniSpacing.lg,
              0,
            ),
            sliver: SliverToBoxAdapter(child: _Kpi()),
          ),
        if (groups.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: OmniEmptyState(
              icon: Icons.task_alt_rounded,
              title: 'Chưa có việc nào xong',
              // KHÔNG phải "chưa có hoạt động nào": có thể có rất nhiều hoạt
              // động mà không có việc nào được đánh dấu xong. Hai chuyện khác
              // hẳn nhau, và nói nhầm thì người đọc đi tìm sai chỗ.
              message:
                  'Chưa có việc nào được đánh dấu xong trong 7 ngày qua. '
                  'Tick xong một công đoạn là nó hiện ở đây ngay.',
            ),
          ),
        for (final group in groups) ...[
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: OmniSpacing.lg),
            sliver: SliverPersistentHeader(
              pinned: true,
              delegate: DayHeaderDelegate(group),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: OmniSpacing.lg),
            sliver: SliverList.builder(
              itemCount: group.entries.length,
              itemBuilder: (context, index) {
                final entry = group.entries[index];
                final isNew = seen.isNotEmpty && !seen.contains(entry.id);
                seen.add(entry.id);

                return _SlideInOnce(
                  key: ValueKey(entry.id),
                  enabled: isNew,
                  child: _Row(entry: entry),
                );
              },
            ),
          ),
        ],
        if (truncated)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(OmniSpacing.lg),
              child: Text(
                // Trần 200 việc ở server. Cắt mà không nói là để người đọc
                // tưởng mình đã thấy hết — và một dòng thời gian thiếu thì
                // không nhìn ra được là nó thiếu.
                'Chỉ hiện 7 ngày gần nhất.',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        const SliverToBoxAdapter(
          child: SizedBox(height: OmniSpacing.bottomSafe),
        ),
      ],
    );
  }
}

/// Chọn kiểu dòng theo loại. Cây đàn xong đứng riêng vì nó đếm được.
class _Row extends StatelessWidget {
  const _Row({required this.entry});

  final FeedEntry entry;

  @override
  Widget build(BuildContext context) {
    void open() {
      if (entry.taskId.isEmpty) return;
      context.pushNamed(
        TaskRoutes.detail,
        pathParameters: {'id': entry.taskId},
      );
    }

    return entry.kind == FeedKind.pianoDone
        ? PianoDoneRow(entry: entry, onTap: open)
        : CompletionRow(entry: entry, onTap: open);
  }
}

/// Mờ dần + trượt lên, đúng MỘT lần, cho dòng vừa tới qua realtime.
class _SlideInOnce extends StatelessWidget {
  const _SlideInOnce({super.key, required this.enabled, required this.child});

  final bool enabled;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, 8 * (1 - t)), child: child),
      ),
      child: child,
    );
  }
}

/// Thẻ KPI tự chịu trạng thái tải của mình.
///
/// Tách khỏi dòng việc: hai lượt gọi mạng độc lập, và một cái chậm không được
/// giữ cái kia lại. Cụ thể: KPI phải quét nhật ký cả tháng, dòng việc thì chỉ
/// lấy cửa sổ bảy ngày.
class _Kpi extends ConsumerWidget {
  const _Kpi();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kpi = ref.watch(workshopKpiProvider);
    final month = ref.watch(kpiMonthProvider);
    final now = DateTime.now();
    // So sánh theo THÁNG, không theo ngày: `kpiMonthProvider` luôn giữ ngày 1,
    // nên một phép so bằng trên DateTime sẽ đúng — cho tới lần đầu ai đó đặt
    // vào đó một ngày giữa tháng.
    final atCurrentMonth = month.year == now.year && month.month == now.month;

    return kpi.when(
      data: (data) => KpiCard(
        kpi: data,
        month: month,
        onPrevMonth: () => ref.read(kpiMonthProvider.notifier).state =
            DateTime(month.year, month.month - 1),
        // Không đi tới tương lai: một tháng chưa tới luôn có `delivered = 0`,
        // và số 0 đó trông y hệt "tháng này chưa ai xong cây nào".
        onNextMonth: atCurrentMonth
            ? null
            : () => ref.read(kpiMonthProvider.notifier).state = DateTime(
                month.year,
                month.month + 1,
              ),
        // Không có dự án nào trong tay ở màn này, nên đưa người dùng tới danh
        // sách dự án — chỗ gần nhất mở được phần nhóm việc.
        onConfigure: () => context.pushNamed(PlanRoutes.teams),
      ),
      // Một ô trống cao bằng thẻ, để dòng việc bên dưới không nhảy khi con số
      // tới nơi.
      loading: () => const SizedBox(height: 132),
      // KPI hỏng không được che mất dòng việc — nó là thứ phụ trên màn này, dù
      // là thứ quan trọng nhất với chủ xưởng.
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}
