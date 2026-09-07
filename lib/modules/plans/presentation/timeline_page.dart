import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/formatters.dart';
import '../../../design/components/components.dart';
import '../../../design/tokens/tokens.dart';
import '../../tasks/application/tasks_providers.dart';
import '../../tasks/routes.dart';
import '../application/plans_providers.dart';
import '../domain/feed_entry.dart';
import '../domain/feed_group.dart';
import 'widgets/kpi_card.dart';

/// "Chuyện gì vừa xảy ra ở xưởng", và "tháng này xong bao nhiêu cây".
///
/// Hai câu hỏi của chủ xưởng, và §B4 của tài liệu nói rõ màn này thay hoàn
/// toàn cái bảng đếm tay trên Zalo. Con số đứng trên cùng vì nó là thứ được
/// hỏi hằng ngày; dòng hoạt động ở dưới trả lời "vì sao con số đó".
///
/// Thẻ KPI chỉ hiện với người GIAO việc. Thợ mở màn này để xem việc của team
/// đang chạy tới đâu, không phải để theo dõi mốc thưởng — và §1 nói rõ thưởng
/// theo team, nên bày nó ra trước mặt từng người là đổi cách xưởng làm việc.
class TimelinePage extends ConsumerWidget {
  const TimelinePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(workshopFeedProvider);
    final isAssigner = ref.watch(taskAccessProvider).isAssigner;

    return Scaffold(
      appBar: AppBar(title: const Text('Dòng việc')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(workshopFeedProvider);
          ref.invalidate(workshopKpiProvider);
        },
        child: OmniAsyncView(
          value: feed,
          onRetry: () => ref.invalidate(workshopFeedProvider),
          isEmpty: (rows) => rows.isEmpty && !isAssigner,
          empty: const OmniEmptyState(
            icon: Icons.history_rounded,
            title: 'Chưa có hoạt động nào',
            message:
                'Việc được tạo, chuyển công đoạn hay đổi hạn sẽ hiện ở đây.',
          ),
          data: (rows) {
            final groups = FeedGroup.from(rows);

            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                OmniSpacing.lg,
                OmniSpacing.lg,
                OmniSpacing.lg,
                OmniSpacing.bottomSafe,
              ),
              // +1 cho thẻ KPI ở đầu, chỉ khi người xem là người giao việc.
              itemCount: groups.length + (isAssigner ? 1 : 0),
              separatorBuilder: (_, _) =>
                  const SizedBox(height: OmniSpacing.md),
              itemBuilder: (context, index) {
                if (isAssigner && index == 0) return const _Kpi();

                return _FeedCard(group: groups[index - (isAssigner ? 1 : 0)]);
              },
            );
          },
        ),
      ),
    );
  }
}

/// Thẻ KPI tự chịu trạng thái tải của mình.
///
/// Tách khỏi dòng hoạt động: hai lượt gọi mạng độc lập, và một cái chậm không
/// được giữ cái kia lại. Cụ thể: KPI phải quét nhật ký cả tháng, dòng hoạt
/// động thì chỉ lấy vài chục dòng mới nhất.
class _Kpi extends ConsumerWidget {
  const _Kpi();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kpi = ref.watch(workshopKpiProvider);

    return Padding(
      padding: const EdgeInsets.only(bottom: OmniSpacing.sm),
      child: kpi.when(
        data: (data) => KpiCard(kpi: data),
        // Một ô trống cao bằng thẻ, để dòng hoạt động bên dưới không nhảy khi
        // con số tới nơi.
        loading: () => const SizedBox(height: 132),
        // KPI hỏng không được che mất dòng hoạt động — nó là thứ phụ trên màn
        // này, dù là thứ quan trọng nhất với chủ xưởng.
        error: (_, _) => const SizedBox.shrink(),
      ),
    );
  }
}

/// Một cây đàn, và những gì vừa xảy ra với nó.
///
/// Tiêu đề cây đàn hiện MỘT lần rồi mới tới các hoạt động, thay vì lặp lại
/// trên từng dòng. Cùng một lượng thông tin, nhưng mắt chỉ phải đọc tên cây
/// một lần và phần còn lại là chuyện đã xảy ra — đó là khác biệt giữa một bản
/// tóm tắt và một cuốn sổ.
class _FeedCard extends StatelessWidget {
  const _FeedCard({required this.group});

  /// Nhiều hơn ngần này thì một cây đàn bị rework dồn dập sẽ đẩy cả xưởng ra
  /// khỏi màn hình. Phần còn lại vẫn đếm được, và mở cây đàn ra là thấy đủ.
  static const _maxLines = 5;

  final FeedGroup group;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final shown = group.entries.take(_maxLines).toList();
    final hidden = group.entries.length - shown.length;

    return OmniCard(
      onTap: group.taskId.isEmpty
          ? null
          : () => context.pushNamed(
              TaskRoutes.detail,
              pathParameters: {'id': group.taskId},
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            group.taskTitle,
            style: text.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: OmniSpacing.sm),
          for (final entry in shown) _FeedLine(entry: entry),
          if (hidden > 0)
            Padding(
              padding: const EdgeInsets.only(top: OmniSpacing.xs),
              child: Text(
                'và $hidden hoạt động nữa',
                style: text.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Một hoạt động: ai, làm gì, lúc nào.
class _FeedLine extends StatelessWidget {
  const _FeedLine({required this.entry});

  final FeedEntry entry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: OmniSpacing.xxs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_icon, size: OmniIconSize.sm, color: scheme.onSurfaceVariant),
          const SizedBox(width: OmniSpacing.sm),
          Expanded(
            child: Text(
              // Tên người đứng trước hành động khi biết được: "Hằng Ni đã xong
              // Body ngoài" đọc như một câu, còn "đã xong Body ngoài — Hằng Ni"
              // đọc như một bản ghi.
              entry.userName == null
                  ? entry.summary
                  : '${entry.userName} ${entry.summary}',
              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(width: OmniSpacing.sm),
          Text(
            Formatters.relative(entry.at),
            style: text.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  IconData get _icon => switch (entry.kind) {
    FeedKind.created => Icons.add_circle_outline_rounded,
    FeedKind.section => Icons.swap_horiz_rounded,
    FeedKind.status => Icons.check_circle_outline_rounded,
    FeedKind.dueDate => Icons.event_outlined,
    FeedKind.assignees => Icons.person_outline_rounded,
    // Hai loại thợ tạo ra nhiều nhất trong ngày, nên chúng phải phân biệt
    // được với nhau chỉ bằng biểu tượng khi lướt nhanh.
    FeedKind.subtaskCompleted => Icons.task_alt_rounded,
    FeedKind.subtaskAssigned => Icons.how_to_reg_outlined,
    FeedKind.attachmentAdded => Icons.image_outlined,
    FeedKind.attachmentRemoved => Icons.hide_image_outlined,
    FeedKind.other => Icons.circle_outlined,
  };
}
