import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/utils/formatters.dart';
import '../../../../../design/components/components.dart';
import '../../../../../design/tokens/tokens.dart';
import '../../../../../security/session/api_capabilities.dart';
import '../../../../team/team.dart';
import '../../../application/tasks_providers.dart';
import '../../../data/tasks_api.dart';
import '../../../domain/custom_field.dart';
import '../../../domain/task.dart';
import '../../../domain/task_copy_request.dart';
import '../../../domain/task_project.dart';
import '../assign_task_sheet.dart';

/// Kết quả sheet sao chép: body cho `POST /tasks/{id}/copy` và tên chỗ đặt
/// bản sao (nhóm việc, hoặc kế hoạch khi kế hoạch không có nhóm) cho SnackBar.
typedef TaskCopyResult = ({TaskCopyRequest request, String placeName});

/// Trần tên việc (`CopyTaskRequest` / `CreateTaskRequest` `title` `max:255`).
const kTaskTitleMax = 255;

/// Tên gợi ý khi sao chép: tên gốc cắt còn ≤244 ký tự rồi thêm " (bản sao)",
/// để cả chuỗi không vượt [kTaskTitleMax] (server sẽ trả 422).
String copyTitleOf(String title) {
  const suffix = ' (bản sao)';
  final runes = title.runes;
  final head = runes.length <= kTaskTitleMax - suffix.length - 1
      ? title
      : String.fromCharCodes(runes.take(kTaskTitleMax - suffix.length - 1));

  return '$head$suffix';
}

/// Cùng ngày lịch; hai null là BẰNG nhau (`DateUtils.isSameDay(null, null)`
/// trả false — dùng thẳng nó thì "không đổi gì" thành "xoá ngày").
bool sameCopyDay(DateTime? a, DateTime? b) {
  if (a == null || b == null) return a == null && b == null;

  return DateUtils.isSameDay(a, b);
}

/// Mở sheet "Sao chép công việc" (`AppCopy.dc.html`). Trả null khi đóng.
Future<TaskCopyResult?> showCopyTaskSheet(
  BuildContext context, {
  required Task task,
}) => showOmniViecSheet<TaskCopyResult>(
  context: context,
  builder: (_) => CopyTaskSheet(task: task),
);

/// Sheet sao chép: Tên, Team → Kế hoạch → Nhóm việc (`GET /projects`), rồi
/// — chỉ khi phiên khai `tasks.copy_options` — ngày, người thực hiện, trường
/// tuỳ chỉnh; cuối cùng là việc con. API cũ: công tắc "Giữ người thực hiện"
/// thay khối người, và body KHÔNG BAO GIỜ có bốn khoá mới (R11).
class CopyTaskSheet extends ConsumerStatefulWidget {
  const CopyTaskSheet({super.key, required this.task});

  final Task task;

  @override
  ConsumerState<CopyTaskSheet> createState() => _CopyTaskSheetState();
}

/// Khoá nhóm "Chưa thuộc team" trong ô Team.
const _noTeam = '';

class _CopyTaskSheetState extends ConsumerState<CopyTaskSheet> {
  late final _title = TextEditingController(
    text: copyTitleOf(widget.task.title),
  );

  List<MovablePlan>? _all;
  bool _loadFailed = false;

  String? _team;
  MovablePlan? _plan;
  String? _sectionId;

  late final DateTime? _origStart = _calendarDay(widget.task.startDate);
  late final DateTime? _origDue = _calendarDay(widget.task.dueDate);
  late DateTime? _start = _origStart;
  late DateTime? _due = _origDue;

  bool _pickOthers = false;
  late final List<String> _people = [...widget.task.assigneeIds];
  bool _copyFields = true;
  bool _keepAssignees = true;
  bool _keepChecklist = true;

  @override
  void initState() {
    super.initState();
    _title.addListener(_onTitle);
    _load();
  }

  @override
  void dispose() {
    _title
      ..removeListener(_onTitle)
      ..dispose();
    super.dispose();
  }

  void _onTitle() => setState(() {});

