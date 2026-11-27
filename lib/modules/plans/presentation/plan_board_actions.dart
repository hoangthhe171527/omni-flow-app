part of 'plan_board_page.dart';

/// Hành động trên kế hoạch và nhóm việc của bảng: menu ⋯, đổi tên, đóng,
/// sao chép, chuyển đội, chuyển chủ, xoá; thêm / sửa / xoá nhóm việc.
///
/// Tách khỏi `plan_board_page.dart` (rà soát kiến trúc 27/11/2026) — cụm này
/// không chạm trạng thái kéo thả hay cuộn của bảng, chỉ cần `ref`,
/// `context` và [_back].
mixin _PlanBoardActions on ConsumerState<PlanBoardPage> {
  /// Rời bảng (trang của [_PlanBoardPageState]).
  void _back();

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
          omniPageRoute<bool>(
            context: context,
            builder: (_) => EditPlanPage(planId: plan.id),
          ),
        );
      case PlanMenuAction.members:
        await navigator.push(
          omniPageRoute<bool>(
            context: context,
            builder: (_) => PlanMembersPage(planId: plan.id),
          ),
        );
      case PlanMenuAction.labels:
        await showLabelsSheet(context);
      case PlanMenuAction.fields:
        await navigator.push(
          omniPageRoute<bool>(
            context: context,
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
          omniPageRoute<void>(
            context: context,
            builder: (_) => ArchivedTasksPage(
              planId: plan.id,
              canRestore: _canEditTasks(plan),
            ),
          ),
        );
      case PlanMenuAction.files:
        await navigator.push(
          omniPageRoute<void>(
            context: context,
            builder: (_) =>
                PlanFilesPage(planId: plan.id, canDelete: _canEditTasks(plan)),
          ),
        );
      case PlanMenuAction.report:
        await navigator.push(
          omniPageRoute<void>(
            context: context,
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
      (_SectionAction.rename, LucideIcons.pencil, 'Đổi tên nhóm'),
      (_SectionAction.reorder, LucideIcons.arrowUpDown, 'Sắp xếp nhóm việc'),
      (_SectionAction.edit, LucideIcons.slidersHorizontal, 'Sửa nhóm việc'),
      if (canRemove) (_SectionAction.remove, LucideIcons.trash2, 'Xoá nhóm'),
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
          omniPageRoute(
            context: context,
            builder: (_) => SectionOrderPage(planId: widget.planId),
          ),
        );
      case _SectionAction.edit:
        // EditSectionsPage tự invalidate planProvider/planTasksProvider khi lưu.
        await Navigator.of(context).push<bool>(
          omniPageRoute(
            context: context,
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
