import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/web_links.dart';
import '../../../core/error/app_exception.dart';
import '../../../core/utils/client_id.dart';
import '../../../core/utils/copy_link.dart';
import '../../../design/components/components.dart';
import '../../../design/platform/omni_motion_scope.dart';
import '../../../design/tokens/tokens.dart';
import '../../../security/session/api_capabilities.dart';
import '../../../security/session/session_controller.dart';
import '../../tasks/application/tasks_providers.dart';
import '../../tasks/data/tasks_api.dart';
import '../../tasks/domain/task.dart';
import '../../tasks/routes.dart';
import '../../tasks/tasks.dart';
import '../../tasks/tasks_module.dart';
import '../application/plans_providers.dart';
import '../data/plans_api.dart';
import '../domain/board_drop.dart';
import '../domain/plan.dart';
import '../routes.dart';
import 'archived_tasks_page.dart';
import 'edit_plan_page.dart';
import 'edit_sections_page.dart';
import 'plan_fields_page.dart';
import 'plan_files_page.dart';
import 'plan_members_page.dart';
import 'plan_report_page.dart';
import 'section_order_page.dart';
import 'widgets/board_column.dart';
import 'widgets/board_drag.dart';
import 'widgets/board_zoom.dart';
import 'widgets/person_filter_sheet.dart';
import 'widgets/project_cover.dart';
import 'widgets/plan_copy_move_sheets.dart';
import 'widgets/plan_menu_sheet.dart';
import 'widgets/transfer_owner_sheet.dart';