  Future<void> _load() async {
    setState(() {
      _all = null;
      _loadFailed = false;
    });
    try {
      final plans = await ref.read(tasksApiProvider).projectsForMove();
      if (!mounted) return;
      setState(() {
        _all = plans;
        final source =
            plans.where((p) => p.id == widget.task.projectId).firstOrNull ??
            plans.firstOrNull;
        if (source == null) return;
        _team = _teamOf(source);
        _plan = source;
        final sections = source.sections;
        _sectionId = sections.any((s) => s.id == widget.task.sectionId)
            ? widget.task.sectionId
            : sections.firstOrNull?.id;
      });
    } on Object {
      if (!mounted) return;
      setState(() => _loadFailed = true);
    }
  }

  static String _teamOf(MovablePlan p) {
    final id = p.teamId;
    return id == null || id.isEmpty ? _noTeam : id;
  }

  /// Ngày lịch VN của một giá trị từ API, ở dạng nửa đêm cục bộ — cùng dạng
  /// với ngày `showDatePicker` trả, để so và để `ymd` in đúng.
  static DateTime? _calendarDay(DateTime? d) {
    if (d == null) return null;
    final v = VnTime.of(d);
    return DateTime(v.year, v.month, v.day);
  }

  /// Thành viên kế hoạch đích (R13); null = không lọc (chưa tải, lỗi, hoặc
  /// kế hoạch legacy không có danh sách).
  static Set<String>? _allowedOf(TaskProject? project) {
    final ids = project?.memberIdsWithOwner ?? const <String>[];
    return ids.isEmpty ? null : ids.toSet();
  }

  /// Teams theo thứ tự xuất hiện; "Chưa thuộc team" luôn cuối (R10).
  List<(String, String)> _teams(List<MovablePlan> plans) {
    final out = <String, String>{};
    var hasNone = false;
    for (final p in plans) {
      final key = _teamOf(p);
      if (key == _noTeam) {
        hasNone = true;
      } else {
        out.putIfAbsent(key, () {
          final name = p.teamName?.trim() ?? '';
          return name.isEmpty ? 'Team' : name;
        });
      }
    }

    return [
      for (final e in out.entries) (e.key, e.value),
      if (hasNone) (_noTeam, 'Chưa thuộc team'),
    ];
  }

  void _pickTeam(String? key) {
    final plans = _all;
    if (key == null || plans == null || key == _team) return;
    final first = plans.where((p) => _teamOf(p) == key).firstOrNull;
    setState(() {
      _team = key;
      if (first != null) _selectPlan(first);
    });
  }

  void _pickPlan(String? id) {
    final plan = _all?.where((p) => p.id == id).firstOrNull;
    if (plan == null || plan.id == _plan?.id) return;
    setState(() => _selectPlan(plan));
  }

  /// Đổi kế hoạch: nhóm đầu tiên; bỏ người không thuộc kế hoạch mới (R13).
  void _selectPlan(MovablePlan plan) {
    _plan = plan;
    _sectionId = plan.sections.firstOrNull?.id;
    final allowed = _allowedOf(
      ref.read(taskProjectProvider(plan.id)).valueOrNull,
    );
    if (allowed != null) _people.retainWhere(allowed.contains);
  }

  bool get _datesInvalid {
    final start = _start;
    final due = _due;
    return start != null && due != null && due.isBefore(start);
  }

