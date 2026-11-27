import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/config/web_links.dart';
import '../../../core/error/app_exception.dart';
import '../../../core/utils/client_id.dart';
import '../../../core/utils/copy_link.dart';
import '../../../core/utils/media_url.dart';
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
import 'widgets/add_task_sheet.dart';

part 'plan_board_actions.dart';
part 'plan_board_widgets.dart';

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

/// Ảnh cover (URL đã lưu trong `cover`) cho lớp mờ của header. Tách ra để
/// test thay bằng ảnh trong bộ nhớ, tải xong lúc nào test quyết định.
///
/// Giải mã tối đa rộng 800: ảnh chỉ làm nền đã làm mờ của header, giải mã
/// kích thước gốc (tới 2400px ≈ 17 MB bộ nhớ) là phí trên máy RAM thấp.
final boardCoverImageProvider = Provider<ImageProvider Function(String cover)>(
  (_) =>
      (cover) => ResizeImage(
        CachedNetworkImageProvider(resolveMediaUrl(cover)),
        width: 800,
        policy: ResizeImagePolicy.fit,
      ),
);

class _PlanBoardPageState extends ConsumerState<PlanBoardPage>
    with SingleTickerProviderStateMixin, _PlanBoardActions {
  final _track = ScrollController();

  /// Đang lọc theo ai. Sống trong State của màn: đây là cách người dùng đang
  /// NHÌN một cái bảng, không phải một thiết lập của họ.
  BoardPerson _person = BoardPerson.everyone;

  /// Đang mở ô tìm trong header.
  bool _searching = false;

  /// Chuỗi tìm đã qua debounce 300ms của ô tìm; rỗng = không lọc.
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
  /// ở mép đó, và dải tự trượt: liên tục theo [_edgeTicker], hoặc (giảm
  /// chuyển động) [_edgeTimer] nhảy sang cột kế mỗi 700ms.
  final _edgeSide = ValueNotifier<int>(0);
  Timer? _edgeTimer;

  /// Trượt mép liên tục, mỗi khung một bước theo vận tốc (xem [_onEdgeTick]).
  late final Ticker _edgeTicker;

  /// `elapsed` ở tick trước (null: tick đầu sau khi bắt đầu).
  Duration? _edgeLast;

  /// Độ sâu của ngón trong vùng mép, 0..1 (1 = sát mép màn).
  double _edgeDepth = 0;

  /// Đã hẹn dò lại đích ở cuối khung này.
  bool _retargetQueued = false;

  /// Bảng đang vẽ lúc bắt đầu kéo. Trong lượt kéo trang vẽ nó thay cho dữ
  /// liệu mới về (cùng các `List<Task>`), nên không thẻ nào dựng lại và chỗ
  /// chèn khớp cái người dùng đang nhìn; kéo xong mới áp dữ liệu mới.
  BoardBuckets? _frozen;

  /// Số ô trên dải (cột + ô "Thêm nhóm việc"), để tự trượt không vượt cuối.
  int _trackCount = 1;

  /// Bảng đang vẽ (đã gồm thẻ lạc quan), để thả và dò lại cột sau khi trượt.
  BoardBuckets? _board;

  /// Thẻ vừa thả, đang chờ server: bảng vẽ nó ở chỗ mới ngay (lạc quan). Xoá
  /// khi dữ liệu mới về hoặc khi lưu lỗi.
  ///
  /// Giữ id nhóm đích chứ không giữ chỉ số cột: chỉ số tính trên bảng đóng
  /// băng lúc kéo, mà dữ liệu áp sau khi thả có thể đã xoá/đổi thứ tự nhóm.
  /// [order] là số đã gửi, để biết dữ liệu mới về đã mang thứ tự mới chưa
  /// (đổi chỗ trong cùng nhóm không đổi `sectionId`).
  ({String taskId, int index, String sectionId, double? order})? _pendingMove;

  ({String taskId, int index, String sectionId, double? order})? get _pending =>
      _pendingMove;

  set _pending(
    ({String taskId, int index, String sectionId, double? order})? value,
  ) {
    _pendingMove = value;
    _liftable.value = value == null;
    _pendingTimer?.cancel();
    _pendingTimer = value == null
        ? null
        : Timer(pendingTimeout, () {
            if (mounted && identical(_pendingMove, value)) {
              setState(() => _pending = null);
            }
          });
  }

  /// Lưới an toàn của [_pending]: không có dữ liệu mới nào khớp (tải lại hỏng
  /// mà không báo lỗi, server chuẩn hoá thứ tự…) thì sau ngần này cũng bỏ vẽ
  /// lạc quan, để bảng không kẹt ở chế độ không nhấc được thẻ.
  static const pendingTimeout = Duration(seconds: 10);
  Timer? _pendingTimer;

  /// false khi một lượt thả còn chờ server: chưa cho nhấc thẻ khác (thứ tự
  /// tính trên dữ liệu cũ sẽ lệch). Là `ValueListenable` chứ không đổi tham số
  /// `drag`/`canDrag` của cột: đổi chúng là dựng lại MỌI thẻ ngay lúc thả, còn
  /// đây chỉ dựng lại lớp `LongPressDraggable` của từng thẻ.
  final _liftable = ValueNotifier<bool>(true);

  /// Các ngón đang chạm, theo thứ tự chạm; và ngón đang giữ thẻ (ngón chạm
  /// gần nhất lúc thẻ nhấc lên). Chỉ ngón ấy nhấc lên mới kết thúc lượt kéo.
  final _pointers = <int>[];
  int? _dragPointer;

  @override
  void initState() {
    super.initState();
    _edgeTicker = createTicker(_onEdgeTick);
    _drag.addListener(_onDragState);
    // Dải dời dưới ngón đứng yên (Ticker trượt mép, snap 250ms sau khi rời
    // mép, nhảy cột khi giảm chuyển động): dò lại đích ở cuối mỗi khung. Lúc
    // snap dải bỏ qua hit-test nên `DragTarget` không tự báo được.
    _track.addListener(() {
      if (_drag.active) _queueRetarget();
    });
  }

  void _onDragState() {
    assert(
      _drag.active || _frozen == null,
      'Chỉ dọn lượt kéo qua _endDrag: nó gỡ băng dữ liệu (_frozen) trước.',
    );
    if (_drag.active && _dragPointer == null && _pointers.isNotEmpty) {
      _dragPointer = _pointers.last;
    }
    if (_drag.active && _frozen == null) _frozen = _board;
  }

  /// Ngón [pointer] nhấc lên ([drop]) hoặc bị huỷ. Ngón đang giữ thẻ nhấc lên
  /// thì thả vào ĐÍCH của [_drag] — đọc trước khi dọn. Không dựa vào
  /// `DragTarget` nhận thả: sau khi dải tự trượt, Flutter không dò lại đích
  /// khi ngón tay đứng yên, nên cột nhận thả là cột đã trôi khỏi dưới ngón.
  void _pointerEnded(int pointer, {required bool drop}) {
    _pointers.remove(pointer);
    if (_dragPointer != null && pointer != _dragPointer) return;
    // Đích của khung gần nhất có thể đã cũ nếu dải vừa dời (snap đang chạy):
    // dò lại ngay theo vị trí hiện tại trước khi đọc.
    if (drop && _drag.active) _retarget();
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
    _pendingTimer?.cancel();
    _edgeTicker.dispose();
    _edgeSide.dispose();
    _drag.dispose();
    _liftable.dispose();
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
      if (pending == null) return;
      // Tải lại hỏng: không còn gì để đối chiếu, bỏ vẽ lạc quan (PUT có thể
      // đã xong) thay vì khoá kéo thả tới lượt tải tốt kế tiếp.
      if (next is AsyncError) {
        setState(() => _pending = null);
        return;
      }
      if (next is! AsyncData<PlanTasks>) return;
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
      // Header luôn là lớp kính tối, kể cả khi phần thân dùng surface sáng.
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: ProjectCoverSurface(
          key: const Key('board-background'),
          cover: loaded?.cover,
          color: loaded?.color,
          // Cỡ của nền, để header cắt đúng phần ảnh nằm dưới nó (xem
          // [_GlassHeader.backdropSize]).
          child: LayoutBuilder(
            builder: (context, box) => Column(
              children: [
                _GlassHeader(
                  coverImage: isProjectCoverImage(loaded?.cover)
                      ? ref.watch(boardCoverImageProvider)(loaded!.cover!)
                      : null,
                  backdropSize: box.biggest,
                  title: loaded?.name ?? 'Kế hoạch',
                  subtitle: _subtitle(loaded, visible),
                  searching: _searching,
                  onSearchChanged: _onSearchChanged,
                  onBack: _back,
                  onOpenSearch: () {
                    HapticFeedback.selectionClick();
                    setState(() => _searching = true);
                  },
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
                              canCreate:
                                  canEditSections && taskAccess.canCreate,
                              canComplete:
                                  canEditSections && taskAccess.canComplete,
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
                                canCreate:
                                    canEditSections && taskAccess.canCreate,
                                canComplete:
                                    canEditSections && taskAccess.canComplete,
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
    if (_drag.active && _frozen != null) {
      board = _frozen!;
    } else if (_pending case final p?) {
      // Cột đích tìm theo id trên bảng HIỆN TẠI; nhóm không còn thì vẽ theo
      // dữ liệu mới, không đặt lạc quan.
      final to = board.columns.indexWhere((c) => c.id == p.sectionId);
      if (to >= 0) board = board.moved(p.taskId, to, p.index, p.sectionId);
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
                  // Cột kế đã dựng sẵn trước khi dải trượt tới: dựng ≈10 thẻ
                  // giữa lúc trượt là một khung vọt.
                  scrollCacheExtent: const ScrollCacheExtent.pixels(
                    BoardMetrics.pitch,
                  ),
                  physics: _TrackPhysics(
                    sliding: () => _edgeTicker.isActive,
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
                    // dựng tạm, không có gì để đổi tên hay xoá. Cột ảo "Đã
                    // giao" cũng vậy: không thả vào, không tạo việc, không ⋯.
                    final real = section.id.isNotEmpty && !section.isDelivered;

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
                          // Bảng bị cắt bớt: thứ tự tính trên phần thiếu.
                          drag: canDragTasks && real && !board.truncated
                              ? _drag
                              : null,
                          // Việc ở cột ảo "Đã giao" không nhấc được: nhóm đã
                          // lưu của nó không đổi theo chỗ đang vẽ.
                          canDrag: (t) =>
                              canDragTasks &&
                              !board.truncated &&
                              !t.isLocked &&
                              !t.isDeliveredRefurbish,
                          liftable: _liftable,
                          moveTargets: [
                            if (canDragTasks && real && !board.truncated)
                              for (var j = 0; j < columns.length; j++)
                                if (j != index &&
                                    columns[j].id.isNotEmpty &&
                                    !columns[j].isDelivered)
                                  (label: columns[j].name, index: j),
                          ],
                          onMoveTo: (task, to) => unawaited(
                            _drop(
                              board,
                              task,
                              to,
                              board.buckets[to].length,
                              columns[to].id,
                            ),
                          ),
                          onDragUpdate: _onDragUpdate,
                          onDragEnd: _endDrag,
                          onOpenTask: (task) => context.pushNamed(
                            TasksModule.detail,
                            pathParameters: {'id': task.id},
                          ),
                          onAddTask: canCreate
                              ? () => _addTask(plan, real ? section.id : null)
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
                          // Cùng cổng với "Đổi tên nhóm" trong ⋯.
                          onRename: canEditSections && real
                              ? (name) => _saveSections([
                                  for (final s in plan.sections)
                                    s.id == section.id
                                        ? _PlanBoardActions._copy(s, name: name)
                                        : s,
                                ])
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
    final w = box.size.width;
    final side = x < _edgeZone
        ? -1
        : x > w - _edgeZone
        ? 1
        : 0;
    _edgeDepth = side == 0
        ? 0
        : ((side < 0 ? _edgeZone - x : x - (w - _edgeZone)) / _edgeZone).clamp(
            0.0,
            1.0,
          );
    if (side == _edgeSide.value) return;
    _edgeSide.value = side;
    if (!OmniMotion.enabled(context)) {
      // Giảm chuyển động: nhảy từng cột mỗi 700ms, không trượt.
      _edgeTimer?.cancel();
      _edgeTimer = side == 0
          ? null
          : Timer.periodic(
              const Duration(milliseconds: 700),
              (_) => _slideColumn(side),
            );
      return;
    }
    if (side == 0) {
      _stopEdge(snap: true);
    } else {
      _startEdge();
    }
  }

  /// Bắt đầu (lại) trượt mép: hệ số khởi động tính từ đây.
  void _startEdge() {
    if (_edgeTicker.isActive) _edgeTicker.stop();
    _edgeLast = null;
    unawaited(_edgeTicker.start());
  }

  /// Một khung trượt mép: `v = 150 + 750·độ sâu` px/s, nhân hệ số khởi động
  /// 0→1 trong 120ms đầu; chạm đầu/cuối dải thì dừng. Dò lại đích ở cuối
  /// khung (khi các cột đã dựng ở vị trí mới).
  void _onEdgeTick(Duration elapsed) {
    final dt = (elapsed - (_edgeLast ?? elapsed)).inMicroseconds / 1e6;
    _edgeLast = elapsed;
    if (!_track.hasClients || _edgeSide.value == 0) return;
    final p = _track.position;
    final ramp = (elapsed.inMicroseconds / 120000).clamp(0.0, 1.0);
    final v = (150 + 750 * _edgeDepth) * ramp;
    final side = _edgeSide.value;
    final next = (p.pixels + side * v * dt).clamp(
      p.minScrollExtent,
      p.maxScrollExtent,
    );
    if (next != p.pixels) _track.jumpTo(next);
    // Chạm đầu/cuối THEO CHIỀU trượt (tick đầu đứng yên ở 0 không tính).
    if (side > 0 ? next >= p.maxScrollExtent : next <= p.minScrollExtent) {
      _edgeTicker.stop();
    }
    // Dò lại đích: `_track` báo khi `jumpTo` dời dải (xem initState).
  }

  /// Hẹn [_retarget] ở cuối khung, gộp một lần mỗi khung.
  void _queueRetarget() {
    if (_retargetQueued) return;
    _retargetQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _retargetQueued = false;
      _retarget();
    });
  }

  /// Dừng trượt mép; [snap] thì về cột gần nhất (250ms) rồi dò lại đích.
  void _stopEdge({required bool snap}) {
    if (_edgeTicker.isActive) _edgeTicker.stop();
    _edgeLast = null;
    if (!snap || !mounted || !_track.hasClients) return;
    final position = _track.position;
    final target = BoardSnapPhysics.offsetOf(
      _nearestColumn(position),
      position,
    );
    if ((target - position.pixels).abs() < .5) {
      _retargetAfterLayout();
      return;
    }
    _track
        .animateTo(
          target,
          duration: const Duration(milliseconds: 250),
          curve: OmniCurves.standard,
        )
        .then((_) => _retargetAfterLayout());
  }

  /// Ô trên dải có tâm gần giữa màn nhất.
  int _nearestColumn(ScrollPosition position) {
    final current =
        ((position.pixels +
                    position.viewportDimension / 2 -
                    BoardMetrics.inset -
                    BoardMetrics.columnWidth / 2) /
                BoardMetrics.pitch)
            .round();

    return math.min(math.max(current, 0), _trackCount - 1);
  }

  /// Giảm chuyển động: nhảy sang cột kế theo [side] rồi dò lại đích.
  void _slideColumn(int side) {
    if (!mounted || !_track.hasClients) return;
    final position = _track.position;
    final next = math.min(
      math.max(_nearestColumn(position) + side, 0),
      _trackCount - 1,
    );
    _track.jumpTo(BoardSnapPhysics.offsetOf(next, position));
    _retargetAfterLayout();
  }

  /// Thả, huỷ hay thẻ nguồn rời cây: dọn mọi thứ. Gọi nhiều lần cũng được.
  /// Đang trượt mép thì dừng và snap về cột gần nhất (nơi gọi đã đọc đích).
  void _endDrag() {
    _edgeTimer?.cancel();
    _edgeTimer = null;
    final atEdge = _edgeTicker.isActive || _edgeSide.value != 0;
    if (_edgeSide.value != 0) _edgeSide.value = 0;
    _stopEdge(snap: atEdge && mounted && OmniMotion.enabled(context));
    _dragPointer = null;
    final wasFrozen = _frozen != null;
    _frozen = null;
    _drag.clear();
    if (wasFrozen && mounted) setState(() {});
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
    if (sectionId.isEmpty ||
        sectionId == PlanSection.deliveredId ||
        from < 0 ||
        _pending != null) {
      return;
    }
    final fromIndex = board.buckets[from].indexWhere((t) => t.id == task.id);
    final targetOthers = [
      for (final t in board.buckets[toColumn])
        if (t.id != task.id) t,
    ];
    // Kẹp vào vùng ghim của thẻ (như ô chỗ trống đã hiện): thả thẻ ghim xuống
    // giữa thẻ thường thì nó nằm cuối khối ghim, không thành "không xếp được".
    final safeIndex = clampToPinZone(
      targetOthers,
      task.isPinned,
      index.clamp(0, targetOthers.length),
    );
    // Thả lại đúng vị trí cũ không tạo request và không làm danh sách nháy.
    if (from == toColumn && safeIndex == fromIndex) return;
    // `order` tính trên CẢ cột đích (không lọc người / tìm kiếm): neo vào thẻ
    // thấy được phía trên nhưng không nhảy qua thẻ ẩn nằm ngay sau nó.
    // [safeIndex] đếm trên cột đích ĐÃ bỏ thẻ đang kéo (cùng nhóm thì thẻ ấy
    // vẫn nằm trong cột), nên danh sách thấy được cũng bỏ nó trước khi neo.
    final visible = targetOthers;
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
      clampToPinZone(
        others,
        task.isPinned,
        fullInsertIndex(others, visible, safeIndex),
      ),
    );
    // Một số việc legacy không có `order`. Không gửi một request không thể
    // thay đổi thứ tự trong cùng nhóm; tải lại sẽ lập tức bật thẻ về chỗ cũ.
    if (from == toColumn && order == null) {
      showOmniToast(
        context,
        'Chưa sắp xếp được việc cũ này. Vui lòng thử lại.',
      );
      return;
    }
    final container = ProviderScope.containerOf(context);
    final messenger = ScaffoldMessenger.of(context);
    final api = ref.read(tasksApiProvider);
    setState(() {
      _pending = (
        taskId: task.id,
        index: safeIndex,
        sectionId: sectionId,
        order: order,
      );
    });
    try {
      final saved = await api.moveOnBoard(
        task.id,
        sectionId: sectionId,
        order: order,
      );
      // Server đã ghi: đối chiếu dữ liệu tải lại với THỨ TỰ server trả về
      // (có thể đã chuẩn hoá), không phải số app gửi — kẻo không bao giờ khớp.
      final p = _pending;
      if (mounted &&
          p != null &&
          p.taskId == task.id &&
          saved.id == task.id &&
          saved.sectionId == sectionId) {
        _pending = (
          taskId: p.taskId,
          index: p.index,
          sectionId: p.sectionId,
          order: saved.hasOrder ? saved.order : null,
        );
      }
      container.read(taskRealtimeSignalProvider.notifier).bump();
      // Sang cột khác: toast "Hoàn tác" đưa thẻ về nhóm và thứ tự cũ.
      final back = board.columns[from];
      if (from != toColumn && back.id.isNotEmpty && !back.isDelivered) {
        showOmniToast(
          null,
          'Đã chuyển sang ${board.columns[toColumn].name}.',
          messenger: messenger,
          actionLabel: omniUndoLabel,
          onAction: () => _undoMove(task, back.id, container, messenger),
        );
      }
    } on AppException catch (error) {
      if (mounted) setState(() => _pending = null);
      showOmniToast(null, error.message, messenger: messenger);
    } on Object {
      if (mounted) setState(() => _pending = null);
      showOmniToast(
        null,
        'Chưa chuyển được. Vui lòng thử lại.',
        messenger: messenger,
      );
    }
  }

  /// Đưa [task] về nhóm [sectionId] với thứ tự cũ (Hoàn tác của lượt thả).
  Future<void> _undoMove(
    Task task,
    String sectionId,
    ProviderContainer container,
    ScaffoldMessengerState messenger,
  ) async {
    try {
      await container
          .read(tasksApiProvider)
          .moveOnBoard(
            task.id,
            sectionId: sectionId,
            order: task.hasOrder ? task.order : null,
          );
      container.read(taskRealtimeSignalProvider.notifier).bump();
    } on AppException catch (error) {
      showOmniToast(null, error.message, messenger: messenger);
    } on Object {
      showOmniToast(
        null,
        'Chưa hoàn tác được. Vui lòng thử lại.',
        messenger: messenger,
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

  @override
  void _back() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    } else {
      // Mở thẳng bằng liên kết sâu: không có gì phía sau, về tab Việc.
      context.goNamed(PlanRoutes.teams);
    }
  }

  /// Ô tìm chuẩn đã chờ 300ms và bỏ khoảng trắng hai đầu.
  void _onSearchChanged(String value) {
    if (mounted) setState(() => _query = value);
  }

  void _closeSearch() {
    HapticFeedback.selectionClick();
    // Ô tìm rời cây khi đóng nên tự mất chữ và lượt gõ đang chờ.
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

  /// + ở cột: tấm "Thêm việc" (Gõ tên / Chọn đàn — TNP_DON_HANG_THEO_CAY §6).
  /// "Thêm chi tiết" mở trang tạo đầy đủ như trước.
  Future<void> _addTask(Plan plan, String? sectionId) async {
    final sectionName =
        plan.sections.where((s) => s.id == sectionId).firstOrNull?.name ??
        'Chưa phân nhóm';
    final choice = await showAddTaskSheet(context, sectionName: sectionName);
    if (choice == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    void say(String text) => showOmniToast(null, text, messenger: messenger);
    try {
      switch (choice) {
        case OpenFullCreate():
          await _createTask(plan, sectionId);
          return;
        case AddTypedTask(:final title):
          await ref
              .read(tasksApiProvider)
              .create(
                title: title,
                projectId: plan.id,
                sectionId: sectionId,
                order: _nextOrder(sectionId),
              );
        case AddUnitTasks(:final unitIds):
          final res = await ref
              .read(plansApiProvider)
              .tasksFromUnits(
                planId: plan.id,
                sectionId: sectionId,
                unitIds: unitIds,
              );
          final s = res.skipped.length;
          say(
            res.created == 0
                ? 'Không thêm việc nào: $s cây đang có việc tân trang.'
                : s > 0
                ? 'Đã thêm ${res.created} việc, bỏ qua $s cây đang có việc tân trang.'
                : 'Đã thêm ${res.created} việc.',
          );
      }
      if (mounted) ref.invalidate(planTasksProvider(widget.planId));
    } on AppException catch (error) {
      say(error.message);
    }
  }

  /// Thứ tự cho việc mới ở cuối nhóm [sectionId].
  double _nextOrder(String? sectionId) {
    final loaded = ref.read(planTasksProvider(widget.planId)).valueOrNull;
    final same = loaded?.tasks.where((t) => t.sectionId == sectionId).toList();
    final ordered = same?.where((t) => t.hasOrder).toList();
    return ordered == null || ordered.isEmpty
        ? (same?.length ?? 0).toDouble()
        : ordered.map((t) => t.order).reduce(math.max) + 1;
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

  /// ⋯ của kế hoạch: menu neo tại nút, cùng mẫu với dấu + ở màn Team. Sửa
  /// nhóm việc vẫn nằm ở ⋯ của cột và ô "Thêm nhóm việc".
}