/// Bảng kế hoạch (`Board.dc.html`): nền theo `cover`, header kính tối, dải
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

  /// Lượt kéo đang diễn ra (thẻ, cột đích, chỗ chèn).
  final _drag = BoardDragController();

  /// Con trỏ đang ở mép nào của dải: -1 trái, 1 phải, 0 không. Dải sáng 28px
  /// ở mép đó, và [_edgeTimer] sang cột kế mỗi 700ms.
  final _edgeSide = ValueNotifier<int>(0);
  Timer? _edgeTimer;

  /// Số ô trên dải (cột + ô "Thêm nhóm việc"), để tự trượt không vượt cuối.
  int _trackCount = 1;

  /// Bảng đang vẽ (đã gồm thẻ lạc quan), để thả và dò lại cột sau khi trượt.
  BoardBuckets? _board;

  /// Thẻ vừa thả, đang chờ server: bảng vẽ nó ở chỗ mới ngay (lạc quan). Xoá
  /// khi dữ liệu mới về hoặc khi lưu lỗi.
  ({String taskId, int toColumn, int index, String sectionId, double? order})?
  _pending;

  /// Các ngón đang chạm, theo thứ tự chạm; và ngón đang giữ thẻ (ngón chạm
  /// gần nhất lúc thẻ nhấc lên). Chỉ ngón ấy nhấc lên mới kết thúc lượt kéo.
  final _pointers = <int>[];
  int? _dragPointer;

  @override
  void initState() {
    super.initState();
    _drag.addListener(_onDragState);
  }

  void _onDragState() {
    if (_drag.active && _dragPointer == null && _pointers.isNotEmpty) {
      _dragPointer = _pointers.last;
    }
  }

  /// Ngón [pointer] nhấc lên ([drop]) hoặc bị huỷ. Ngón đang giữ thẻ nhấc lên
  /// thì thả vào ĐÍCH của [_drag] — đọc trước khi dọn. Không dựa vào
  /// `DragTarget` nhận thả: sau khi dải tự trượt, Flutter không dò lại đích
  /// khi ngón tay đứng yên, nên cột nhận thả là cột đã trôi khỏi dưới ngón.
  void _pointerEnded(int pointer, {required bool drop}) {
    _pointers.remove(pointer);
    if (_dragPointer != null && pointer != _dragPointer) return;
    final task = _drag.task;
    final to = _drag.targetColumn;
    final index = _drag.targetIndex;
    final board = _board;
    _endDrag();
    if (!drop || task == null || to == null || index == null) return;
    if (board == null || to >= board.columns.length) return;
    unawaited(_drop(board, task, to, index, board.columns[to].id));
  }

  /// Ngón giữ thẻ di chuyển. Bắt ở đây chứ không chỉ ở `onDragUpdate` của
  /// thẻ: thẻ nguồn có thể đã rời cây khi dải trượt xa.
  void _pointerMoved(PointerMoveEvent e) {
    if (!_drag.active || e.pointer != _dragPointer) return;
    _drag.pointer = e.position;
    _onDragUpdate(e.position);
  }

  /// Sau khi dải trượt xong: tìm cột đang dưới ngón (theo vị trí cuộn và
  /// bước cột) và chỗ chèn trong nó, rồi đặt làm đích.
  void _retarget() {
    if (!mounted) return;
    final pointer = _drag.pointer;
    final board = _board;
    final box = context.findRenderObject();
    if (!_drag.active || pointer == null || board == null) return;
    if (!_track.hasClients || box is! RenderBox || !box.hasSize) return;
    final x =
        _track.offset + box.globalToLocal(pointer).dx - BoardMetrics.inset;
    final column = (x / BoardMetrics.pitch).floor();
    final inColumn =
        column >= 0 &&
        column < board.columns.length &&
        x - column * BoardMetrics.pitch < BoardMetrics.columnWidth;
    final index = inColumn ? _drag.indexAt(column, pointer) : null;
    if (index == null) {
      _drag.clearTarget();
    } else {
      _drag.hover(column, index, board.columns[column].name);
    }
  }

  /// Dò lại đích ở khung kế (khi các cột đã dựng ở vị trí mới).
  void _retargetAfterLayout() {
    if (!mounted) return;
    WidgetsBinding.instance
      ..addPostFrameCallback((_) => _retarget())
      ..ensureVisualUpdate();
  }

  @override
  void dispose() {
    _drag.removeListener(_onDragState);
    _edgeTimer?.cancel();
    _edgeSide.dispose();
    _drag.dispose();
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

    // Kéo thẻ (R1, R2, R5): `tasks.write`, không mang vai người xem ghi rõ,
    // không đang thu nhỏ; thẻ khoá thì không nhấc (canDrag). KHÔNG dùng
    // `manage.all` — nó mở quyền quản kế hoạch, không mở quyền sửa việc.
    final canDragTasks =
        taskAccess.canUpdate &&
        !(loaded?.isTaskViewer(currentUserId) ?? false) &&
        !_zoomed;

    // Dữ liệu mới về (sau khi thả) là sự thật: bỏ phần vẽ lạc quan.
    // Chỉ khi dữ liệu mới ĐÃ có việc ở nhóm mới (hoặc việc không còn): một lượt
    // tải lại bắt đầu trước khi PUT xong vẫn thấy thẻ ở nhóm cũ, và xoá lúc đó
    // là làm thẻ bật về chỗ cũ rồi nhảy lại.
    ref.listen(planTasksProvider(widget.planId), (_, next) {
      final pending = _pending;
      if (pending == null || next is! AsyncData<PlanTasks>) return;
      final now = next.value.tasks.where((t) => t.id == pending.taskId);
      final saved = now.firstOrNull;
      final sectionSaved = saved?.sectionId == pending.sectionId;
      final orderSaved =
          pending.order == null ||
          (saved != null &&
              saved.hasOrder &&
              (saved.order - pending.order!).abs() < 0.000001);
      if (saved == null || (sectionSaved && orderSaved)) {
        setState(() => _pending = null);
      }
    });

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

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: OmniCovers.colorOf(loaded?.cover),
        body: ProjectCoverSurface(
          key: const Key('board-background'),
          cover: loaded?.cover,
          color: loaded?.color,
          child: Column(
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
                    ? () => _planMenu(loaded!, menuGroups)
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
                            canDragTasks: canDragTasks,
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
                              canDragTasks: canDragTasks,
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
    required bool canDragTasks,
    int? searchCapped,
  }) {
    if (_pending case final p?) {
      board = board.moved(p.taskId, p.toColumn, p.index, p.sectionId);
    }
    final columns = board.columns;
    if (!_introDone) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _introDone = true);
    }
    final realSections = plan.sections;
    final itemCount = columns.length + (canEditSections ? 1 : 0);
    _trackCount = itemCount;
    _board = board;

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
                          columnIndex: index,
                          // Cột dựng tạm (id rỗng) không có nhóm để thả vào.
                          drag:
                              canDragTasks &&
                                  real &&
                                  !board.truncated &&
                                  _pending == null
                              ? _drag
                              : null,
                          canDrag: (t) =>
                              canDragTasks &&
                              !board.truncated &&
                              _pending == null &&
                              !t.isLocked,
                          onDragUpdate: _onDragUpdate,
                          onDragEnd: _endDrag,
                          onOpenTask: (task) => context.pushNamed(
                            TasksModule.detail,
                            pathParameters: {'id': task.id},
                          ),
                          onAddTask: canCreate
                              ? () =>
                                    _createTask(plan, real ? section.id : null)
                              : null,
                          onOptions: canEditSections && real
                              ? () => _sectionOptions(
                                  plan,
                                  board,
                                  section,
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

    return Listener(
      // Chốt: thẻ nguồn có thể đã rời cây khi tự trượt (lúc đó Flutter không
      // gọi onDragEnd), nên nhấc tay là dọn hết, ở đây.
      onPointerDown: (e) => _pointers.add(e.pointer),
      onPointerMove: _pointerMoved,
      onPointerUp: (e) => _pointerEnded(e.pointer, drop: true),
      onPointerCancel: (e) => _pointerEnded(e.pointer, drop: false),
      child: Stack(
        children: [
          Positioned.fill(child: content),
          _EdgeGlow(side: _edgeSide, alignLeft: true),
          _EdgeGlow(side: _edgeSide, alignLeft: false),
          Positioned(
            right: 16,
            bottom: 34 + MediaQuery.paddingOf(context).bottom,
            child: BoardZoomButton(
              zoomed: _zoomed,
              onTap: () => setState(() => _zoomed = !_zoomed),
            ),
          ),
        ],
      ),
    );
  }

  /// Vùng mép: con trỏ cách mép trái/phải của dải dưới 40.
  static const double _edgeZone = 40;

  void _onDragUpdate(Offset global) {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return;
    final x = box.globalToLocal(global).dx;
    final side = x < _edgeZone
        ? -1
        : x > box.size.width - _edgeZone
        ? 1
        : 0;
    if (side == _edgeSide.value) return;
    _edgeSide.value = side;
    _edgeTimer?.cancel();
    _edgeTimer = side == 0
        ? null
        : Timer.periodic(
            const Duration(milliseconds: 700),
            (_) => _slideColumn(side),
          );
  }

  /// Sang cột kế theo [side]: trượt 350ms, hoặc nhảy khi giảm chuyển động.
  void _slideColumn(int side) {
    if (!mounted || !_track.hasClients) return;
    final position = _track.position;
    final current =
        ((position.pixels +
                    position.viewportDimension / 2 -
                    BoardMetrics.inset -
                    BoardMetrics.columnWidth / 2) /
                BoardMetrics.pitch)
            .round();
    final next = math.min(math.max(current + side, 0), _trackCount - 1);
    final target = BoardSnapPhysics.offsetOf(next, position);
    if (OmniMotion.enabled(context)) {
      _track
          .animateTo(
            target,
            duration: const Duration(milliseconds: 350),
            curve: OmniCurves.standard,
          )
          .then((_) => _retargetAfterLayout());
    } else {
      _track.jumpTo(target);
      _retargetAfterLayout();
    }
  }

  /// Thả, huỷ hay thẻ nguồn rời cây: dọn mọi thứ. Gọi nhiều lần cũng được.
  void _endDrag() {
    _edgeTimer?.cancel();
    _edgeTimer = null;
    if (_edgeSide.value != 0) _edgeSide.value = 0;
    _dragPointer = null;
    _drag.clear();
  }

  /// Thả [task] vào cột [toColumn] tại chỗ chèn [index], kể cả đổi thứ tự
  /// trong cùng nhóm. Vẽ ngay, gửi `PUT {section_id, order}`; lỗi thì thẻ về
  /// chỗ cũ và báo câu của server (R6).
  Future<void> _drop(
    BoardBuckets board,
    Task task,
    int toColumn,
    int index,
    String sectionId,
  ) async {
    // Cột gốc tìm trên bảng chứ không đọc từ [_drag]: nhấc tay đã dọn nó
    // trước khi lượt thả tới đây.
    final from = board.buckets.indexWhere((b) => b.any((t) => t.id == task.id));
    _endDrag();
    if (sectionId.isEmpty || from < 0 || _pending != null) return;
    final fromIndex = board.buckets[from].indexWhere((t) => t.id == task.id);
    final targetLength = board.buckets[toColumn]
        .where((t) => t.id != task.id)
        .length;
    final safeIndex = index.clamp(0, targetLength);
    // Thả lại đúng vị trí cũ không tạo request và không làm danh sách nháy.
    if (from == toColumn && safeIndex == fromIndex) return;
    // `order` tính trên CẢ cột đích (không lọc người / tìm kiếm): neo vào thẻ
    // thấy được phía trên nhưng không nhảy qua thẻ ẩn nằm ngay sau nó.
    final visible = board.buckets[toColumn];
    final all = ref.read(planTasksProvider(widget.planId)).valueOrNull;
    final full = all == null
        ? visible
        : BoardBuckets.build(
            all,
            board.columns,
            BoardPerson.everyone,
          ).buckets[toColumn];
    final others = [
      for (final t in full)
        if (t.id != task.id) t,
    ];
    final order = boardDropOrder(
      others,
      task,
      fullInsertIndex(others, visible, safeIndex),
    );
    // Một số việc legacy không có `order`. Không gửi một request không thể
    // thay đổi thứ tự trong cùng nhóm; tải lại sẽ lập tức bật thẻ về chỗ cũ.
    if (from == toColumn && order == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Chưa sắp xếp được việc cũ này. Vui lòng thử lại.'),
          ),
        );
      return;
    }
    final container = ProviderScope.containerOf(context);
    final messenger = ScaffoldMessenger.of(context);
    final api = ref.read(tasksApiProvider);
    setState(() {
      _pending = (
        taskId: task.id,
        toColumn: toColumn,
        index: safeIndex,
        sectionId: sectionId,
        order: order,
      );
    });
    try {
      await api.moveOnBoard(task.id, sectionId: sectionId, order: order);
      container.read(taskRealtimeSignalProvider.notifier).bump();
    } on AppException catch (error) {
      if (mounted) setState(() => _pending = null);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error.message)));
    } on Object {
      if (mounted) setState(() => _pending = null);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Chưa chuyển được. Vui lòng thử lại.')),
        );
    }
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

  Future<void> _pickPerson() async {
    final picked = await showPersonFilterSheet(context, current: _person);
    if (picked != null && mounted) setState(() => _person = picked);
  }

  /// Mở màn tạo việc với kế hoạch + nhóm của cột đã chạm điền sẵn.
  Future<void> _createTask(Plan plan, String? sectionId) async {
    final loaded = ref.read(planTasksProvider(widget.planId)).valueOrNull;
    final sameSection = loaded?.tasks
        .where((task) => task.sectionId == sectionId)
        .toList();
    final ordered = sameSection?.where((task) => task.hasOrder).toList();
    final order = ordered == null || ordered.isEmpty
        ? (sameSection?.length ?? 0).toDouble()
        : ordered.map((task) => task.order).reduce(math.max) + 1;
    final created = await context.pushNamed<String>(
      TaskRoutes.create,
      extra: CreateTaskArgs(
        planId: plan.id,
        sectionId: sectionId,
        order: order,
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

  /// ⋯ của kế hoạch: sheet ba nhóm (`PlanMenu.dc.html`). Sửa nhóm việc đã
  /// chuyển sang ⋯ của cột và ô "Thêm nhóm việc".
  Future<void> _planMenu(Plan plan, List<List<PlanMenuAction>> groups) async {
    final choice = await showPlanMenuSheet(context, plan: plan, groups: groups);
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
      case PlanMenuAction.copyLink:
        await copyLinkToClipboard(
          ScaffoldMessenger.of(context),
          WebLinks.plan(plan.id),
        );
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
    required bool canRemove,
  }) async {
    final choice = await _optionsSheet<_SectionAction>(section.name, [
      (_SectionAction.rename, Icons.edit_outlined, 'Đổi tên nhóm'),
      if (canRemove) (_SectionAction.remove, Icons.delete_outline, 'Xoá nhóm'),
      (_SectionAction.reorder, Icons.swap_vert_rounded, 'Sắp xếp nhóm việc'),
      (_SectionAction.edit, Icons.tune_rounded, 'Sửa nhóm việc'),
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
        await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => SectionOrderPage(planId: widget.planId),
          ),
        );
      case _SectionAction.edit:
        // EditSectionsPage tự invalidate planProvider/planTasksProvider khi lưu.
        await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => EditSectionsPage(planId: widget.planId),
          ),
        );
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

  Future<T?> _optionsSheet<T>(
    String title,
    List<(T, IconData, String)> items, {
    required T danger,
  }) => showOmniSheet<T>(
    context: context,
    builder: (ctx) {
      final scheme = Theme.of(ctx).colorScheme;

      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: OmniType.bodyStrong.copyWith(color: scheme.onSurface),
                ),
              ),
              for (final (value, icon, label) in items)
                ListTile(
                  minTileHeight: 52,
                  leading: Icon(
                    icon,
                    color: value == danger
                        ? scheme.error
                        : scheme.onSurfaceVariant,
                  ),
                  title: Text(
                    label,
                    style: OmniType.body.copyWith(
                      fontWeight: FontWeight.w500,
                      color: value == danger
                          ? OmniColors.dangerTextOf(ctx)
                          : scheme.onSurface,
                    ),
                  ),
                  onTap: () => Navigator.of(ctx).pop(value),
                ),
            ],
          ),
        ),
      );
    },
  );

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

