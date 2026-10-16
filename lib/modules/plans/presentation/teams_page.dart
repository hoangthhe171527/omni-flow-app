import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/utils/text_search.dart';
import '../../../design/components/components.dart';
import '../../../design/tokens/tokens.dart';
import '../../../security/session/api_capabilities.dart';
import '../../../security/session/session_controller.dart';
import '../../tasks/application/tasks_providers.dart';
import '../../tasks/tasks.dart' show showTextEditSheet;
import '../application/plans_providers.dart';
import '../data/plans_api.dart';
import '../domain/plan.dart';
import '../plans_module.dart';
import 'create_plan_page.dart';
import 'create_team_page.dart';
import 'edit_plan_page.dart';
import 'widgets/create_choice_sheet.dart';
import 'widgets/favorites_group.dart';
import 'widgets/team_group.dart';
import 'widgets/teams_search_row.dart';
import 'widgets/work_list_actions_sheet.dart';

/// Gốc tab Việc (`Main.dc.html`): các team gập/mở được, mỗi team chứa các kế
/// hoạch; ô tìm và nút + ở hàng thứ hai của header.
///
/// Người NHẬN việc mở màn này để xem kế hoạch mình thuộc về. Người GIAO việc
/// mở nó để trả lời "cây nào đang ở công đoạn nào, tắc ở đâu" — và chỉ họ mới
/// thấy nút +. "Việc của tôi" không còn là tab nhưng vẫn sống trong "Tất cả".
///
/// Tìm lọc PHÍA APP trên tên team và tên kế hoạch: cây đã tải đủ, và lọc tại
/// chỗ khớp bản mẫu (gõ tới đâu lọc tới đó). `GET ?search=` của `PlansApi`
/// để dành cho khi danh sách có phân trang.
class TeamsPage extends ConsumerStatefulWidget {
  const TeamsPage({super.key});

  @override
  ConsumerState<TeamsPage> createState() => _TeamsPageState();
}

class _TeamsPageState extends ConsumerState<TeamsPage> {
  final _search = TextEditingController();
  String _query = '';

  /// Team đang mở, theo id. Mặc định đóng để màn Việc chỉ hiện cấu trúc cấp
  /// một; người dùng chủ động mở đúng team cần làm.
  final _expanded = <String>{};

  /// Team đang mở dòng "Đã đóng (N)", theo id. Mặc định gập.
  final _closedOpen = <String>{};

  /// Đã qua khung đầu có dữ liệu. Chỉ nhóm vào cây ở khung đó mới "rise":
  /// danh sách lười dựng lại nhóm khi cuộn về, đổi tìm hay realtime, và phát
  /// lại hiệu ứng lúc đó đọc như giật.
  bool _introDone = false;

  /// Menu + đang mở: biểu tượng xoay thành × nhưng vẫn giữ kiểu phẳng.
  bool _menuOpen = false;

  /// Mục "Yêu thích" cũng đóng mặc định: không có kế hoạch nào tự bung ra
  /// trước khi người dùng chọn một nhóm.
  bool _favoritesOpen = false;

  /// Sao đã bấm mà cây chưa tải lại (theo id kế hoạch): lạc quan, rồi theo
  /// `is_favorite` server trả; hỏng thì về giá trị trước lượt bấm.
  final _favorite = <String, bool>{};

  /// Lượt bấm sao đang bay: lần tải lại cây giữa chừng không được xoá nó.
  final _favoriteInFlight = <String>{};

  /// Sao của [plan]; null = không vẽ sao (API chưa có `projects.favorite`).
  bool? _favoriteOf(Plan plan) => _favoriteSupported
      ? _favorite[plan.id] ?? plan.isFavorite ?? false
      : null;

  /// Khả năng `projects.favorite` của bản API (đọc trong [build]).
  bool _favoriteSupported = false;

