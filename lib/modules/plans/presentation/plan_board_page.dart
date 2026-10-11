import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/error/app_exception.dart';
import '../../../design/components/components.dart';
import '../../../design/platform/omni_motion_scope.dart';
import '../../../design/tokens/tokens.dart';
import '../../../security/session/session_controller.dart';
import '../../tasks/application/tasks_providers.dart';
import '../../tasks/domain/task.dart';
import '../../tasks/routes.dart';
import '../../tasks/tasks.dart';
import '../../tasks/tasks_module.dart';
import '../application/plans_providers.dart';
import '../data/plans_api.dart';
import '../domain/plan.dart';
import '../routes.dart';
import 'edit_sections_page.dart';
import 'widgets/board_column.dart';
import 'widgets/person_filter_sheet.dart';

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

  /// Thẻ đã hiện trên bảng này. Chỉ lần đầu mới "rise": cột là danh sách
  /// lười, cuộn đi rồi cuộn về là dựng lại thẻ — phát lại hiệu ứng lúc đó
  /// đọc như giật. Đổi lọc hay realtime cũng không phát lại.
  final _shown = <String>{};

  @override
  void dispose() {
    _debounce?.cancel();
    _searchField.dispose();
    _track.dispose();
    super.dispose();
  }

  bool _firstShow(String taskId) => _shown.add(taskId);

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

    final buckets = ref.watch(
      boardBucketsProvider((planId: widget.planId, person: _person)),
    );
    final search = _query.isEmpty
        ? null
        : ref.watch(
            planTaskSearchProvider((planId: widget.planId, query: _query)),
          );
    final ids = search?.valueOrNull;
    final board = buckets.valueOrNull;
    final visible = board == null || ids == null ? board : board.only(ids);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: OmniCovers.colorOf(loaded?.cover),
        body: DecoratedBox(
          key: const Key('board-background'),
          decoration: BoxDecoration(
            gradient: OmniCovers.gradientOf(loaded?.cover),
          ),
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
                onMenu: loaded != null && (canEditSections || canDeletePlan)
                    ? () => _planMenu(
                        loaded,
                        canEditSections: canEditSections,
                        canDeletePlan: canDeletePlan,
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
                    data: (board) => search == null
                        ? _body(
                            plan,
                            board,
                            canCreate: taskAccess.canCreate,
                            canEditSections: canEditSections,
                          )
                        : OmniAsyncView(
                            value: search,
                            onRetry: () => ref.invalidate(
                              planTaskSearchProvider((
                                planId: widget.planId,
                                query: _query,
                              )),
                            ),
                            data: (ids) => _body(
                              plan,
                              board.only(ids),
                              canCreate: taskAccess.canCreate,
                              canEditSections: canEditSections,
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
    required bool canEditSections,
  }) {
    final columns = board.columns;
    final realSections = plan.sections;
    final itemCount = columns.length + (canEditSections ? 1 : 0);

    return Column(
      children: [
        if (board.truncated) const _TruncatedNotice(),
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
          child: ListView.separated(
            key: const Key('board-track'),
            controller: _track,
            scrollDirection: Axis.horizontal,
            physics: BoardSnapPhysics(animate: OmniMotion.enabled(context)),
            padding: const EdgeInsets.fromLTRB(
              BoardMetrics.inset,
              BoardMetrics.top,
              BoardMetrics.inset,
              BoardMetrics.bottom,
            ),
            itemCount: itemCount,
            separatorBuilder: (_, _) => const SizedBox(width: BoardMetrics.gap),
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
                    onOpenTask: (task) => context.pushNamed(
                      TasksModule.detail,
                      pathParameters: {'id': task.id},
                    ),
                    onAddTask: canCreate
                        ? () => _createTask(plan, real ? section.id : null)
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
    });
  }

  Future<void> _pickPerson() async {
    final picked = await showPersonFilterSheet(context, current: _person);
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

  /// ⋯ của kế hoạch, tạm thời tới khi menu kế hoạch đầy đủ ra đời (Task 6).
  Future<void> _planMenu(
    Plan plan, {
    required bool canEditSections,
    required bool canDeletePlan,
  }) async {
    final choice = await _optionsSheet<_PlanAction>(plan.name, [
      if (canEditSections)
        (_PlanAction.editSections, Icons.view_column_outlined, 'Sửa nhóm việc'),
      if (canDeletePlan)
        (_PlanAction.delete, Icons.delete_outline, 'Xoá kế hoạch'),
    ], danger: _PlanAction.delete);
    if (!mounted) return;
    switch (choice) {
      case _PlanAction.editSections:
        await _editSections();
      case _PlanAction.delete:
        await _deletePlan(plan);
      case null:
        break;
    }
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
    final index = board.columns.indexWhere((c) => c.id == section.id);
    final count = index < 0 ? 0 : board.buckets[index].length;
    final confirmed = await showOmniConfirm(
      context: context,
      title: 'Xoá nhóm “${section.name}”?',
      message: count == 0
          ? 'Nhóm việc này sẽ biến mất trên cả điện thoại và web.'
          : '$count việc trong nhóm này sẽ hiện ở nhóm việc đầu tiên.',
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

    // Id chưa từng dùng: kể cả id mà việc nào đó còn trỏ tới (nhóm đã xoá),
    // nếu không các việc cũ đó sẽ lặng lẽ hiện vào nhóm mới.
    final used = {
      for (final s in plan.sections) s.id,
      for (final bucket in board.buckets)
        for (final task in bucket) ?task.sectionId,
    };
    var n = plan.sections.length + 1;
    while (used.contains('s$n')) {
      n++;
    }

    await _saveSections([
      ...plan.sections,
      PlanSection(id: 's$n', name: name, order: plan.sections.length),
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
          'Toàn bộ công việc trong kế hoạch cũng sẽ được chuyển vào thùng rác. Thao tác sẽ đồng bộ trên web và điện thoại.',
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

enum _PlanAction { editSections, delete }

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
  const _TruncatedNotice();

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
                  'Kế hoạch này có hơn $kMaxTasksOnBoard việc. Bảng đang hiện '
                  '$kMaxTasksOnBoard việc đầu theo thứ tự trên bảng.',
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
