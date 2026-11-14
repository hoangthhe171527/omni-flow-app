import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../design/components/components.dart';
import '../../../design/tokens/tokens.dart';
import '../application/tasks_providers.dart';
import '../domain/task.dart';
import '../routes.dart';
import 'widgets/task_card.dart';

/// Khoảng lặng trước khi gõ trở thành một lượt gọi mạng.
///
/// 350ms là quãng nghỉ tự nhiên giữa hai chữ. Ngắn hơn thì mỗi ký tự là một
/// lượt đi mạng xưởng; dài hơn thì kết quả tới sau khi người ta đã ngẩng lên.
const kTaskSearchDebounce = Duration(milliseconds: 350);

/// "Cây SN 471302 đang ở đâu."
///
/// Ở xưởng người ta gọi cây đàn bằng số máy, không bằng tên dự án hay tên
/// cột. Khách gọi điện hỏi cây của họ, và câu trả lời nằm rải trong bảy cột
/// của hai dự án — app trước đây không có đường nào tới nó ngoài việc lướt
/// từng cột.
///
/// Server so khớp trên `title`, `customer_name`, `name` và `code`, nên một số
/// máy nằm trong tiêu đề ("SCHWESTER No.53 — SN 471302") tìm ra được, và tên
/// khách cũng vậy.
///
/// Không giới hạn cho quản đốc: người đi tìm một cây đàn thường KHÔNG phải
/// người đang giữ nó — đó chính là lý do họ phải tìm. §3 nói xưởng chạy kiểu
/// pull, và một người thợ không tra được cây mình sắp nhận thì không nhận
/// được.
class TaskSearchPage extends ConsumerStatefulWidget {
  const TaskSearchPage({super.key});

  @override
  ConsumerState<TaskSearchPage> createState() => _TaskSearchPageState();
}

class _TaskSearchPageState extends ConsumerState<TaskSearchPage> {
  @override
  Widget build(BuildContext context) {
    final query = ref.watch(taskSearchQueryProvider).trim();
    final results = ref.watch(taskSearchProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      // Màn con kính (viomni-apple-uiux.html "Tìm cây đàn"): nút quay lại,
      // tiêu đề giữa; ô tìm trong viên kính ngay dưới.
      appBar: OmniAppBar(
        title: 'Tìm cây đàn',
        fallbackBack: () => context.go('/tasks'),
        bottom: OmniSearchBottom(
          fieldKey: const Key('task-search-flat'),
          hint: 'Tên cây đàn, số máy, tên khách',
          debounce: kTaskSearchDebounce,
          autofocus: true,
          onChanged: (value) {
            if (!mounted) return;
            ref.read(taskSearchQueryProvider.notifier).state = value;
          },
          onSubmitted: (value) {
            if (!mounted) return;
            ref.read(taskSearchQueryProvider.notifier).state = value;
          },
        ),
      ),
      body: query.isEmpty
          ? const OmniEmptyState(
              icon: Icons.search_rounded,
              title: 'Tìm một cây đàn',
              message:
                  'Gõ số máy, tên cây đàn hoặc tên khách. Tìm trong cả việc '
                  'đã xong — một cây đã bàn giao vẫn phải tra lại được.',
            )
          : OmniAsyncView(
              value: results,
              onRetry: () => ref.invalidate(taskSearchProvider),
              isEmpty: (list) => list.isEmpty,
              empty: OmniEmptyState(
                icon: Icons.search_off_rounded,
                title: 'Không có kết quả cho "$query"',
                message:
                    'Thử một phần của số máy thay vì cả chuỗi — tìm theo đoạn '
                    'khớp, nên "4713" cũng ra.',
              ),
              data: (list) {
                final groups = _groupByPlan(list);
                return ListView.separated(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(
                    OmniSpacing.lg,
                    OmniSpacing.xs,
                    OmniSpacing.lg,
                    OmniSpacing.bottomSafe,
                  ),
                  itemCount: groups.length + 1,
                  separatorBuilder: (_, index) => SizedBox(
                    height: index == 0 ? OmniSpacing.sm : OmniGroupSection.gap,
                  ),
                  itemBuilder: (context, i) {
                    if (i == 0) {
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
                        child: Text(
                          '${list.length} kết quả · tìm cả việc đã xong',
                          style: OmniType.caption.copyWith(
                            fontWeight: FontWeight.w400,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      );
                    }
                    final group = groups[i - 1];
                    return OmniGroupSection(
                      title: group.title,
                      trailingTitle: Text(
                        '${group.tasks.length} việc',
                        style: OmniType.caption.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontFeatures: OmniType.tabular,
                        ),
                      ),
                      dividerIndent: 14,
                      children: [
                        for (final task in group.tasks)
                          TaskCard(
                            task: task,
                            showPlanName: false,
                            highlight: query,
                            onTap: () => context.pushNamed(
                              TaskRoutes.detail,
                              pathParameters: {'id': task.id},
                            ),
                          ),
                      ],
                    );
                  },
                );
              },
            ),
    );
  }

  List<({String title, List<Task> tasks})> _groupByPlan(List<Task> items) {
    final map = <String, List<Task>>{};
    for (final task in items) {
      final raw = task.projectName?.trim();
      final key = (raw != null && raw.isNotEmpty) ? raw : 'Việc chung';
      map.putIfAbsent(key, () => []).add(task);
    }
    return [
      for (final entry in map.entries) (title: entry.key, tasks: entry.value),
    ];
  }
}
