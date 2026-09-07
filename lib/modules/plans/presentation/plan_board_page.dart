import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../design/components/components.dart';
import '../../../design/platform/omni_motion_scope.dart';
import '../../../design/tokens/tokens.dart';
import '../../tasks/domain/task.dart';
import '../../tasks/application/tasks_providers.dart';
import '../../tasks/presentation/create_task_page.dart';
import '../../tasks/presentation/widgets/task_card.dart';
import '../../tasks/routes.dart';
import '../../tasks/tasks_module.dart';
import '../application/plans_providers.dart';
import '../data/plans_api.dart';
import '../domain/plan.dart';
import 'widgets/section_pager.dart';

/// Bảng công việc của một kế hoạch: mỗi màn lướt ngang là MỘT nhóm việc.
///
/// Tôi từng cho rằng điện thoại không hợp kanban. Ảnh chụp myXteam của người
/// dùng chứng minh ngược lại — cách làm đúng là PHÂN TRANG, không phải cuộn
/// ngang tự do. Một cột chiếm trọn màn hình thì thẻ đọc được; hé cột bên cạnh
/// làm chữ bị cắt và đọc như lỗi.
class PlanBoardPage extends ConsumerStatefulWidget {
  const PlanBoardPage({super.key, required this.planId});

  final String planId;

  @override
  ConsumerState<PlanBoardPage> createState() => _PlanBoardPageState();
}

class _PlanBoardPageState extends ConsumerState<PlanBoardPage> {
  // viewportFraction mặc định là 1.0 — cố ý không đổi. Xem doc của lớp.
  final _controller = PageController();
  int _current = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final plan = ref.watch(planProvider(widget.planId));
    final tasks = ref.watch(planTasksProvider(widget.planId));

    final loaded = plan.valueOrNull;

    return Scaffold(
      appBar: AppBar(title: Text(loaded?.name ?? 'Kế hoạch')),
      // Nút tạo nằm trên BẢNG, không nằm ở "Việc của tôi": ở đây kế hoạch và
      // cột đang đứng đã biết sẵn, nên việc mới ra đời đúng chỗ mà không phải
      // hỏi thêm câu nào. Ở "Việc của tôi" thì cả hai đều phải hỏi.
      floatingActionButton:
          loaded == null || !ref.watch(taskAccessProvider).canCreate
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _createTask(loaded),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Việc mới'),
            ),
      body: OmniAsyncView(
        value: plan,
        onRetry: () => ref.invalidate(planProvider(widget.planId)),
        data: (plan) => _Board(
          plan: plan,
          tasks: tasks,
          controller: _controller,
          current: _current.clamp(0, _columnCount(plan) - 1),
          onPage: (index) => setState(() => _current = index),
          onRetryTasks: () => ref.invalidate(planTasksProvider(widget.planId)),
        ),
      ),
    );
  }

  int _columnCount(Plan plan) =>
      plan.sections.isEmpty ? 1 : plan.sections.length;

  /// Mở màn tạo việc với kế hoạch + cột đang đứng điền sẵn.
  Future<void> _createTask(Plan plan) async {
    final sections = plan.sections;
    final current = _current.clamp(0, _columnCount(plan) - 1);

    final created = await context.pushNamed<String>(
      TaskRoutes.create,
      extra: CreateTaskArgs(
        planId: plan.id,
        sectionId: sections.isEmpty ? null : sections[current].id,
        // Chép sang value type của module tasks. `PlanSection` sống ở plans,
        // và bắt tasks biết kiểu đó là đóng một vòng phụ thuộc.
        sections: [
          for (final s in sections) TaskSection(id: s.id, name: s.name),
        ],
      ),
    );

    // Chỉ làm mới khi thật sự tạo được. Huỷ giữa chừng mà vẫn gọi lại mạng là
    // bắt người dùng chờ một lượt tải cho một việc họ vừa quyết định không làm.
    if (created != null && mounted) {
      ref.invalidate(planTasksProvider(widget.planId));
    }
  }
}

class _Board extends StatelessWidget {
  const _Board({
    required this.plan,
    required this.tasks,
    required this.controller,
    required this.current,
    required this.onPage,
    required this.onRetryTasks,
  });

