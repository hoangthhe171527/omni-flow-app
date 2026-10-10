import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/error/app_exception.dart';
import '../../../design/components/components.dart';
import '../../../design/platform/omni_motion_scope.dart';
import '../../../design/tokens/tokens.dart';
import '../../../security/session/session_controller.dart';
import '../../tasks/domain/task.dart';
import '../../tasks/application/tasks_providers.dart';
import '../../settings/settings.dart';
import '../../tasks/routes.dart';
import '../../tasks/tasks.dart';
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
    final taskAccess = ref.watch(taskAccessProvider);
    final currentUserId = ref.watch(sessionProvider.select((s) => s.user?.id));
    final canDeletePlan =
        loaded != null &&
        taskAccess.canDelete &&
        (taskAccess.isAssigner ||
            (currentUserId != null &&
                loaded.roleOf(currentUserId) == PlanRole.owner));

    final canPop = ModalRoute.of(context)?.canPop ?? false;
    final scheme = Theme.of(context).colorScheme;

    // Chủ/quản lý DỰ ÁN cũng sửa được nhóm việc, đúng quyền API (CV-I14).
    final canEditSections =
        loaded != null &&
        (taskAccess.isAssigner ||
            (currentUserId != null &&
                loaded.roleOf(currentUserId).canManagePlan));

    return Scaffold(
      // Đầu bảng là mặt TRẮNG liền với dải tab nhóm việc — cùng kiểu đầu màn
      // với mọi màn làm việc khác (đề xuất "Chuẩn hoá phong cách"). Khối mực
      // cũ là một kiểu tab thứ ba trên cùng một app.
      appBar: AppBar(
        backgroundColor: scheme.surface,
        // Nút quay lại luôn có khi mở từ danh sách; khi không có (mở thẳng
        // bằng liên kết sâu) thì tiêu đề lùi vào 16 chứ không dính mép.
        automaticallyImplyLeading: false,
        leading: canPop ? const BackButton() : null,
        titleSpacing: canPop ? 0 : OmniSpacing.lg,
        title: _BoardTitle(
          planId: widget.planId,
          plan: loaded,
          person: _person,
        ),
        actions: [
          // Lọc theo người. Mở cho MỌI người đọc được bảng, không riêng quản
          // đốc: §3 nói xưởng chạy kiểu pull, và "công đoạn nào đang trống"
          // là câu người thợ hỏi mỗi lần rảnh tay — "Chưa giao ai" trong
          // sheet này là câu trả lời, trước nay chỉ có bằng cách lướt hết
          // bảng đọc từng thẻ.
          _FilterButton(active: _person.chipLabel != null, onTap: _pickPerson),
          // Sửa nhóm việc và xoá dự án gộp một menu: hai nút riêng chiếm chỗ
          // của tên dự án. Không quyền nào thì ẩn cả ⋯ (không nút chết).
          if (loaded != null && (canEditSections || canDeletePlan))
            PopupMenuButton<_PlanAction>(
              tooltip: 'Tuỳ chọn dự án',
              onSelected: (action) {
                switch (action) {
                  case _PlanAction.editSections:
                    _editSections();
                  case _PlanAction.delete:
                    _deletePlan(loaded);
                }
              },
              itemBuilder: (context) => [
                if (canEditSections)
                  const PopupMenuItem(
                    value: _PlanAction.editSections,
                    child: Row(
                      children: [
                        Icon(Icons.view_column_outlined),
                        SizedBox(width: OmniSpacing.sm),
                        Text('Sửa nhóm việc'),
                      ],
                    ),
                  ),
                if (canDeletePlan)
                  const PopupMenuItem(
                    value: _PlanAction.delete,
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, color: Colors.red),
                        SizedBox(width: OmniSpacing.sm),
                        Text('Xoá dự án', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
              ],
            ),
        ],
        // Dải tab nhóm việc nằm ngay dưới tên dự án và ĐỌC cùng rổ đã chia với
        // bảng, nên số trên tab đi theo bộ lọc.
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(SectionTabs.height + 1),
          child: _BoardTabs(
            planId: widget.planId,
            person: _person,
            controller: _controller,
            current: _current,
          ),
        ),
      ),
      // Nút tạo nằm trên BẢNG, không nằm ở "Việc của tôi": ở đây dự án và
      // cột đang đứng đã biết sẵn, nên việc mới ra đời đúng chỗ mà không phải
      // hỏi thêm câu nào. Ở "Việc của tôi" thì cả hai đều phải hỏi.
      floatingActionButton: loaded == null || !taskAccess.canCreate
          ? null
          // Bảng là route gốc (rootNavigator) nên thanh kính mờ của shell
          // không phủ lên đây — nút không cần nâng lên khỏi nó.
          : FloatingActionButtonTheme(
              data: const FloatingActionButtonThemeData(
                extendedSizeConstraints: BoxConstraints.tightFor(height: 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(14)),
                ),
              ),
              child: FloatingActionButton.extended(
                onPressed: () => _createTask(loaded),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Việc mới'),
              ),
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

  Future<void> _deletePlan(Plan plan) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showOmniConfirm(
      context: context,
      title: 'Xoá dự án “${plan.name}”?',
      message:
          'Toàn bộ công việc trong dự án cũng sẽ được chuyển vào thùng rác. Thao tác sẽ đồng bộ trên web và điện thoại.',
      confirmLabel: 'Xoá dự án',
      destructive: true,
    );
    if (!confirmed) return;

    try {
      await ref.read(plansApiProvider).deletePlan(plan.id);
      ref.invalidate(teamsWithPlansProvider);
      ref.invalidate(planProvider(plan.id));
      ref.invalidate(planTasksProvider(plan.id));
      ref.read(taskRealtimeSignalProvider.notifier).bump();
      if (!mounted) return;
      context.pop();
      messenger.showSnackBar(const SnackBar(content: Text('Đã xoá dự án.')));
    } on AppException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    }
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

