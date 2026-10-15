import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/utils/client_id.dart';
import '../../../design/components/components.dart';
import '../../../design/platform/omni_motion_scope.dart';
import '../../../design/tokens/tokens.dart';
import '../../../security/session/api_capabilities.dart';
import '../../../security/session/session_controller.dart';
import '../../tasks/application/tasks_providers.dart';
import '../../tasks/domain/task.dart';
import '../../tasks/routes.dart';
import '../../tasks/tasks.dart';
import '../../tasks/tasks_module.dart';
import '../application/plans_providers.dart';
import '../data/plan_cover_upload.dart';
import '../data/plans_api.dart';
import '../domain/plan.dart';
import '../routes.dart';
import 'archived_tasks_page.dart';
import 'edit_plan_page.dart';
import 'edit_sections_page.dart';
import 'plan_fields_page.dart';
import 'plan_files_page.dart';
import 'plan_members_page.dart';
import 'plan_report_page.dart';
import 'widgets/board_column.dart';
import 'widgets/board_zoom.dart';
import 'widgets/person_filter_sheet.dart';
import 'widgets/plan_copy_move_sheets.dart';
import 'widgets/plan_menu_sheet.dart';
import 'widgets/transfer_owner_sheet.dart';

/// Bảng kế hoạch (`Board.dc.html`): ảnh nền theo `cover`, header kính tối, dải
/// cột 300 kéo ngang có snap căn giữa, hé cột kế bên.
///
/// Bản trước là một cột mỗi trang. Bản mẫu đã duyệt chọn dải cột: hé cột kế
/// là lời mời vuốt tiếp, và đầu cột có số việc nên không cần dải tab riêng.
class PlanBoardPage extends ConsumerStatefulWidget {
  const PlanBoardPage({super.key, required this.planId});

  final String planId;

  @override
  ConsumerState<PlanBoardPage> createState() => _PlanBoardPageState();
}

class _PlanBoardPageState extends ConsumerState<PlanBoardPage> {
  final _track = ScrollController();

  /// Đang lọc theo ai. Sống trong State của màn: đây là cách người dùng đang
  /// NHÌN một cái bảng, không phải một thiết lập của họ.
  BoardPerson _person = BoardPerson.everyone;

  /// Đang mở ô tìm trong header.
  bool _searching = false;
  final _searchField = TextEditingController();
  Timer? _debounce;

  /// Chuỗi tìm đã qua debounce 300ms; rỗng = không lọc.
  String _query = '';

  /// Đã qua khung đầu có thẻ. Chỉ thẻ vào cây ở khung đó mới "rise": cột và
  /// dải là danh sách lười, dựng lại thẻ khi cuộn về hay khi cột kế được cuộn
  /// tới — phát lại hiệu ứng lúc đó đọc như giật. Đổi lọc, tìm hay realtime
  /// cũng không phát lại.
  bool _introDone = false;

  /// Kết quả lượt tìm gần nhất đã về, để giữ trên bảng khi lượt mới đang tải.
  PlanSearchResult? _lastSearch;

