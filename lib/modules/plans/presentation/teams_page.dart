import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/utils/text_search.dart';
import '../../../design/components/components.dart';
import '../../../design/tokens/tokens.dart';
import '../../../security/guard/access_requirement.dart';
import '../../../security/session/session_controller.dart';
import '../../tasks/application/tasks_providers.dart';
import '../../tasks/domain/task_permissions.dart';
import '../application/plans_providers.dart';
import '../data/plans_api.dart';
import '../domain/plan.dart';
import '../plans_module.dart';
import 'create_plan_page.dart';
import 'create_team_page.dart';
import 'widgets/create_choice_sheet.dart';
import 'widgets/team_group.dart';
import 'widgets/teams_search_row.dart';

/// Gốc tab Việc (`Main.dc.html`): các team gập/mở được, mỗi team chứa các kế
/// hoạch; ô tìm và nút + ở hàng thứ hai của header; thẻ "Dòng việc" ở cuối.
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

  /// Team đang gập, theo id. Mặc định mọi team mở; không nhớ qua phiên.
  final _collapsed = <String>{};

  /// Team đang mở dòng "Đã đóng (N)", theo id. Mặc định gập.
  final _closedOpen = <String>{};

  /// Đã qua khung đầu có dữ liệu. Chỉ nhóm vào cây ở khung đó mới "rise":
  /// danh sách lười dựng lại nhóm khi cuộn về, đổi tìm hay realtime, và phát
  /// lại hiệu ứng lúc đó đọc như giật.
  bool _introDone = false;

  /// Menu + đang mở: nút + đổi nền mực và xoay thành ×.
  bool _menuOpen = false;

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
    final taskAccess = ref.watch(taskAccessProvider);
    final access = ref.watch(accessProvider);
    final isAssigner = taskAccess.isAssigner;
    // Cùng quyền mà API đòi ở đường ghi `/teams` — xem `Interfaces/routes.php`.
    final canCreateTeam = access.can('organization.org_units.create');
    final canDeleteTeam =
        taskAccess.canDelete && access.can('organization.org_units.delete');
    final canOpenFeed = const AccessRequirement.any(
      TaskPermissions.anyRead,
    ).isSatisfiedBy(access);

    return Scaffold(
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
            canDeleteTeam: canDeleteTeam,
            canOpenFeed: canOpenFeed,
          ),
        ),
      ),
    );
  }

  Widget _list(
    List<TeamWithPlans> list, {
    required bool isAssigner,
    required bool canDeleteTeam,
    required bool canOpenFeed,
  }) {
    final needle = foldDiacritics(_query.trim());
    final searching = needle.isNotEmpty;
    bool hit(String name) => foldDiacritics(name).contains(needle);

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
      else if (visible.isEmpty)
        () => _NoMatch(query: _query.trim()),
      for (var i = 0; i < visible.length; i++)
        () => TeamGroup(
          key: ValueKey(_groupKey(visible[i].$1)),
          index: i,
          rise: !_introDone,
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
          open: searching || !_collapsed.contains(visible[i].$1.team.id),
          onToggle: () => setState(() {
            final id = visible[i].$1.team.id;
            if (!_collapsed.remove(id)) _collapsed.add(id);
          }),
          onOpenPlan: (plan) => context.pushNamed(
            PlansModule.board,
            pathParameters: {'id': plan.id},
          ),
          onLongPress: _canDelete(visible[i].$1, canDeleteTeam)
              ? () => _teamOptions(visible[i].$1)
              : null,
        ),
      if (canOpenFeed) () => const _TimelineCard(),
    ];

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
      itemCount: children.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, i) => children[i](),
    );
  }

  /// Khoá nhóm CHỈ theo id: đổi tên team không được dựng lại cả nhóm. Team
  /// tổng hợp "Chưa xếp team" không có id nên có khoá riêng.
  static String _groupKey(TeamWithPlans group) =>
      group.synthetic ? 'team-synthetic' : 'team-${group.team.id}';

  bool _canDelete(TeamWithPlans group, bool canDeleteTeam) =>
      canDeleteTeam && !group.synthetic && group.team.id.isNotEmpty;

  /// "Tuỳ chọn team" (bấm giữ đầu nhóm): hiện chỉ có Xoá team.
  Future<void> _teamOptions(TeamWithPlans group) async {
    final delete = await showOmniSheet<bool>(
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
                    group.team.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: OmniType.bodyStrong.copyWith(
                      color: scheme.onSurface,
                    ),
                  ),
                ),
                ListTile(
                  minTileHeight: 52,
                  leading: Icon(Icons.delete_outline, color: scheme.error),
                  title: Text(
                    'Xoá team',
                    style: OmniType.body.copyWith(
                      fontWeight: FontWeight.w500,
                      color: OmniColors.dangerTextOf(ctx),
                    ),
                  ),
                  onTap: () => Navigator.of(ctx).pop(true),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (delete != true || !mounted) return;
    await _deleteTeam(group);
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

/// Thẻ "Dòng việc" cuối danh sách: lối vào dòng hoạt động và KPI tháng. Khung
/// như một nhóm team (`.grp`): dòng 48, ô biểu tượng 28, mũi tên.
class _TimelineCard extends ConsumerWidget {
  const _TimelineCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final tones = OmniTaskTones.of(context);
    // Lỗi / đang tải đều rơi về phụ đề trung tính: thẻ này là lối vào, không
    // được biến mất chỉ vì con số KPI chưa có.
    final delivered = ref.watch(workshopKpiProvider).valueOrNull?.delivered;
    final subtitle = delivered == null
        ? 'KPI tháng · feed 7 ngày'
        : 'KPI tháng · $delivered việc xong';

    return Material(
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(Radius.circular(8)),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: OmniPressScale(
        child: InkWell(
          onTap: () => context.pushNamed(PlansModule.timeline),
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.fromLTRB(12, 4, 6, 4),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: tones.today.background,
                    borderRadius: const BorderRadius.all(Radius.circular(6)),
                  ),
                  child: Icon(
                    Icons.timeline_rounded,
                    size: 18,
                    color: tones.today.foreground,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Dòng việc',
                        style: OmniType.bodyStrong.copyWith(
                          color: scheme.onSurface,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: OmniType.micro.copyWith(
                          fontWeight: FontWeight.w400,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox.square(
                  dimension: 44,
                  child: Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: tones.faint,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