enum _PlanAction { editSections, delete }

/// Tên dự án + "team · N việc". N là số việc ĐANG HIỆN sau lọc, nên widget này
/// tự đọc rổ đã chia: lọc đổi thì phụ đề đổi theo mà AppBar không dựng lại.
class _BoardTitle extends ConsumerWidget {
  const _BoardTitle({
    required this.planId,
    required this.plan,
    required this.person,
  });

  final String planId;
  final Plan? plan;
  final BoardPerson person;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final loaded = plan;
    final board = ref
        .watch(boardBucketsProvider((planId: planId, person: person)))
        .valueOrNull;
    // Chưa tải rổ thì dùng số tổng của dự án — im lặng còn hơn đoán.
    final shown = board == null
        ? (loaded?.taskCount ?? 0)
        : board.buckets.fold<int>(0, (a, b) => a + b.length);
    final subtitle = [
      if (loaded?.teamName case final team? when team.isNotEmpty) team,
      if (board != null || shown > 0) '$shown việc',
    ].join(' · ');

    return Row(
      children: [
        Container(
          key: const Key('board-swatch'),
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: OmniCovers.colorOf(loaded?.cover),
            borderRadius: const BorderRadius.all(Radius.circular(6)),
          ),
        ),
        const SizedBox(width: OmniSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                loaded?.name ?? 'Dự án',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: OmniType.bodyStrong.copyWith(color: scheme.onSurface),
              ),
              if (subtitle.isNotEmpty)
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: OmniType.micro.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Nút lọc: ô 36 bo 6 trong vùng chạm 44. Đang lọc thì đảo màu (mực/nền).
class _FilterButton extends StatelessWidget {
  const _FilterButton({required this.active, required this.onTap});

  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Tooltip(
      message: 'Lọc theo người',
      child: Semantics(
        button: true,
        selected: active,
        label: 'Lọc theo người',
        excludeSemantics: true,
        child: InkResponse(
          onTap: onTap,
          radius: 22,
          child: SizedBox.square(
            dimension: 44,
            child: Center(
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: active ? scheme.onSurface : Colors.transparent,
                  borderRadius: const BorderRadius.all(Radius.circular(6)),
                ),
                child: Icon(
                  active ? Icons.filter_alt_rounded : Icons.filter_alt_outlined,
                  size: OmniIconSize.md,
                  color: active ? scheme.surface : scheme.onSurface,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Dải tab nhóm việc dưới đầu bảng, kèm vạch đáy. Đọc rổ đã chia để có số.
class _BoardTabs extends ConsumerWidget {
  const _BoardTabs({
    required this.planId,
    required this.person,
    required this.controller,
    required this.current,
  });

  final String planId;
  final BoardPerson person;
  final PageController controller;
  final ValueNotifier<int> current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final board = ref
        .watch(boardBucketsProvider((planId: planId, person: person)))
        .valueOrNull;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      child: SizedBox(
        height: SectionTabs.height,
        width: double.infinity,
        child: board == null
            ? null
            // Chỉ dải tab dựng lại khi lướt trang; các cột đứng yên.
            : ValueListenableBuilder<int>(
                valueListenable: current,
                builder: (context, index, _) => SectionTabs(
                  sections: board.columns,
                  current: index.clamp(0, board.columns.length - 1),
                  countOf: board.countOf,
                  // goTo nhảy thay vì trượt khi người dùng đã tắt hiệu ứng.
                  // Bảng lướt ngang toàn màn hình là đúng loại chuyển động mà
                  // cài đặt đó nhắm tới.
                  onSelected: (i) => controller.goTo(context, i),
                ),
              ),
      ),
    );
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
            // Thanh "Đang lọc" trượt xuống thay vì nhảy ra: bảng đổi hình
            // (cột ngắn đi) nên người dùng cần thấy nó đến từ đâu.
            AnimatedSwitcher(
              duration: OmniMotion.enabled(context)
                  ? const Duration(milliseconds: 300)
                  : Duration.zero,
              transitionBuilder: (child, animation) => SizeTransition(
                sizeFactor: animation,
                alignment: Alignment.topCenter,
                child: child,
              ),
              child: switch (person.chipLabel) {
                final String label => _FilterBar(
                  key: const ValueKey('filter-bar'),
                  label: label,
                  onClear: onClearPerson,
                ),
                null => const SizedBox(
                  key: ValueKey('no-filter'),
                  width: double.infinity,
                ),
              },
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
        // Khe 12 dưới dải tab: dải giờ là mặt trắng, thẻ đầu không được dính
        // vào vạch đáy của nó.
        OmniSpacing.md,
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
  const _FilterBar({super.key, required this.label, required this.onClear});

  final String label;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    // Khối xanh nhạt "Đang lọc: X · Bỏ lọc" (`Plan.dc.html`): cùng cặp màu với
    // chip "hôm nay" của màn Việc, và đổi theo chế độ tối.
    final tone = OmniTaskTones.of(context).today;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        OmniSpacing.lg,
        OmniSpacing.sm,
        OmniSpacing.lg,
        0,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tone.background,
          borderRadius: const BorderRadius.all(Radius.circular(8)),
        ),
        child: Padding(
          padding: const EdgeInsets.only(left: OmniSpacing.md),
          child: Row(
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(text: 'Đang lọc: '),
                      TextSpan(
                        text: label,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  style: OmniType.caption.copyWith(
                    fontWeight: FontWeight.w400,
                    color: tone.foreground,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton(
                onPressed: onClear,
                style: TextButton.styleFrom(
                  foregroundColor: tone.foreground,
                  minimumSize: const Size(64, 44),
                  textStyle: OmniType.caption.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: const Text('Bỏ lọc'),
              ),
            ],
          ),
        ),
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