enum _SectionAction { rename, remove, reorder, edit }

/// Dải sáng 28px ở mép trái/phải khi kéo thẻ tới sát mép: báo "thả ở đây sẽ
/// sang cột kế". Fade 200ms; giảm chuyển động thì đổi ngay.
class _EdgeGlow extends StatelessWidget {
  const _EdgeGlow({required this.side, required this.alignLeft});

  final ValueNotifier<int> side;
  final bool alignLeft;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Positioned(
      top: 0,
      bottom: 0,
      left: alignLeft ? 0 : null,
      right: alignLeft ? null : 0,
      width: 28,
      child: IgnorePointer(
        child: ValueListenableBuilder<int>(
          valueListenable: side,
          builder: (context, value, _) => AnimatedOpacity(
            key: Key(alignLeft ? 'edge-glow-left' : 'edge-glow-right'),
            opacity: value == (alignLeft ? -1 : 1) ? 1 : 0,
            duration: OmniMotion.enabled(context)
                ? const Duration(milliseconds: 200)
                : Duration.zero,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: alignLeft
                      ? Alignment.centerLeft
                      : Alignment.centerRight,
                  end: alignLeft ? Alignment.centerRight : Alignment.centerLeft,
                  colors: [
                    primary.withValues(alpha: .35),
                    primary.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

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
  final VoidCallback onFilter;
  final VoidCallback? onMenu;

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
                  _HeaderButton(
                    tooltip: 'Lọc theo người',
                    icon: Icons.person_outline_rounded,
                    onTap: onFilter,
                    dot: filterActive,
                    selected: filterActive,
                  ),
                  if (onMenu case final menu?)
                    _HeaderButton(
                      tooltip: 'Tuỳ chọn kế hoạch',
                      icon: Icons.more_horiz_rounded,
                      onTap: menu,
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
      style: OmniType.body.copyWith(color: Colors.white),
      decoration: InputDecoration(
        isDense: true,
        filled: false,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        hintText: 'Tìm trong kế hoạch',
        hintStyle: OmniType.body.copyWith(
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
            // Màn nhỏ + bàn phím: ô nhập co lại và cuộn, nút "Lưu" luôn trong
            // tầm chạm (như `showTextEditSheet`).
            Flexible(
              child: SingleChildScrollView(
                child: TextField(
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