  /// Bấm sao (`POST|DELETE /projects/{id}/favorite`): đổi ngay dưới ngón tay,
  /// lỗi thì hoàn tác và báo.
  Future<void> _toggleFavorite(Plan plan) async {
    // Lượt trước còn bay: bỏ qua chạm mới — hai lượt chéo nhau sẽ để sao
    // hiện ngược với server tuỳ lượt nào về sau.
    if (_favoriteInFlight.contains(plan.id)) return;
    final before = _favoriteOf(plan) ?? false;
    final next = !before;
    final messenger = ScaffoldMessenger.of(context);
    final api = ref.read(plansApiProvider);
    setState(() {
      _favorite[plan.id] = next;
      _favoriteInFlight.add(plan.id);
    });
    try {
      final server = await api.setFavorite(plan.id, next);
      if (mounted) setState(() => _favorite[plan.id] = server);
    } on AppException catch (error) {
      if (mounted) setState(() => _favorite[plan.id] = before);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            failureText(error, 'Chưa lưu được yêu thích. Thử lại khi có mạng.'),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _favoriteInFlight.remove(plan.id));
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _create(Rect anchor, {required bool canCreateTeam}) async {
    setState(() => _menuOpen = true);
    final choice = await showCreateMenu(
      context,
      anchor: anchor,
      canCreateTeam: canCreateTeam,
    );
    if (!mounted) return;
    setState(() => _menuOpen = false);
    if (choice == null) return;

    // Bắt trước `await`: sau khi trang tạo đóng, widget này có thể đã rời cây.
    final container = ProviderScope.containerOf(context);
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => switch (choice) {
          CreateChoice.team => const CreateTeamPage(),
          CreateChoice.plan => const CreatePlanPage(),
        },
      ),
    );
    container.invalidate(teamsWithPlansProvider);
  }

  @override
  Widget build(BuildContext context) {
    final groups = ref.watch(teamsWithPlansProvider);
    _favoriteSupported = ref.watch(
      apiSupportsProvider(ApiCapability.projectFavorite),
    );
    // Cây mới về thì bỏ các sao đã bấm xong: `is_favorite` của server đã
    // mang giá trị đó (hoặc máy khác vừa đổi — server thắng).
    ref.listen(teamsWithPlansProvider, (_, next) {
      if (next.hasValue && !next.isLoading) {
        _favorite.removeWhere((id, _) => !_favoriteInFlight.contains(id));
      }
    });
    final taskAccess = ref.watch(taskAccessProvider);
    final currentUserId = ref.watch(sessionProvider.select((s) => s.user?.id));
    final access = ref.watch(accessProvider);
    final isAssigner = taskAccess.isAssigner;
    // Cùng quyền mà API đòi ở đường ghi `/teams` — xem `Interfaces/routes.php`.
    final canCreateTeam = access.can('organization.org_units.create');
    final canUpdateTeam =
        taskAccess.canUpdate && access.can('organization.org_units.update');
    final canDeleteTeam =
        taskAccess.canDelete && access.can('organization.org_units.delete');
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: OmniTopBar(
        semanticsTitle: 'Việc',
        bottom: TeamsSearchRow(
          controller: _search,
          onChanged: (value) => setState(() => _query = value),
          showAdd: isAssigner,
          addOpen: _menuOpen,
          onAdd: (anchor) => _create(anchor, canCreateTeam: canCreateTeam),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(teamsWithPlansProvider),
        child: OmniAsyncView(
          value: groups,
          onRetry: () => ref.invalidate(teamsWithPlansProvider),
          data: (list) => _list(
            list,
            isAssigner: isAssigner,
            currentUserId: currentUserId,
            canUpdateTeam: canUpdateTeam,
            canDeleteTeam: canDeleteTeam,
            canMovePlan: (plan) =>
                taskAccess.canUpdate &&
                (taskAccess.isAssigner ||
                    (currentUserId != null &&
                        plan.roleOf(currentUserId).canManagePlan)),
          ),
        ),
      ),
    );
  }

  Widget _list(
    List<TeamWithPlans> list, {
    required bool isAssigner,
    required String? currentUserId,
    required bool canUpdateTeam,
    required bool canDeleteTeam,
    required bool Function(Plan plan) canMovePlan,
  }) {
    final needle = foldDiacritics(_query.trim());
    final searching = needle.isNotEmpty;
    bool hit(String name) => foldDiacritics(name).contains(needle);

    // Mục Yêu thích: mọi kế hoạch (cả đã đóng) mang sao, lọc theo ô tìm như
    // các team. API cũ không có `is_favorite` nên danh sách luôn rỗng.
    final favorites = <FavoritePlan>[
      for (final group in list)
        for (final p in [...group.plans, ...group.closedPlans])
          if (_favoriteOf(p) == true &&
              (!searching || hit(group.team.name) || hit(p.name)))
            (plan: p, teamName: group.team.name),
    ];

    final visible = <(TeamWithPlans, List<Plan>, List<Plan>)>[];
    for (final group in list) {
      if (!searching) {
        visible.add((group, group.plans, group.closedPlans));
        continue;
      }
      final teamHit = hit(group.team.name);
      final plans = [
        for (final p in group.plans)
          if (teamHit || hit(p.name)) p,
      ];
      // Tìm cũng ra kế hoạch đã đóng (dòng có nhãn "Đã đóng" / "Lưu trữ").
      final closed = [
        for (final p in group.closedPlans)
          if (teamHit || hit(p.name)) p,
      ];
      // Có query: nhóm không còn kế hoạch nào thì ẩn.
      if (plans.isNotEmpty || closed.isNotEmpty) {
        visible.add((group, plans, closed));
      }
    }

    // Nhóm dựng LƯỜI trong itemBuilder: cờ rise được đọc lúc nhóm thật sự vào
    // cây, nên nhóm ở xa cuộn tới sau khung đầu thì hiện ngay.
    if (!_introDone) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _introDone = true);
    }
    final children = <Widget Function()>[
      if (list.isEmpty)
        () => SizedBox(
          height: 260,
          child: OmniEmptyState(
            icon: Icons.workspaces_outline,
            title: 'Chưa có team nào',
            message: isAssigner
                ? 'Tạo một team để nhóm các kế hoạch lại.'
                : 'Khi bạn được thêm vào một kế hoạch, nó sẽ hiện ở đây.',
          ),
        )
      else if (visible.isEmpty && favorites.isEmpty)
        () => _NoMatch(query: _query.trim()),
      if (favorites.isNotEmpty)
        () => FavoritesGroup(
          key: const ValueKey('favorites'),
          rise: !_introDone,
          favorites: favorites,
          open: searching || _favoritesOpen,
          onToggle: () => setState(() => _favoritesOpen = !_favoritesOpen),
          onOpenPlan: (plan) => context.pushNamed(
            PlansModule.board,
            pathParameters: {'id': plan.id},
          ),
          onLongPressPlan: (plan) {
            final canEdit = _canEditPlan(
              plan,
              isAssigner: isAssigner,
              currentUserId: currentUserId,
            );
            final canDelete = _canDeletePlan(
              plan,
              isAssigner: isAssigner,
              currentUserId: currentUserId,
            );
            _planOptions(plan, canEdit: canEdit, canDelete: canDelete);
          },
          canLongPressPlan: (plan) =>
              _canEditPlan(
                plan,
                isAssigner: isAssigner,
                currentUserId: currentUserId,
              ) ||
              _canDeletePlan(
                plan,
                isAssigner: isAssigner,
                currentUserId: currentUserId,
              ),
        ),
      for (var i = 0; i < visible.length; i++)
        () => TeamGroup(
          key: ValueKey(_groupKey(visible[i].$1)),
          index: favorites.isEmpty ? i : i + 1,
          rise: !_introDone,
          favoriteOf: _favoriteOf,
          onToggleFavorite: _favoriteSupported ? _toggleFavorite : null,
          canDragPlan: canMovePlan,
          // Team tổng hợp do API thiếu/lệch dữ liệu không phải một đích ghi.
          // Riêng "Chưa xếp team" (id rỗng) là đích hợp lệ để gỡ team.
          onMovePlan: !visible[i].$1.synthetic || visible[i].$1.team.id.isEmpty
              ? (plan) => unawaited(_movePlan(plan, visible[i].$1))
              : null,
          group: visible[i].$1,
          plans: visible[i].$2,
          closed: visible[i].$3,
          // Đang tìm: kế hoạch đã đóng khớp phải thấy ngay.
          closedOpen:
              (searching && visible[i].$3.isNotEmpty) ||
              _closedOpen.contains(visible[i].$1.team.id),
          // Đang tìm thì "Đã đóng" luôn mở: chạm gập là nút chết.
          onToggleClosed: searching
              ? null
              : () => setState(() {
                  final id = visible[i].$1.team.id;
                  if (!_closedOpen.remove(id)) _closedOpen.add(id);
                }),
          open: searching || _expanded.contains(visible[i].$1.team.id),
          onToggle: () => setState(() {
            final id = visible[i].$1.team.id;
            if (!_expanded.remove(id)) _expanded.add(id);
          }),
          onOpenPlan: (plan) => context.pushNamed(
            PlansModule.board,
            pathParameters: {'id': plan.id},
          ),
          onLongPress:
              _canUpdateTeam(visible[i].$1, canUpdateTeam) ||
                  _canDeleteTeam(visible[i].$1, canDeleteTeam)
              ? () => _teamOptions(
                  visible[i].$1,
                  canEdit: _canUpdateTeam(visible[i].$1, canUpdateTeam),
                  canDelete: _canDeleteTeam(visible[i].$1, canDeleteTeam),
                )
              : null,
          onLongPressPlan: (plan) {
            final canEdit = _canEditPlan(
              plan,
              isAssigner: isAssigner,
              currentUserId: currentUserId,
            );
            final canDelete = _canDeletePlan(
              plan,
              isAssigner: isAssigner,
              currentUserId: currentUserId,
            );
            if (canEdit || canDelete) {
              _planOptions(plan, canEdit: canEdit, canDelete: canDelete);
            }
          },
          canLongPressPlan: (plan) =>
              _canEditPlan(
                plan,
                isAssigner: isAssigner,
                currentUserId: currentUserId,
              ) ||
              _canDeletePlan(
                plan,
                isAssigner: isAssigner,
                currentUserId: currentUserId,
              ),
        ),
    ];

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 4, bottom: 110),
      itemCount: children.length,
      separatorBuilder: (context, _) => Divider(
        height: 17,
        thickness: 1,
        indent: 16,
        endIndent: 16,
        color: Theme.of(context).colorScheme.outlineVariant,
      ),
      itemBuilder: (_, i) => children[i](),
    );
  }

  /// Khoá nhóm CHỈ theo id: đổi tên team không được dựng lại cả nhóm. Team
  /// tổng hợp "Chưa xếp team" không có id nên có khoá riêng.
  static String _groupKey(TeamWithPlans group) =>
      group.synthetic ? 'team-synthetic' : 'team-${group.team.id}';

  bool _canUpdateTeam(TeamWithPlans group, bool canUpdateTeam) =>
      canUpdateTeam && !group.synthetic && group.team.id.isNotEmpty;

  bool _canDeleteTeam(TeamWithPlans group, bool canDeleteTeam) =>
      canDeleteTeam && !group.synthetic && group.team.id.isNotEmpty;

  Future<void> _movePlan(Plan plan, TeamWithPlans target) async {
    final targetId = target.team.id;
    if ((plan.teamId ?? '') == targetId) return;
    final messenger = ScaffoldMessenger.of(context);
    final container = ProviderScope.containerOf(context);
    try {
      await container
          .read(plansApiProvider)
          .updatePlan(
            plan.id,
            targetId.isEmpty
                ? PlanPatch(clearTeam: true)
                : PlanPatch(teamId: targetId),
          );
      container.read(planRealtimeSignalProvider.notifier).bump();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            targetId.isEmpty
                ? 'Đã đưa “${plan.name}” ra khỏi team.'
                : 'Đã chuyển “${plan.name}” sang ${target.team.name}.',
          ),
        ),
      );
    } on AppException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    } on Object {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Chưa chuyển được dự án. Vui lòng thử lại.'),
        ),
      );
    }
  }

  /// Bấm giữ team mở thẳng hai thao tác của đúng team đó.
  Future<void> _teamOptions(
    TeamWithPlans group, {
    required bool canEdit,
    required bool canDelete,
  }) async {
    final choice = await showWorkListActionsSheet(
      context,
      title: group.team.name,
      editLabel: 'Sửa tên team',
      deleteLabel: 'Xoá team',
      canEdit: canEdit,
      canDelete: canDelete,
    );
    if (!mounted) return;

    switch (choice) {
      case WorkListAction.edit:
        await _renameTeam(group);
      case WorkListAction.delete:
        await _deleteTeam(group);
      case null:
        break;
    }
  }

  Future<void> _renameTeam(TeamWithPlans group) async {
    final name = await showTextEditSheet(
      context: context,
      title: 'Sửa tên team',
      initial: group.team.name,
      hint: 'Tên team',
      maxLength: 255,
    );
    if (name == null || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final container = ProviderScope.containerOf(context);
    try {
      await container
          .read(plansApiProvider)
          .updateTeam(group.team.id, name: name);
      container.invalidate(teamsWithPlansProvider);
      messenger.showSnackBar(const SnackBar(content: Text('Đã đổi tên team.')));
    } on AppException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  bool _canEditPlan(
    Plan plan, {
    required bool isAssigner,
    required String? currentUserId,
  }) =>
      ref.read(taskAccessProvider).canUpdate &&
      (isAssigner ||
          (currentUserId != null && plan.roleOf(currentUserId).canManagePlan));

  bool _canDeletePlan(
    Plan plan, {
    required bool isAssigner,
    required String? currentUserId,
  }) =>
      ref.read(taskAccessProvider).canDelete &&
      (isAssigner || (currentUserId != null && plan.ownerId == currentUserId));

  Future<void> _planOptions(
    Plan plan, {
    required bool canEdit,
    required bool canDelete,
  }) async {
    final choice = await showWorkListActionsSheet(
      context,
      title: plan.name,
      editLabel: 'Sửa kế hoạch',
      deleteLabel: 'Xoá kế hoạch',
      canEdit: canEdit,
      canDelete: canDelete,
    );
    if (!mounted) return;

    switch (choice) {
      case WorkListAction.edit:
        final container = ProviderScope.containerOf(context);
        await Navigator.of(context).push<bool>(
          MaterialPageRoute(builder: (_) => EditPlanPage(planId: plan.id)),
        );
        container.invalidate(teamsWithPlansProvider);
      case WorkListAction.delete:
        await _deletePlan(plan);
      case null:
        break;
    }
  }

  Future<void> _deletePlan(Plan plan) async {
    final confirmed = await showOmniConfirm(
      context: context,
      title: 'Xoá kế hoạch “${plan.name}”?',
      message:
          'Kế hoạch và các công việc bên trong sẽ biến mất trên cả điện thoại '
          'và web. Hành động này không thể hoàn tác tại đây.',
      confirmLabel: 'Xoá kế hoạch',
      destructive: true,
    );
    if (!confirmed || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final container = ProviderScope.containerOf(context);
    try {
      await container.read(plansApiProvider).deletePlan(plan.id);
      container.invalidate(planProvider(plan.id));
      container.invalidate(teamsWithPlansProvider);
      messenger.showSnackBar(const SnackBar(content: Text('Đã xoá kế hoạch.')));
    } on AppException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _deleteTeam(TeamWithPlans group) async {
    final messenger = ScaffoldMessenger.of(context);
    // Bắt trước `await`: sau hộp thoại xác nhận, widget này có thể đã rời cây
    // (realtime dựng lại danh sách), và `ref` của nó khi đó không còn dùng được.
    final container = ProviderScope.containerOf(context);
    // Kế hoạch đã đóng vẫn trỏ về team này: xoá team là để chúng mồ côi.
    final total = group.plans.length + group.closedPlans.length;
    if (total > 0) {
      final closed = group.closedPlans.isEmpty
          ? ''
          : ' (${group.closedPlans.length} đã đóng)';
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Team còn $total kế hoạch$closed. Hãy chuyển các kế hoạch sang '
            'team khác trước.',
          ),
        ),
      );
      return;
    }

    final confirmed = await showOmniConfirm(
      context: context,
      title: 'Xoá team “${group.team.name}”?',
      message:
          'Team sẽ biến mất trên cả điện thoại và web. Hành động này không thể hoàn tác.',
      confirmLabel: 'Xoá team',
      destructive: true,
    );
    if (!confirmed) return;

    try {
      await container.read(plansApiProvider).deleteTeam(group.team.id);
      container.invalidate(teamsWithPlansProvider);
      messenger.showSnackBar(const SnackBar(content: Text('Đã xoá team.')));
    } on AppException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    }
  }
}

/// "Không thấy “q”" — tìm không ra team hay kế hoạch nào.
class _NoMatch extends StatelessWidget {
  const _NoMatch({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 48, 16, 48),
      child: Column(
        children: [
          Text(
            'Không thấy “$query”',
            textAlign: TextAlign.center,
            style: OmniType.bodySm.copyWith(
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Thử tên team hoặc tên kế hoạch khác.',
            textAlign: TextAlign.center,
            style: OmniType.caption.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