  Future<void> _pickDate({required bool start}) async {
    final current = start ? _start : _due;
    final now = DateTime.now();
    final initial = current ?? (start ? _due : _start) ?? now;
    var first = DateTime(now.year - 1);
    var last = DateTime(now.year + 3, 12, 31);
    if (initial.isBefore(first)) first = DateTime(initial.year - 1);
    if (initial.isAfter(last)) last = DateTime(initial.year + 1, 12, 31);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
    );
    if (picked == null || !mounted) return;
    final day = DateUtils.dateOnly(picked);
    setState(() => start ? _start = day : _due = day);
  }

  Future<void> _addPeople(Set<String>? allowed, List<String> current) async {
    final picked = await showAssignTaskSheet(
      context: context,
      currentIds: current,
      allowedIds: allowed,
      title: 'Người thực hiện bản sao',
      confirmLabel: (n) => 'Chọn $n người',
    );
    if (picked == null || !mounted) return;
    setState(
      () => _people
        ..clear()
        ..addAll(picked),
    );
  }

  String _nameOf(String id, Map<String, TeamMember> byId) {
    final name = byId[id]?.name.trim() ?? '';
    if (name.isNotEmpty) return name;
    final i = widget.task.assigneeIds.indexOf(id);
    if (i >= 0 && i < widget.task.assigneeNames.length) {
      final fallback = widget.task.assigneeNames[i].trim();
      if (fallback.isNotEmpty) return fallback;
    }
    return 'Người dùng';
  }

  /// Tên các trường gốc (có giá trị) sẽ được chép sang kế hoạch đích — ghép
  /// như `CopyTask::customFieldsFor`: tên trim + không phân biệt hoa thường,
  /// CÙNG kiểu, `select` thì giá trị phải có trong lựa chọn đích.
  List<String> _matchedFields(
    List<CustomFieldDef> source,
    List<CustomFieldDef> target,
  ) {
    String key(CustomFieldDef d) => d.name.trim().toLowerCase();
    final byName = <String, CustomFieldDef>{};
    for (final d in target) {
      if (key(d).isNotEmpty) byName.putIfAbsent(key(d), () => d);
    }
    final used = <String>{};
    final out = <String>[];
    for (final d in source) {
      final value = widget.task.customFields[d.id];
      if (value == null || value == '') continue;
      final to = byName[key(d)];
      if (to == null || to.type != d.type || used.contains(to.id)) continue;
      if (to.type == CustomFieldType.select &&
          !(value is String && to.options.contains(value))) {
        continue;
      }
      used.add(to.id);
      out.add(d.name.trim());
    }

    return out;
  }

  void _submit({required bool extended, required List<String> people}) {
    final plan = _plan;
    if (plan == null) return;
    final task = widget.task;
    final samePlan = plan.id == task.projectId;
    final section = plan.sections.where((s) => s.id == _sectionId).firstOrNull;
    final request = TaskCopyRequest(
      title: _title.text,
      projectId: plan.id,
      // Cùng kế hoạch + cùng nhóm: không gửi, để server tự lùi về cột không
      // có cổng QC (R12). Kế hoạch không có nhóm: không gửi.
      sectionId:
          plan.sections.isEmpty || (samePlan && _sectionId == task.sectionId)
          ? null
          : _sectionId,
      keepAssignees: extended ? true : _keepAssignees,
      keepChecklist: _keepChecklist,
      startDate: extended && !sameCopyDay(_start, _origStart)
          ? (date: _start)
          : null,
      dueDate: extended && !sameCopyDay(_due, _origDue) ? (date: _due) : null,
      assigneeIds: extended && _pickOthers ? [...people] : null,
      keepCustomFields: extended && task.customFields.isNotEmpty
          ? _copyFields
          : null,
    );
    Navigator.of(context).pop<TaskCopyResult>((
      request: request,
      placeName: section?.name ?? plan.name,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final extended = ref.watch(
      apiSupportsProvider(ApiCapability.taskCopyOptions),
    );
    final byId = ref.watch(teamMemberByIdProvider);
    final task = widget.task;
    final plan = _plan;

    final target = plan == null
        ? null
        : ref.watch(taskProjectProvider(plan.id)).valueOrNull;
    if (plan != null) {
      ref.listen(taskProjectProvider(plan.id), (_, next) {
        final allowed = _allowedOf(next.valueOrNull);
        if (allowed == null || _people.every(allowed.contains)) return;
        setState(() => _people.retainWhere(allowed.contains));
      });
    }
    final allowed = _allowedOf(target);
    final people = [
      for (final id in _people)
        if (allowed == null || allowed.contains(id)) id,
    ];

    final canSubmit =
        _title.text.trim().isNotEmpty &&
        plan != null &&
        !(extended && _datesInvalid);
    final bottom = MediaQuery.viewPaddingOf(context).bottom;

    return Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      label: 'Sao chép công việc',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: OmniSheetHandle(gap: 0),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: OmniColors.trackOf(context)),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Sao chép công việc',
                      style: OmniType.section.copyWith(color: scheme.onSurface),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Đóng',
                    onPressed: () => Navigator.of(context).pop(),
                    style: IconButton.styleFrom(
                      minimumSize: const Size(44, 44),
                    ),
                    icon: const Icon(Icons.close_rounded, size: 20),
                  ),
                ],
              ),
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 16,
                children: [
                  _Field(
                    label: 'Tên công việc',
                    child: TextField(
                      controller: _title,
                      maxLength: kTaskTitleMax,
                      style: OmniType.body.copyWith(color: scheme.onSurface),
                      decoration: _inputDecoration(
                        context,
                      ).copyWith(counterText: ''),
                    ),
                  ),
                  ..._placeFields(context),
                  if (extended) ...[
                    _dates(context),
                    _assignees(context, byId, people, allowed),
                    if (task.customFields.isNotEmpty)
                      _customFields(context, target),
                  ] else
                    _SwitchRow(
                      label: 'Giữ người thực hiện',
                      note: _keepNote(byId),
                      value: _keepAssignees,
                      onChanged: (v) => setState(() => _keepAssignees = v),
                    ),
                  if (task.subtasks.isNotEmpty)
                    DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(color: OmniColors.trackOf(context)),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: _SwitchRow(
                          label: 'Chép cả việc con',
                          note:
                              '${task.subtasks.length} việc con, bỏ đánh dấu '
                              'đã xong',
                          value: _keepChecklist,
                          onChanged: (v) => setState(() => _keepChecklist = v),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: OmniColors.trackOf(context)),
              ),
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 10, 16, 28 + bottom),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                      child: const Text('Huỷ'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: canSubmit
                          ? () => _submit(extended: extended, people: people)
                          : null,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                      child: const Text('Sao chép'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(BuildContext context) {
    OutlineInputBorder border(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: color),
    );
    final scheme = Theme.of(context).colorScheme;

    return InputDecoration(
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      constraints: const BoxConstraints(minHeight: 44),
      enabledBorder: border(OmniColors.controlBorderOf(context)),
      disabledBorder: border(OmniColors.trackOf(context)),
      focusedBorder: border(scheme.primary),
      border: border(OmniColors.controlBorderOf(context)),
    );
  }

  /// Ba ô Team / Kế hoạch / Nhóm việc; đang tải thì vòng xoay, lỗi thì
  /// "Thử lại" (như `move_task_sheet.dart`).
  List<Widget> _placeFields(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final plans = _all;
    if (_loadFailed) {
      return [
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Chưa tải được danh sách kế hoạch.',
              style: OmniType.caption.copyWith(color: scheme.onSurfaceVariant),
            ),
            TextButton(
              onPressed: _load,
              style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
              child: const Text('Thử lại'),
            ),
          ],
        ),
      ];
    }
    if (plans == null) {
      return const [
        Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }
    final plan = _plan;
    final teamPlans = [
      for (final p in plans)
        if (_teamOf(p) == _team) p,
    ];
    final style = OmniType.body.copyWith(color: scheme.onSurface);
    final sections = plan?.sections ?? const <TaskSection>[];

    return [
      _Field(
        label: 'Team',
        child: DropdownButtonFormField<String>(
          key: const ValueKey('copy-team'),
          initialValue: _team,
          isExpanded: true,
          style: style,
          decoration: _inputDecoration(context),
          items: [
            for (final (id, name) in _teams(plans))
              DropdownMenuItem(
                value: id,
                child: Text(name, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: _pickTeam,
        ),
      ),
      _Field(
        label: 'Kế hoạch',
        child: DropdownButtonFormField<String>(
          key: const ValueKey('copy-plan'),
          initialValue: plan?.id,
          isExpanded: true,
          style: style,
          decoration: _inputDecoration(context),
          items: [
            for (final p in teamPlans)
              DropdownMenuItem(
                value: p.id,
                child: Text(p.name, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: _pickPlan,
        ),
      ),
      _Field(
        label: 'Nhóm việc',
        child: DropdownButtonFormField<String>(
          key: const ValueKey('copy-section'),
          initialValue: sections.isEmpty ? null : _sectionId,
          isExpanded: true,
          style: style,
          decoration: _inputDecoration(context),
          disabledHint: Text(
            'Chưa xếp nhóm',
            style: style.copyWith(color: scheme.onSurfaceVariant),
          ),
          items: [
            for (final s in sections)
              DropdownMenuItem(
                value: s.id,
                child: Text(s.name, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: sections.isEmpty
              ? null
              : (id) => setState(() => _sectionId = id),
        ),
      ),
    ];
  }

  Widget _dates(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _Field(
                label: 'Từ ngày',
                child: _DateBox(
                  key: const ValueKey('copy-start'),
                  value: _start,
                  clearTooltip: 'Xoá ngày bắt đầu',
                  onTap: () => _pickDate(start: true),
                  onClear: () => setState(() => _start = null),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _Field(
                label: 'Đến ngày',
                child: _DateBox(
                  key: const ValueKey('copy-due'),
                  value: _due,
                  invalid: _datesInvalid,
                  clearTooltip: 'Xoá ngày kết thúc',
                  onTap: () => _pickDate(start: false),
                  onClear: () => setState(() => _due = null),
                ),
              ),
            ),
          ],
        ),
        if (_datesInvalid)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Ngày kết thúc phải từ ngày bắt đầu trở đi.',
              style: OmniType.caption.copyWith(color: scheme.error),
            ),
          ),
      ],
    );
  }

  String _keepNote(Map<String, TeamMember> byId) {
    final ids = widget.task.assigneeIds;
    if (ids.isEmpty) return 'Việc gốc chưa giao cho ai.';
    return 'Như việc gốc: ${ids.map((id) => _nameOf(id, byId)).join(', ')}.';
  }

  Widget _assignees(
    BuildContext context,
    Map<String, TeamMember> byId,
    List<String> people,
    Set<String>? allowed,
  ) {
    return _Field(
      label: 'Người thực hiện',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        spacing: 6,
        children: [
          OmniSegmented(
            labels: const ['Giữ nguyên', 'Chọn người khác'],
            index: _pickOthers ? 1 : 0,
            onChanged: (i) => setState(() => _pickOthers = i == 1),
          ),
          if (!_pickOthers)
            _Note(_keepNote(byId))
          else
            Wrap(
              spacing: 6,
              children: [
                for (final id in people)
                  _PersonChip(
                    name: _nameOf(id, byId),
                    avatar: byId[id]?.avatarUrl,
                    onRemove: () => setState(() => _people.remove(id)),
                  ),
                _AddPersonChip(onTap: () => _addPeople(allowed, people)),
              ],
            ),
        ],
      ),
    );
  }

  Widget _customFields(BuildContext context, TaskProject? target) {
    final plan = _plan;
    final projectId = widget.task.projectId;
    final source = projectId == null
        ? null
        : ref.watch(planCustomFieldsProvider(projectId)).valueOrNull;
    final cross = plan != null && plan.id != projectId;
    String? note;
    if (cross && _copyFields && source != null && target != null) {
      final names = _matchedFields(source, target.customFields);
      note = names.isEmpty
          ? 'Kế hoạch đích không có trường cùng tên — sẽ không chép trường '
                'nào.'
          : 'Khác kế hoạch: chỉ chép trường có cùng tên ở kế hoạch đích '
                '(${names.join(', ')}).';
    }

    return _Field(
      label: 'Trường tuỳ chỉnh',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        spacing: 6,
        children: [
          OmniSegmented(
            labels: const ['Không chép', 'Chép tất cả'],
            index: _copyFields ? 1 : 0,
            onChanged: (i) => setState(() => _copyFields = i == 1),
          ),
          if (note != null) _Note(note),
        ],
      ),
    );
  }
}

/// Nhãn 12/w500 phụ + ô, cách 6.
class _Field extends StatelessWidget {
  const _Field({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    spacing: 6,
    children: [
      Text(
        label,
        style: OmniType.micro.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      child,
    ],
  );
}

class _Note extends StatelessWidget {
  const _Note(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: OmniType.caption.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      height: 1.45,
    ),
  );
}

/// Ô ngày cao 44: chạm mở lịch; có giá trị thì có nút × 44 để xoá.
class _DateBox extends StatelessWidget {
  const _DateBox({
    super.key,
    required this.value,
    required this.clearTooltip,
    required this.onTap,
    required this.onClear,
    this.invalid = false,
  });

  final DateTime? value;
  final String clearTooltip;
  final VoidCallback onTap;
  final VoidCallback onClear;
  final bool invalid;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final value = this.value;
    final radius = BorderRadius.circular(8);

    return SizedBox(
      height: 44,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: radius,
          border: Border.all(
            color: invalid ? scheme.error : OmniColors.controlBorderOf(context),
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: radius,
            onTap: onTap,
            child: Row(
              children: [
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    value == null ? 'Chưa đặt' : Formatters.date(value),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: OmniType.body.copyWith(
                      color: value == null
                          ? scheme.onSurfaceVariant
                          : scheme.onSurface,
                    ),
                  ),
                ),
                if (value != null)
                  IconButton(
                    tooltip: clearTooltip,
                    onPressed: onClear,
                    style: IconButton.styleFrom(
                      minimumSize: const Size(44, 44),
                      padding: EdgeInsets.zero,
                    ),
                    icon: Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: scheme.onSurfaceVariant,
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

/// Chip người: avatar 24, tên, nút × vẽ 32 trong vùng chạm 44. Nền chip cao
/// 36 vẽ giữa hàng 44.
class _PersonChip extends StatelessWidget {
  const _PersonChip({
    required this.name,
    required this.avatar,
    required this.onRemove,
  });

  final String name;
  final String? avatar;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: 44,
      child: Stack(
        children: [
          Positioned.fill(
            top: 4,
            bottom: 4,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(width: 6),
              OmniAvatar(name: name, imageUrl: avatar, size: 24),
              const SizedBox(width: 6),
              Text(
                name,
                style: OmniType.bodySm.copyWith(color: scheme.onSurface),
              ),
              Tooltip(
                message: 'Bỏ $name',
                child: Semantics(
                  button: true,
                  label: 'Bỏ $name',
                  excludeSemantics: true,
                  child: InkResponse(
                    onTap: onRemove,
                    radius: 16,
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: Center(
                        child: Icon(
                          Icons.close_rounded,
                          size: 14,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Chip viền đứt "+ Thêm người" (vẽ 36, vùng chạm 44).
class _AddPersonChip extends StatelessWidget {
  const _AddPersonChip({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      key: const ValueKey('copy-add-person'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        height: 44,
        child: Center(
          child: OmniDashedBox(
            height: 36,
            radius: 18,
            strokeWidth: 1,
            color: OmniTaskTones.of(context).faint,
            fill: scheme.surface,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Center(
                widthFactor: 1,
                child: Text(
                  '+ Thêm người',
                  style: OmniType.bodySm.copyWith(
                    fontWeight: FontWeight.w500,
                    color: scheme.onSurface,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Dòng có công tắc: tiêu đề, ghi chú, `Switch` (vùng chạm 48 của Material).
class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.label,
    required this.note,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String note;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // Cả dòng chạm được (bật/tắt), không chỉ con công tắc.
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Row(
          spacing: 12,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: OmniType.body.copyWith(
                      fontWeight: FontWeight.w500,
                      color: scheme.onSurface,
                    ),
                  ),
                  _Note(note),
                ],
              ),
            ),
            Semantics(
              label: label,
              child: Switch(value: value, onChanged: onChanged),
            ),
          ],
        ),
      ),
    );
  }
}