  final Plan plan;
  final AsyncValue<PlanTasks> tasks;
  final PageController controller;
  final int current;
  final ValueChanged<int> onPage;
  final VoidCallback onRetryTasks;

  /// Một kế hoạch chưa khai báo nhóm việc nào vẫn phải xem được: một cột duy
  /// nhất, chứa tất cả.
  List<PlanSection> get _columns => plan.sections.isEmpty
      ? const [PlanSection(id: '', name: 'Tất cả công việc')]
      : plan.sections;

  @override
  Widget build(BuildContext context) {
    final columns = _columns;

    return OmniAsyncView(
      value: tasks,
      onRetry: onRetryTasks,
      data: (loaded) {
        final buckets = _bucket(loaded.tasks, columns);

        return Column(
          children: [
            if (loaded.truncated) const _TruncatedNotice(),
            SectionIndicator(
              sections: columns,
              current: current,
              countOf: (i) => buckets[i].length,
              // goTo nhảy thay vì trượt khi người dùng đã tắt hiệu ứng. Bảng
              // lướt ngang toàn màn hình là đúng loại chuyển động mà cài đặt
              // đó nhắm tới.
              onSelected: (i) => controller.goTo(context, i),
            ),
            Expanded(
              child: PageView.builder(
                controller: controller,
                onPageChanged: onPage,
                itemCount: columns.length,
                itemBuilder: (context, index) =>
                    _Column(section: columns[index], tasks: buckets[index]),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Chia việc vào cột theo `section_id`.
  ///
  /// Việc không thuộc nhóm nào — hoặc thuộc một nhóm đã bị xoá — rơi vào cột
  /// ĐẦU chứ không bị bỏ đi. Một cây đàn không ai thấy là một cây đàn không ai
  /// làm.
  List<List<Task>> _bucket(List<Task> all, List<PlanSection> columns) {
    final byId = {for (var i = 0; i < columns.length; i++) columns[i].id: i};
    final buckets = List.generate(columns.length, (_) => <Task>[]);

    for (final task in all) {
      buckets[byId[task.sectionId ?? ''] ?? 0].add(task);
    }

    return buckets;
  }
}

class _Column extends StatelessWidget {
  const _Column({required this.section, required this.tasks});

  final PlanSection section;
  final List<Task> tasks;

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      // Một nhóm rỗng VẪN là một trang. Bỏ nó đi làm số trang lệch với số công
      // đoạn, và người quản đốc mất đúng thông tin họ cần: công đoạn nào đang
      // trống.
      return OmniEmptyState(
        icon: Icons.inbox_outlined,
        title: 'Chưa có việc ở "${section.name}"',
        message: 'Việc chuyển sang nhóm việc này sẽ hiện ở đây.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        OmniSpacing.lg,
        0,
        OmniSpacing.lg,
        OmniSpacing.bottomSafe,
      ),
      itemCount: tasks.length,
      separatorBuilder: (_, _) => const SizedBox(height: OmniSpacing.sm),
      itemBuilder: (context, index) => TaskCard(
        task: tasks[index],
        onTap: () => context.pushNamed(
          TasksModule.detail,
          pathParameters: {'id': tasks[index].id},
        ),
      ),
    );
  }
}

/// Kế hoạch vượt trần: bảng chỉ vẽ được một phần, và phải nói ra.
///
/// Nạp một phần mà im lặng là nói dối — quản đốc nhìn một bảng đầy và tưởng
/// mình đã thấy hết. Con số ở đây là thứ họ cần để biết mình đang nhìn bao
/// nhiêu phần của sự thật.
class _TruncatedNotice extends StatelessWidget {
  const _TruncatedNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: OmniColors.warningTextOf(context).withValues(alpha: 0.08),
      padding: const EdgeInsets.symmetric(
        horizontal: OmniSpacing.lg,
        vertical: OmniSpacing.md,
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: OmniIconSize.sm,
            color: OmniColors.warningTextOf(context),
          ),
          const SizedBox(width: OmniSpacing.sm),
          Expanded(
            child: Text(
              'Kế hoạch này có hơn $kMaxTasksOnBoard việc. Bảng đang hiện '
              '$kMaxTasksOnBoard việc đầu theo thứ tự trên bảng.',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: OmniColors.warningTextOf(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
