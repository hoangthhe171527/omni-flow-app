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
          data: (rows) => ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              OmniSpacing.lg,
              OmniSpacing.lg,
              OmniSpacing.lg,
              OmniSpacing.bottomSafe,
            ),
            // +1 cho thẻ KPI ở đầu, chỉ khi người xem là người giao việc.
            itemCount: rows.length + (isAssigner ? 1 : 0),
            separatorBuilder: (_, _) => const SizedBox(height: OmniSpacing.md),
            itemBuilder: (context, index) {
              if (isAssigner && index == 0) return const _Kpi();

              final entry = rows[index - (isAssigner ? 1 : 0)];

              return _FeedRow(entry: entry);
            },
          ),
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

class _FeedRow extends StatelessWidget {
  const _FeedRow({required this.entry});

  final FeedEntry entry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return InkWell(
      onTap: entry.taskId.isEmpty
          ? null
          : () => context.pushNamed(
              TaskRoutes.detail,
              pathParameters: {'id': entry.taskId},
            ),
      borderRadius: OmniRadius.lgAll,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: OmniSpacing.xs),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(_icon, size: OmniIconSize.md, color: scheme.onSurfaceVariant),
            const SizedBox(width: OmniSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.taskTitle,
                    style: text.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    // Tên người đứng trước hành động khi biết được: "Hằng Ni
                    // đã chuyển công đoạn" đọc như một câu, còn "đã chuyển
                    // công đoạn — Hằng Ni" đọc như một bản ghi.
                    entry.userName == null
                        ? entry.summary
                        : '${entry.userName} ${entry.summary}',
                    style: text.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: OmniSpacing.sm),
            Text(
              Formatters.relative(entry.at),
              style: text.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  IconData get _icon => switch (entry.kind) {
    FeedKind.created => Icons.add_circle_outline_rounded,
    FeedKind.section => Icons.swap_horiz_rounded,
    FeedKind.status => Icons.check_circle_outline_rounded,
    FeedKind.dueDate => Icons.event_outlined,
    FeedKind.assignees => Icons.person_outline_rounded,
    FeedKind.other => Icons.circle_outlined,
  };
}