  /// Đang ở chế độ thu nhỏ (lưới mọi cột).
  bool _zoomed = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchField.dispose();
    _track.dispose();
    super.dispose();
  }

  bool _firstShow(String taskId) => !_introDone;

  @override
  Widget build(BuildContext context) {
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
    // Chủ/quản lý KẾ HOẠCH cũng sửa được nhóm việc, đúng quyền API (CV-I14).
    final canEditSections =
        loaded != null &&
        (taskAccess.isAssigner ||
            (currentUserId != null &&
                loaded.roleOf(currentUserId).canManagePlan));
    // Sửa kế hoạch (tên, nền, thành viên, trường, đóng, chuyển team) cùng
    // điều kiện với sửa nhóm việc.
    final menuGroups = loaded == null
        ? const <List<PlanMenuAction>>[]
        : planMenuGroups(
            loaded,
            canManage: canEditSections,
            canDelete: canDeletePlan,
            canViewLabels: taskAccess.canReadLabels,
            // Chuyển chủ (Nhóm 2): chủ hiện tại hoặc `manage.all` — quản lý
            // kế hoạch KHÔNG được (`TransferProjectOwner`, 403).
            canTransferOwner:
                ref.watch(
                  apiSupportsProvider(ApiCapability.projectTransferOwner),
                ) &&
                taskAccess.canUpdate &&
                (taskAccess.isAssigner ||
                    (currentUserId != null && loaded.ownerId == currentUserId)),
          );

    final buckets = ref.watch(
      boardBucketsProvider((planId: widget.planId, person: _person)),
    );
    final search = _query.isEmpty
        ? null
        : ref.watch(
            planTaskSearchProvider((planId: widget.planId, query: _query)),
          );
    // Lượt tìm mới đang tải thì giữ kết quả lượt trước trên bảng, thay vì
    // xoá trắng bảng để quay vòng chờ.
    if (search?.valueOrNull case final found?) _lastSearch = found;
    final result =
        search?.valueOrNull ??
        (search != null && !search.hasError ? _lastSearch : null);
    final board = buckets.valueOrNull;
    final visible = board == null || result == null
        ? board
        : board.only(result.ids);
    final scheme = Theme.of(context).colorScheme;
    final coverUrl = resolveProjectCoverUrl(loaded?.cover);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Header luôn là lớp kính tối, kể cả khi phần thân dùng surface sáng.
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: scheme.surface,
        body: Stack(
          key: const Key('board-background'),
          fit: StackFit.expand,
          children: [
            ColoredBox(color: scheme.surface),
            if (coverUrl != null)
              CachedNetworkImage(
                key: const Key('board-cover-image'),
                imageUrl: coverUrl,
                fit: BoxFit.cover,
                color: Colors.black.withValues(alpha: .14),
                colorBlendMode: BlendMode.darken,
                placeholder: (_, _) => ColoredBox(color: scheme.surface),
                errorWidget: (_, _, _) => ColoredBox(color: scheme.surface),
              ),
            Column(
              children: [
                _GlassHeader(
                  title: loaded?.name ?? 'Kế hoạch',
                  subtitle: _subtitle(loaded, visible),
                  searching: _searching,
                  searchField: _searchField,
                  onSearchChanged: _onSearchChanged,
                  onBack: _back,
                  onOpenSearch: () => setState(() => _searching = true),
                  onCloseSearch: _closeSearch,
                  filterActive: _person.chipLabel != null,
                  onFilter: _pickPerson,
                  onMenu: menuGroups.isNotEmpty
                      ? (anchor) => _planMenu(loaded!, menuGroups, anchor)
                      : null,
                ),
                if (loaded != null && loaded.planStatus != PlanStatus.active)
                  _ClosedBanner(
                    status: loaded.planStatus,
                    onReopen: canEditSections
                        ? () => _patchPlan(
                            loaded,
                            PlanPatch(status: PlanStatus.active),
                            done: 'Đã mở lại kế hoạch.',
                          )
                        : null,
                  ),
                Expanded(
                  child: OmniAsyncView(
                    value: plan,
                    onRetry: () => ref.invalidate(planProvider(widget.planId)),
                    data: (plan) => OmniAsyncView(
                      value: buckets,
                      onRetry: () =>
                          ref.invalidate(planTasksProvider(widget.planId)),
                      data: (board) => search == null || result != null
                          ? _body(
                              plan,
                              result == null ? board : board.only(result.ids),
                              canCreate: taskAccess.canCreate,
                              canComplete: taskAccess.canComplete,
                              canEditSections: canEditSections,
                              searchCapped: result != null && result.capped
                                  ? result.ids.length
                                  : null,
                            )
                          : OmniAsyncView(
                              value: search,
                              onRetry: () => ref.invalidate(
                                planTaskSearchProvider((
                                  planId: widget.planId,
                                  query: _query,
                                )),
                              ),
                              data: (found) => _body(
                                plan,
                                board.only(found.ids),
                                canCreate: taskAccess.canCreate,
                                canComplete: taskAccess.canComplete,
                                canEditSections: canEditSections,
                                searchCapped: found.capped
                                    ? found.ids.length
                                    : null,
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _subtitle(Plan? plan, BoardBuckets? board) {
    final shown = board?.total ?? plan?.taskCount ?? 0;
    return [
      if (plan?.teamName case final team? when team.isNotEmpty) team,
      '$shown việc',
    ].join(' · ');
  }

  Widget _body(
    Plan plan,
    BoardBuckets board, {
    required bool canCreate,
    required bool canComplete,
    required bool canEditSections,
    int? searchCapped,
  }) {
    final columns = board.columns;
    if (!_introDone) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _introDone = true);
    }
    final realSections = plan.sections;
    final itemCount = columns.length + (canEditSections ? 1 : 0);

    final content = Column(
      children: [
        if (board.truncated) const _TruncatedNotice(),
        if (searchCapped case final n?)
          _TruncatedNotice(text: 'Đang hiện $n kết quả đầu'),
        // Thanh "Đang lọc" trượt xuống thay vì nhảy ra: bảng đổi hình (cột
        // ngắn đi) nên người dùng cần thấy nó đến từ đâu.
        AnimatedSwitcher(
          duration: OmniMotion.enabled(context)
              ? const Duration(milliseconds: 300)
              : Duration.zero,
          transitionBuilder: (child, animation) => SizeTransition(
            sizeFactor: animation,
            alignment: Alignment.topCenter,
            child: child,
          ),
          child: switch (_person.chipLabel) {
            final String label => _FilterBar(
              key: const ValueKey('filter-bar'),
              label: label,
              onClear: () => setState(() => _person = BoardPerson.everyone),
            ),
            null => const SizedBox(
              key: ValueKey('no-filter'),
              width: double.infinity,
            ),
          },
        ),
        Expanded(
          child: _zoomed
              ? BoardZoomGrid(
                  columns: columns,
                  buckets: board.buckets,
                  onOpenColumn: _openColumn,
                )
              : ListView.separated(
                  key: const Key('board-track'),
                  controller: _track,
                  scrollDirection: Axis.horizontal,
                  physics: BoardSnapPhysics(
                    count: itemCount,
                    animate: OmniMotion.enabled(context),
                  ),
                  padding: const EdgeInsets.fromLTRB(
                    BoardMetrics.inset,
                    BoardMetrics.top,
                    BoardMetrics.inset,
                    BoardMetrics.bottom,
                  ),
                  itemCount: itemCount,
                  separatorBuilder: (_, _) =>
                      const SizedBox(width: BoardMetrics.gap),
                  itemBuilder: (context, index) {
                    if (index == columns.length) {
                      return Align(
                        alignment: Alignment.topCenter,
                        child: BoardAddSectionTile(
                          onTap: () => _addSection(plan, board),
                        ),
                      );
                    }
                    final section = columns[index];
                    // Cột "Tất cả công việc" của kế hoạch chưa khai nhóm việc là cột
                    // dựng tạm, không có gì để đổi tên hay xoá.
                    final real = section.id.isNotEmpty;

                    return Align(
                      alignment: Alignment.topCenter,
                      child: SizedBox(
                        width: BoardMetrics.columnWidth,
                        child: BoardColumn(
                          section: section,
                          tasks: board.buckets[index],
                          firstShow: _firstShow,
                          canComplete: canComplete,
                          onOpenTask: (task) => context.pushNamed(
                            TasksModule.detail,
                            pathParameters: {'id': task.id},
                          ),
                          onAddTask: canCreate
                              ? () =>
                                    _createTask(plan, real ? section.id : null)
                              : null,
                          onOptions: canEditSections && real
                              ? (anchor) => _sectionOptions(
                                  plan,
                                  board,
                                  section,
                                  anchor: anchor,
                                  canRemove: realSections.length > 1,
                                )
                              : null,
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );

    return Stack(
      children: [
        Positioned.fill(child: content),
        Positioned(
          right: 16,
          bottom: 34 + MediaQuery.paddingOf(context).bottom,
          child: BoardZoomButton(
            zoomed: _zoomed,
            onTap: () => setState(() => _zoomed = !_zoomed),
          ),
        ),
      ],
    );
  }

  /// Từ lưới thu nhỏ về bảng, cột [index] căn giữa màn.
  void _openColumn(int index) {
    setState(() => _zoomed = false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_track.hasClients) return;
      final target = BoardSnapPhysics.offsetOf(index, _track.position);
      if (OmniMotion.enabled(context)) {
        _track.animateTo(
          target,
          duration: const Duration(milliseconds: 350),
          curve: OmniCurves.standard,
        );
      } else {
        _track.jumpTo(target);
      }
    });
  }

  void _back() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    } else {
      // Mở thẳng bằng liên kết sâu: không có gì phía sau, về tab Việc.
      context.goNamed(PlanRoutes.teams);
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() => _query = value.trim());
    });
  }

  void _closeSearch() {
    _debounce?.cancel();
    _searchField.clear();
    setState(() {
      _searching = false;
      _query = '';
      _lastSearch = null;
    });
  }

  Future<void> _pickPerson(Rect anchor) async {
    final picked = await showPersonFilterMenu(
      context,
      anchor: anchor,
      current: _person,
    );
    if (picked != null && mounted) setState(() => _person = picked);
  }

  /// Mở màn tạo việc với kế hoạch + nhóm của cột đã chạm điền sẵn.
  Future<void> _createTask(Plan plan, String? sectionId) async {
    final created = await context.pushNamed<String>(
      TaskRoutes.create,
      extra: CreateTaskArgs(
        planId: plan.id,
        sectionId: sectionId,
        // Chép sang value type của module tasks: tasks không biết `PlanSection`.
        sections: [
          for (final s in plan.sections) TaskSection(id: s.id, name: s.name),
        ],
      ),
    );

    if (created != null && mounted) {
      ref.invalidate(planTasksProvider(widget.planId));
    }
  }

  /// ⋯ của kế hoạch: menu neo tại nút, cùng mẫu với dấu + ở màn Team. Sửa
  /// nhóm việc vẫn nằm ở ⋯ của cột và ô "Thêm nhóm việc".
  Future<void> _planMenu(
    Plan plan,
    List<List<PlanMenuAction>> groups,
    Rect anchor,
  ) async {
    final choice = await showPlanMenu(
      context,
      anchor: anchor,
      plan: plan,
      groups: groups,
    );
    if (!mounted || choice == null) return;
    final navigator = Navigator.of(context);
    switch (choice) {
      case PlanMenuAction.edit:
        await navigator.push(
          MaterialPageRoute<bool>(
            builder: (_) => EditPlanPage(planId: plan.id),
          ),
        );
      case PlanMenuAction.members:
        await navigator.push(
          MaterialPageRoute<bool>(
            builder: (_) => PlanMembersPage(planId: plan.id),
          ),
        );
      case PlanMenuAction.labels:
        await showLabelsSheet(context);
      case PlanMenuAction.fields:
        await navigator.push(
          MaterialPageRoute<bool>(
            builder: (_) => PlanFieldsPage(planId: plan.id),
          ),
        );
      case PlanMenuAction.copy:
        await _copyPlan(plan);
      case PlanMenuAction.moveTeam:
        await _moveTeam(plan);
      case PlanMenuAction.archived:
        await navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => ArchivedTasksPage(
              planId: plan.id,
              canRestore: _canEditTasks(plan),
            ),
          ),
        );
      case PlanMenuAction.files:
        await navigator.push(
          MaterialPageRoute<void>(
            builder: (_) =>
                PlanFilesPage(planId: plan.id, canDelete: _canEditTasks(plan)),
          ),
        );
      case PlanMenuAction.report:
        await navigator.push(
          MaterialPageRoute<void>(
            builder: (_) =>
                PlanReportPage(planId: plan.id, canConfigure: _canManage(plan)),
          ),
        );
      case PlanMenuAction.transferOwner:
        await _transferOwner(plan);
      case PlanMenuAction.close:
        await _closePlan(plan);
      case PlanMenuAction.reopen:
        await _patchPlan(
          plan,
          PlanPatch(status: PlanStatus.active),
          done: 'Đã mở lại kế hoạch.',
        );
      case PlanMenuAction.delete:
        await _deletePlan(plan);
    }
  }

  /// Ghi được việc trong kế hoạch: `tasks.write` và không mang vai người xem
  /// — đúng `ProjectAccessService::assertCanEditTasks` (chỉ vai `viewer` bị
  /// chặn; người ngoài danh sách thành viên vẫn ghi được).
  bool _canEditTasks(Plan plan) {
    if (!ref.read(taskAccessProvider).canUpdate) return false;
    final me = ref.read(sessionProvider).user?.id;
    if (me == null) return true;
    return plan.ownerId == me || plan.memberRoles[me] != PlanRole.viewer;
  }

  /// Như `canEditSections` trong build: người giao việc hoặc chủ / quản lý.
  bool _canManage(Plan plan) {
    if (ref.read(taskAccessProvider).isAssigner) return true;
    final me = ref.read(sessionProvider).user?.id;
    return me != null && plan.roleOf(me).canManagePlan;
  }

  /// Gửi [patch], làm mới kế hoạch và tab Việc; báo [done] khi xong.
  Future<bool> _patchPlan(Plan plan, PlanPatch patch, {String? done}) async {
    final messenger = ScaffoldMessenger.of(context);
    final container = ProviderScope.containerOf(context);
    try {
      await container.read(plansApiProvider).updatePlan(plan.id, patch);
      container.invalidate(planProvider(plan.id));
      container.invalidate(teamsWithPlansProvider);
      if (done != null) {
        messenger.showSnackBar(SnackBar(content: Text(done)));
      }
      return true;
    } on AppException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
      return false;
    }
  }

  /// Chuyển chủ: chọn người, hỏi lại, rồi `POST /projects/{id}/transfer-owner`.
  /// Chủ cũ thành quản lý (mặc định của server).
  Future<void> _transferOwner(Plan plan) async {
    final picked = await showTransferOwnerSheet(
      context,
      currentOwnerId: plan.ownerId,
    );
    if (picked == null || !mounted) return;
    final confirmed = await showOmniConfirm(
      context: context,
      title: 'Chuyển chủ cho ${picked.name}?',
      message:
          '${picked.name} sẽ là chủ kế hoạch “${plan.name}”. Chủ hiện tại '
          'trở thành quản lý kế hoạch.',
      confirmLabel: 'Chuyển chủ',
    );
    if (!confirmed || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final container = ProviderScope.containerOf(context);
    try {
      await container
          .read(plansApiProvider)
          .transferOwner(plan.id, ownerId: picked.userId);
      container.invalidate(planProvider(plan.id));
      container.invalidate(teamsWithPlansProvider);
      messenger.showSnackBar(
        SnackBar(content: Text('Đã chuyển chủ cho ${picked.name}.')),
      );
    } on AppException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _closePlan(Plan plan) async {
    final confirmed = await showOmniConfirm(
      context: context,
      title: 'Đóng kế hoạch “${plan.name}”?',
      message:
          'Kế hoạch sẽ không còn hiện ở tab Việc. Công việc vẫn giữ nguyên, '
          'và mở lại được từ menu kế hoạch.',
      confirmLabel: 'Đóng kế hoạch',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    final ok = await _patchPlan(
      plan,
      PlanPatch(status: PlanStatus.done),
      done: 'Đã đóng kế hoạch.',
    );
    if (ok && mounted) context.goNamed(PlanRoutes.teams);
  }

  Future<void> _copyPlan(Plan plan) async {
    final choice = await showCopyPlanSheet(context, plan);
    if (choice == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final container = ProviderScope.containerOf(context);
    final router = GoRouter.of(context);
    try {
      final copy = await container
          .read(plansApiProvider)
          .copyPlan(
            plan.id,
            name: choice.name,
            copyTasks: choice.copyTasks,
            asTemplate: choice.asTemplate,
          );
      container.invalidate(teamsWithPlansProvider);
      if (!mounted) return;
      // Mẫu không mở được trong app (tab Việc không liệt kê mẫu): ở lại bảng.
      if (choice.asTemplate) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Đã lưu làm mẫu. Dùng mẫu trên web.')),
        );
        return;
      }
      router.pushReplacementNamed(
        PlanRoutes.board,
        pathParameters: {'id': copy.id},
      );
    } on AppException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _moveTeam(Plan plan) async {
    final groups = await ref.read(teamsWithPlansProvider.future);
    if (!mounted) return;
    final target = await showMoveTeamSheet(
      context,
      plan: plan,
      teams: [
        for (final group in groups)
          if (!group.synthetic && group.team.id.isNotEmpty) group.team,
      ],
    );
    if (target == null || !mounted) return;
    await switch (target) {
      PlanTeamTo(:final team) => _patchPlan(
        plan,
        PlanPatch(teamId: team.id),
        done: 'Đã chuyển sang ${team.name}.',
      ),
      PlanTeamNone() => _patchPlan(
        plan,
        PlanPatch(clearTeam: true),
        done: 'Kế hoạch không còn thuộc team nào.',
      ),
    };
  }

  Future<void> _sectionOptions(
    Plan plan,
    BoardBuckets board,
    PlanSection section, {
    required Rect anchor,
    required bool canRemove,
  }) async {
    final choice = await _optionsMenu<_SectionAction>(anchor, section.name, [
      (_SectionAction.rename, Icons.edit_outlined, 'Đổi tên nhóm'),
      (_SectionAction.reorder, Icons.swap_vert_rounded, 'Sắp xếp nhóm việc'),
      if (canRemove) (_SectionAction.remove, Icons.delete_outline, 'Xoá nhóm'),
    ], danger: _SectionAction.remove);
    if (!mounted) return;
    switch (choice) {
      case _SectionAction.rename:
        final name = await _askName(
          title: 'Đổi tên nhóm',
          initial: section.name,
        );
        if (name == null || name == section.name || !mounted) return;
        await _saveSections([
          for (final s in plan.sections)
            s.id == section.id ? _copy(s, name: name) : s,
        ]);
      case _SectionAction.remove:
        await _removeSection(plan, board, section);
      case _SectionAction.reorder:
        await _editSections();
      case null:
        break;
    }
  }

  Future<void> _removeSection(
    Plan plan,
    BoardBuckets board,
    PlanSection section,
  ) async {
    // Đếm trên CẢ kế hoạch, không trên [board]: bảng có thể đang lọc theo
    // người hoặc đang tìm, và cột đầu còn chứa việc mồ côi không thuộc nhóm.
    final all = ref.read(planTasksProvider(widget.planId)).valueOrNull;
    final count = [
      for (final t in all?.tasks ?? const <Task>[])
        if (t.sectionId == section.id) t,
    ].length;
    final atLeast = all?.truncated ?? false;
    // Web và app xếp việc mất nhóm khác nhau, nên chỉ nói điều đúng ở cả
    // hai: việc thành chưa xếp nhóm.
    final parts = [
      if (count > 0)
        '${atLeast ? 'Ít nhất $count' : '$count'} việc trong nhóm này sẽ '
            'thành chưa xếp nhóm.'
      else if (atLeast)
        'Việc trong nhóm này (nếu có) sẽ thành chưa xếp nhóm.'
      else
        'Nhóm việc này sẽ biến mất trên cả điện thoại và web.',
      if (section.countsForKpi)
        'Nhóm này đang được tính vào KPI; xoá nhóm là bỏ luôn thiết lập đó.',
      if (section.requiresChecklist)
        'Nhóm này đang bắt buộc xong việc con; xoá nhóm là bỏ luôn thiết lập '
            'đó.',
    ];
    final confirmed = await showOmniConfirm(
      context: context,
      title: 'Xoá nhóm “${section.name}”?',
      message: parts.join(' '),
      confirmLabel: 'Xoá nhóm',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    await _saveSections([
      for (final s in plan.sections)
        if (s.id != section.id) s,
    ]);
  }

  Future<void> _addSection(Plan plan, BoardBuckets board) async {
    final name = await _askName(title: 'Thêm nhóm việc');
    if (name == null || !mounted) return;

    // Id ngẫu nhiên, như server và web (`crypto.randomUUID`). Id đoán được
    // (`sN`) có thể trùng một nhóm đã xoá mà việc còn trỏ tới — kể cả việc
    // không nằm trên bảng này (đã lưu trữ, quá trần) — và các việc đó sẽ lặng
    // lẽ hiện vào nhóm mới.
    await _saveSections([
      ...plan.sections,
      PlanSection(id: newClientId(), name: name, order: plan.sections.length),
    ]);
  }

  /// Gửi cả mảng nhóm việc (API thay cả mảng), giữ id và hai cờ của từng nhóm.
  Future<void> _saveSections(List<PlanSection> sections) async {
    final messenger = ScaffoldMessenger.of(context);
    final container = ProviderScope.containerOf(context);
    try {
      await container.read(plansApiProvider).updateSections(widget.planId, [
        for (var i = 0; i < sections.length; i++) _copy(sections[i], order: i),
      ]);
      container.invalidate(planProvider(widget.planId));
    } on AppException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  static PlanSection _copy(PlanSection s, {String? name, int? order}) =>
      PlanSection(
        id: s.id,
        name: name ?? s.name,
        order: order ?? s.order,
        requiresChecklist: s.requiresChecklist,
        countsForKpi: s.countsForKpi,
      );

  Future<String?> _askName({required String title, String initial = ''}) =>
      showOmniSheet<String>(
        context: context,
        builder: (_) => _NameSheet(title: title, initial: initial),
      );

  Future<T?> _optionsMenu<T>(
    Rect anchor,
    String title,
    List<(T, IconData, String)> items, {
    required T danger,
  }) => showOmniAnchoredMenu<T>(
    context: context,
    anchor: anchor,
    width: 276,
    menuKey: const Key('section-options-menu'),
    semanticsLabel: 'Tuỳ chọn nhóm việc',
    builder: (menuContext) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          alignment: Alignment.centerLeft,
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: OmniType.bodyStrong.copyWith(
              color: Theme.of(menuContext).colorScheme.onSurface,
            ),
          ),
        ),
        for (var i = 0; i < items.length; i++)
          OmniAnchoredMenuItem(
            icon: items[i].$2,
            label: items[i].$3,
            divider: i == 0 || items[i].$1 == danger,
            destructive: items[i].$1 == danger,
            onTap: () => Navigator.of(menuContext).pop(items[i].$1),
          ),
      ],
    ),
  );

  Future<void> _editSections() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EditSectionsPage(planId: widget.planId),
      ),
    );
  }

  Future<void> _deletePlan(Plan plan) async {
    final messenger = ScaffoldMessenger.of(context);
    final container = ProviderScope.containerOf(context);
    final confirmed = await showOmniConfirm(
      context: context,
      title: 'Xoá kế hoạch “${plan.name}”?',
      message:
          'Toàn bộ công việc trong kế hoạch cũng sẽ được chuyển vào thùng rác. '
          'Khôi phục được (kèm công việc) từ thùng rác trên web. Thao tác sẽ '
          'đồng bộ trên web và điện thoại.',
      confirmLabel: 'Xoá kế hoạch',
      destructive: true,
    );
    if (!confirmed) return;

    try {
      await container.read(plansApiProvider).deletePlan(plan.id);
      container.invalidate(teamsWithPlansProvider);
      container.invalidate(planProvider(plan.id));
      container.invalidate(planTasksProvider(plan.id));
      container.read(taskRealtimeSignalProvider.notifier).bump();
      if (!mounted) return;
      _back();
      messenger.showSnackBar(const SnackBar(content: Text('Đã xoá kế hoạch.')));
    } on AppException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    }
  }
}

enum _SectionAction { rename, remove, reorder }

/// Header kính tối (`.bar`): `OmniCovers.glass` + blur 20, hàng 44 dưới
/// safe area, đệm 4 hai bên và 6 ở đáy.
class _GlassHeader extends StatelessWidget {
  const _GlassHeader({
    required this.title,
    required this.subtitle,
    required this.searching,
    required this.searchField,
    required this.onSearchChanged,
    required this.onBack,
    required this.onOpenSearch,
    required this.onCloseSearch,
    required this.filterActive,
    required this.onFilter,
    required this.onMenu,
  });

  final String title;
  final String subtitle;
  final bool searching;
  final TextEditingController searchField;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onBack;
  final VoidCallback onOpenSearch;
  final VoidCallback onCloseSearch;
  final bool filterActive;
  final ValueChanged<Rect> onFilter;
  final ValueChanged<Rect>? onMenu;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;

    return ClipRect(
      key: const Key('board-header'),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: OmniCovers.glassBlur,
          sigmaY: OmniCovers.glassBlur,
        ),
        child: ColoredBox(
          color: OmniCovers.glass,
          child: Padding(
            padding: EdgeInsets.fromLTRB(4, top, 4, 6),
            child: SizedBox(
              height: 44,
              child: Row(
                children: [
                  _HeaderButton(
                    tooltip: 'Quay lại',
                    icon: Icons.arrow_back_ios_new_rounded,
                    onTap: onBack,
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    child: searching
                        ? _HeaderSearch(
                            controller: searchField,
                            onChanged: onSearchChanged,
                          )
                        : _HeaderTitle(title: title, subtitle: subtitle),
                  ),
                  if (searching)
                    _HeaderButton(
                      tooltip: 'Đóng tìm kiếm',
                      icon: Icons.close_rounded,
                      onTap: onCloseSearch,
                    )
                  else
                    _HeaderButton(
                      tooltip: 'Tìm trong kế hoạch',
                      icon: Icons.search_rounded,
                      onTap: onOpenSearch,
                    ),
                  Builder(
                    builder: (buttonContext) => _HeaderButton(
                      tooltip: 'Lọc theo người',
                      icon: Icons.person_outline_rounded,
                      onTap: () {
                        final box =
                            buttonContext.findRenderObject() as RenderBox?;
                        if (box == null || !box.hasSize) return;
                        onFilter(box.localToGlobal(Offset.zero) & box.size);
                      },
                      dot: filterActive,
                      selected: filterActive,
                    ),
                  ),
                  if (onMenu case final menu?)
                    Builder(
                      builder: (buttonContext) => _HeaderButton(
                        tooltip: 'Tuỳ chọn kế hoạch',
                        icon: Icons.more_horiz_rounded,
                        onTap: () {
                          final box =
                              buttonContext.findRenderObject() as RenderBox?;
                          if (box == null || !box.hasSize) return;
                          menu(box.localToGlobal(Offset.zero) & box.size);
                        },
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

class _HeaderTitle extends StatelessWidget {
  const _HeaderTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: OmniType.section.copyWith(height: 1.25, color: Colors.white),
          ),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: OmniType.micro.copyWith(
              fontWeight: FontWeight.w400,
              color: Colors.white.withValues(alpha: .82),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderSearch extends StatelessWidget {
  const _HeaderSearch({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      autofocus: true,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      cursorColor: Colors.white,
      style: OmniType.search.copyWith(
        color: Colors.white,
        fontStyle: FontStyle.normal,
      ),
      decoration: InputDecoration(
        isDense: true,
        filled: false,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        hintText: 'Tìm trong kế hoạch',
        hintStyle: OmniType.searchHint.copyWith(
          color: Colors.white.withValues(alpha: .7),
        ),
      ),
    );
  }
}

/// `.hb`: 44×44, bo 6, biểu tượng trắng. [dot] = đang lọc.
class _HeaderButton extends StatelessWidget {
  const _HeaderButton({
    required this.tooltip,
    required this.icon,
    required this.onTap,
    this.dot = false,
    this.selected = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;
  final bool dot;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      child: IconButton(
        tooltip: tooltip,
        onPressed: onTap,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 44, height: 44),
        style: IconButton.styleFrom(
          foregroundColor: Colors.white,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(6)),
          ),
        ),
        icon: Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(icon, size: OmniIconSize.lg, color: Colors.white),
            if (dot)
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  key: const Key('filter-dot'),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: OmniTaskTones.of(context).priorityNormal,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Sheet nhập tên nhóm việc: một ô, nút "Lưu". Tên rỗng thì không lưu.
class _NameSheet extends StatefulWidget {
  const _NameSheet({required this.title, required this.initial});

  final String title;
  final String initial;

  @override
  State<_NameSheet> createState() => _NameSheetState();
}

class _NameSheetState extends State<_NameSheet> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.title,
              style: OmniType.bodyStrong.copyWith(color: scheme.onSurface),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              autofocus: true,
              maxLength: 128,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              decoration: const InputDecoration(
                hintText: 'Tên nhóm việc',
                counterText: '',
              ),
            ),
            const SizedBox(height: 12),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _controller,
              builder: (context, value, _) => FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: value.text.trim().isEmpty ? null : _submit,
                child: const Text('Lưu'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Thanh "Đang lọc: X · Bỏ lọc". Một cái bảng đang lọc trông y hệt một cái
/// bảng vắng việc; thanh này phân biệt hai chuyện đó, và có đường ra ngay cạnh.
class _FilterBar extends StatelessWidget {
  const _FilterBar({super.key, required this.label, required this.onClear});

  final String label;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final tone = OmniTaskTones.of(context).today;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        BoardMetrics.inset,
        OmniSpacing.md,
        BoardMetrics.inset,
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

/// Kế hoạch vượt trần: bảng chỉ vẽ được một phần, và phải nói ra.
class _TruncatedNotice extends StatelessWidget {
  const _TruncatedNotice({this.text});

  /// null = câu mặc định về trần [kMaxTasksOnBoard] của bảng.
  final String? text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final warning = OmniColors.warningTextOf(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        BoardMetrics.inset,
        OmniSpacing.md,
        BoardMetrics.inset,
        0,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: const BorderRadius.all(Radius.circular(8)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(OmniSpacing.md),
          child: Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: OmniIconSize.sm,
                color: warning,
              ),
              const SizedBox(width: OmniSpacing.sm),
              Expanded(
                child: Text(
                  text ??
                      'Kế hoạch này có hơn $kMaxTasksOnBoard việc. Bảng đang '
                          'hiện $kMaxTasksOnBoard việc đầu theo thứ tự trên '
                          'bảng.',
                  style: OmniType.caption.copyWith(color: warning),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dải dưới header khi kế hoạch đã đóng / lưu trữ: nói rõ trạng thái, và với
/// người quản lý có "Mở lại" ngay tại chỗ (tab Việc đã gập kế hoạch này dưới
/// "Đã đóng (N)").
class _ClosedBanner extends StatelessWidget {
  const _ClosedBanner({required this.status, this.onReopen});

  final PlanStatus status;
  final VoidCallback? onReopen;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final label = status == PlanStatus.archived
        ? 'Kế hoạch đã lưu trữ'
        : 'Kế hoạch đã đóng';

    return Container(
      key: const Key('plan-closed-banner'),
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.fromLTRB(12, 0, 4, 0),
      constraints: const BoxConstraints(minHeight: 44),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.lock_outline_rounded,
            size: OmniIconSize.sm,
            color: scheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: OmniType.bodySm.copyWith(
                fontWeight: FontWeight.w500,
                color: scheme.onSurface,
              ),
            ),
          ),
          if (onReopen != null)
            TextButton(
              style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
              onPressed: onReopen,
              child: const Text('Mở lại'),
            ),
        ],
      ),
    );
  }
}
