import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../design/components/components.dart';
import '../../../design/platform/omni_motion_scope.dart';
import '../../../design/tokens/tokens.dart';
import '../../tasks/domain/task.dart';
import '../../tasks/application/tasks_providers.dart';
import '../../settings/presentation/widgets/surface_backdrop.dart';
import '../../tasks/presentation/create_task_page.dart';
import '../../tasks/presentation/widgets/task_card.dart';
import '../../tasks/routes.dart';
import '../../tasks/tasks_module.dart';
import '../application/plans_providers.dart';
import '../data/plans_api.dart';
import '../domain/plan.dart';
import 'edit_sections_page.dart';
import 'widgets/person_filter_sheet.dart';
import 'widgets/section_pager.dart';

/// Chỗ nút "Việc mới" chiếm, cộng vào đáy danh sách để nó không che thẻ cuối.
const double _fabInset = 72;

/// Bảng công việc của một dự án: mỗi màn lướt ngang là MỘT nhóm việc.
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

  /// Trang đang đứng. ValueNotifier chứ không setState: một cú vuốt chỉ đổi
  /// viên đang sáng trên dải chỉ báo, không việc gì phải dựng lại cả bảng.
  final _current = ValueNotifier<int>(0);

  /// Đang lọc theo ai. Sống trong State của màn chứ không trong một provider
  /// toàn cục: đây là cách người dùng đang NHÌN một cái bảng, không phải một
  /// thiết lập của họ. Mở bảng khác ra mà vẫn còn lọc theo một người là cách
  /// một cái bảng trống trông như một cái bảng hỏng.
  BoardPerson _person = BoardPerson.everyone;

  @override
  void dispose() {
    _controller.dispose();
    _current.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Không theo dõi việc ở đây: `_Board` tự đọc rổ đã chia từ provider, nên
    // realtime đổi việc chỉ dựng lại bảng, không dựng lại AppBar và nút tạo.
    final plan = ref.watch(planProvider(widget.planId));

    final loaded = plan.valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: Text(loaded?.name ?? 'Dự án'),
        actions: [
          // Lọc theo người. Mở cho MỌI người đọc được bảng, không riêng quản
          // đốc: §3 nói xưởng chạy kiểu pull, và "công đoạn nào đang trống"
          // là câu người thợ hỏi mỗi lần rảnh tay — "Chưa giao ai" trong
          // sheet này là câu trả lời, trước nay chỉ có bằng cách lướt hết
          // bảng đọc từng thẻ.
          IconButton(
            onPressed: _pickPerson,
            tooltip: 'Lọc theo người',
            icon: Icon(
              _person.chipLabel == null
                  ? Icons.filter_alt_outlined
                  : Icons.filter_alt_rounded,
            ),
          ),
          // Sửa các cột của chính cái bảng đang nhìn. Nhóm việc trước đây
          // chỉ khai được lúc tạo dự án, nên một cái tên gõ nhầm là phải
          // tạo lại cả dự án — mà công việc thì đã nằm trong đó rồi.
          if (loaded != null && ref.watch(taskAccessProvider).isAssigner)
            IconButton(
              onPressed: _editSections,
              icon: const Icon(Icons.view_column_outlined),
              tooltip: 'Sửa nhóm việc',
            ),
        ],
      ),
      // Nút tạo nằm trên BẢNG, không nằm ở "Việc của tôi": ở đây dự án và
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
          controller: _controller,
          current: _current,
          onRetryTasks: () => ref.invalidate(planTasksProvider(widget.planId)),
          person: _person,
          onClearPerson: () => setState(() => _person = BoardPerson.everyone),
        ),
      ),
    );
  }

  int _columnCount(Plan plan) =>
      plan.sections.isEmpty ? 1 : plan.sections.length;

  Future<void> _pickPerson() async {
    final picked = await showPersonFilterSheet(context, current: _person);
    if (picked != null && mounted) setState(() => _person = picked);
  }

  Future<void> _editSections() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EditSectionsPage(planId: widget.planId),
      ),
    );
  }

  /// Mở màn tạo việc với dự án + cột đang đứng điền sẵn.
  Future<void> _createTask(Plan plan) async {
    final sections = plan.sections;
    final current = _current.value.clamp(0, _columnCount(plan) - 1);

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

/// Bảng: dải chỉ báo + các cột lướt ngang, vẽ từ rổ đã chia trong provider.
class _Board extends ConsumerWidget {
  const _Board({
    required this.plan,
    required this.controller,
    required this.current,
    required this.onRetryTasks,
    required this.person,
    required this.onClearPerson,
  });

  final Plan plan;
  final PageController controller;

  /// Trang đang đứng; chỉ dải chỉ báo nghe nó.
  final ValueNotifier<int> current;
  final VoidCallback onRetryTasks;
  final BoardPerson person;
  final VoidCallback onClearPerson;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Lọc và chia cột đã xong trong provider — tính một lần cho mỗi (dự án,
    // bộ lọc), không phải mỗi lần widget này dựng lại.
    final buckets = ref.watch(
      boardBucketsProvider((planId: plan.id, person: person)),
    );

    return OmniAsyncView(
      value: buckets,
      onRetry: onRetryTasks,
      data: (board) {
        final columns = board.columns;

        return Column(
          children: [
            if (board.truncated) const _TruncatedNotice(),
            if (person.chipLabel case final String label)
              _FilterBar(label: label, onClear: onClearPerson),
            // Chỉ dải chỉ báo dựng lại khi lướt trang; các cột đứng yên.
            ValueListenableBuilder<int>(
              valueListenable: current,
              builder: (context, index, _) => SectionIndicator(
                sections: columns,
                current: index.clamp(0, columns.length - 1),
                countOf: board.countOf,
                // goTo nhảy thay vì trượt khi người dùng đã tắt hiệu ứng. Bảng
                // lướt ngang toàn màn hình là đúng loại chuyển động mà cài đặt
                // đó nhắm tới.
                onSelected: (i) => controller.goTo(context, i),
              ),
            ),
            Expanded(
              // Nền cả app nằm SAU các cột, không sau dải nhóm việc: dải và
              // AppBar giữ nền phẳng để đọc; thẻ việc vốn đục nên vẫn nổi.
              child: SurfaceBackdrop(
                child: PageView.builder(
                  controller: controller,
                  onPageChanged: (index) => current.value = index,
                  itemCount: columns.length,
                  itemBuilder: (context, index) => _Column(
                    section: columns[index],
                    tasks: board.buckets[index],
                    filteredBy: person.chipLabel,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Column extends StatelessWidget {
  const _Column({required this.section, required this.tasks, this.filteredBy});

  final PlanSection section;
  final List<Task> tasks;

  /// Tên bộ lọc đang bật, để một cột rỗng nói đúng lý do nó rỗng.
  final String? filteredBy;

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      // Một nhóm rỗng VẪN là một trang. Bỏ nó đi làm số trang lệch với số công
      // đoạn, và người quản đốc mất đúng thông tin họ cần: công đoạn nào đang
      // trống.
      //
      // Rỗng vì đang lọc là chuyện KHÁC HẲN rỗng vì không có việc nào, và hai
      // câu phải khác nhau: một quản đốc còn đang lọc theo một người mà đọc
      // "chưa có việc ở Chờ QC" sẽ kết luận sai về cả cột.
      return OmniEmptyState(
        icon: Icons.inbox_outlined,
        title: filteredBy == null
            ? 'Chưa có việc ở "${section.name}"'
            : 'Không có việc nào của $filteredBy ở "${section.name}"',
        message: filteredBy == null
            ? 'Việc chuyển sang nhóm việc này sẽ hiện ở đây.'
            : 'Bỏ bộ lọc để xem toàn bộ nhóm việc này.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        OmniSpacing.lg,
        0,
        OmniSpacing.lg,
        // Chừa chỗ cho nút "Việc mới": nó nổi trên danh sách, nên cột đầy
        // việc thì nó che mất đúng thẻ cuối — thẻ người ta phải cuộn xa nhất
        // mới tới.
        OmniSpacing.bottomSafe + _fabInset,
      ),
      itemCount: tasks.length,
      separatorBuilder: (_, _) => const SizedBox(height: OmniSpacing.sm),
      itemBuilder: (context, index) => TaskCard(
        task: tasks[index],
        // Tiêu đề màn đã LÀ tên dự án, và cả bảng chỉ thuộc một dự án.
        // In lại trên từng thẻ là ba dòng giống nhau trên một màn hình.
        // Ở "Việc của tôi" thì ngược lại: việc đến từ nhiều dự án, nên ở
        // đó dòng này là thứ phân biệt.
        showPlanName: false,
        onTap: () => context.pushNamed(
          TasksModule.detail,
          pathParameters: {'id': tasks[index].id},
        ),
      ),
    );
  }
}

/// Đang lọc theo ai, và đường ra khỏi bộ lọc.
///
/// Một cái bảng đang lọc trông y hệt một cái bảng vắng việc. Thanh này là thứ
/// duy nhất phân biệt hai chuyện đó, nên nó phải nằm TRÊN bảng chứ không nấp
/// sau một biểu tượng ở thanh tiêu đề — và nút bỏ lọc phải ở ngay cạnh, vì
/// người bật nó lên thường không nhớ mình đã bật.
class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.label, required this.onClear});

  final String label;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      color: scheme.primary.withValues(alpha: 0.06),
      padding: const EdgeInsets.fromLTRB(
        OmniSpacing.lg,
        OmniSpacing.sm,
        OmniSpacing.sm,
        OmniSpacing.sm,
      ),
      child: Row(
        children: [
          Icon(
            Icons.filter_alt_rounded,
            size: OmniIconSize.sm,
            color: scheme.primary,
          ),
          const SizedBox(width: OmniSpacing.sm),
          Expanded(
            child: Text(
              'Đang lọc: $label',
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(color: scheme.primary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            onPressed: onClear,
            tooltip: 'Bỏ lọc',
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.close_rounded, color: scheme.primary),
          ),
        ],
      ),
    );
  }
}

/// Dự án vượt trần: bảng chỉ vẽ được một phần, và phải nói ra.
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
              'Dự án này có hơn $kMaxTasksOnBoard việc. Bảng đang hiện '
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
