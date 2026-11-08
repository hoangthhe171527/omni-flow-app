import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/utils/formatters.dart';
import '../../../../../design/components/components.dart';
import '../../../../../design/tokens/tokens.dart';
import '../../../../../security/session/api_capabilities.dart';
import '../../../../../security/session/session_controller.dart';
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
/// `placeName` null = bản sao không thuộc kế hoạch nào (việc cá nhân).
typedef TaskCopyResult = ({TaskCopyRequest request, String? placeName});

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

/// Giá trị "Không thuộc kế hoạch" trong ô Kế hoạch (không trùng id nào).
const _noPlan = '\u0000no-plan';

class _CopyTaskSheetState extends ConsumerState<CopyTaskSheet> {
  late final _title = TextEditingController(
    text: copyTitleOf(widget.task.title),
  );

  List<MovablePlan>? _all;
  bool _loadFailed = false;

  String? _team;
  MovablePlan? _plan;

  /// Việc gốc là việc cá nhân. Chỉ khi đó mới có lựa chọn "Không thuộc kế
  /// hoạch": thiếu `project_id` thì server chép vào kế hoạch GỐC
  /// (`CopyTask`: `project_id ?? sourceProject`), nên với việc trong kế hoạch
  /// lựa chọn ấy sẽ là nói dối.
  bool get _personalSource => (widget.task.projectId ?? '').isEmpty;

  /// Đang chọn "Không thuộc kế hoạch": không gửi project_id / section_id.
  late bool _personal = _personalSource;
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
      final me = ref.read(sessionProvider).user?.id;
      // Kế hoạch mình chỉ xem: server trả 403 cho mọi lượt chép vào đó
      // (`assertCanEditTasks`), nên không đưa ra cho chọn — kể cả làm mặc định.
      final plans = [
        for (final p in await ref.read(tasksApiProvider).projectsForMove())
          if (!isPlanViewer(p, me)) p,
      ];
      if (!mounted) return;
      setState(() {
        _all = plans;
        if (_personal) return;
        final source =
            plans.where((p) => p.id == widget.task.projectId).firstOrNull ??
            plans.firstOrNull;
        if (source == null) return;
        _team = _teamOf(source);
        _plan = source;
        final sections = source.sections;
        final from = widget.task.sectionId;
        // Gốc chưa xếp nhóm và vẫn ở kế hoạch gốc: để trống, không tự chọn
        // nhóm đầu — chọn sẵn là gửi section_id người dùng không hề chọn.
        _sectionId = source.id == widget.task.projectId && from == null
            ? null
            : sections.any((s) => s.id == from)
            ? from
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
  /// với ngày `pickOmniDate` trả, để so và để `ymd` in đúng.
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
    if (id == _noPlan) {
      setState(() {
        _personal = true;
        _plan = null;
        _team = null;
        _sectionId = null;
      });
      return;
    }
    final plan = _all?.where((p) => p.id == id).firstOrNull;
    if (plan == null || (!_personal && plan.id == _plan?.id)) return;
    setState(() {
      _personal = false;
      _team = _teamOf(plan);
      _selectPlan(plan);
    });
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
    final picked = await pickOmniDate(
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
    final plan = _personal ? null : _plan;
    if (plan == null && !_personal) return;
    final task = widget.task;
    final samePlan = plan?.id == task.projectId;
    final section = plan?.sections.where((s) => s.id == _sectionId).firstOrNull;
    final request = TaskCopyRequest(
      title: _title.text,
      // Không thuộc kế hoạch (chỉ có với việc cá nhân): không gửi khoá nào —
      // server giữ "không kế hoạch" của việc gốc.
      projectId: plan?.id,
      // Cùng kế hoạch + cùng nhóm: không gửi, để server tự lùi về cột không
      // có cổng QC (R12). Kế hoạch không có nhóm: không gửi.
      sectionId:
          plan == null ||
              plan.sections.isEmpty ||
              (samePlan && _sectionId == task.sectionId)
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
      placeName: section?.name ?? plan?.name,
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
    final plan = _personal ? null : _plan;

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
        (_personal || plan != null) &&
        !(extended && _datesInvalid);

    return Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      label: 'Sao chép công việc',
      child: OmniSheetBody(
        header: OmniSheetHeader(
          title: 'Sao chép công việc',
          trailing: IconButton(
            tooltip: 'Đóng',
            onPressed: () => Navigator.of(context).pop(),
            style: IconButton.styleFrom(minimumSize: const Size(44, 44)),
            icon: const Icon(Icons.close_rounded, size: 20),
          ),
        ),
        footer: FilledButton(
          onPressed: canSubmit
              ? () => _submit(extended: extended, people: people)
              : null,
          child: const Text('Sao chép'),
        ),
        children: [
          OmniField(
            label: 'Tên công việc',
            child: TextField(
              controller: _title,
              maxLength: kTaskTitleMax,
              style: OmniType.body.copyWith(color: scheme.onSurface),
              decoration: const InputDecoration(counterText: ''),
            ),
          ),
          ..._placeFields(context),
          if (extended) ...[
            ..._dates(context),
            _assignees(context, byId, people, allowed),
            if (task.customFields.isNotEmpty) _customFields(context, target),
          ] else if (task.assigneeIds.isNotEmpty)
            _SwitchRow(
              label: 'Giữ người thực hiện',
              note: _keepNote(byId),
              value: _keepAssignees,
              onChanged: (v) => setState(() => _keepAssignees = v),
            ),
          if (task.subtasks.isNotEmpty)
            _SwitchRow(
              label: 'Chép cả việc con',
              note: '${task.subtasks.length} việc con, bỏ đánh dấu đã xong',
              value: _keepChecklist,
              onChanged: (v) => setState(() => _keepChecklist = v),
            ),
        ],
      ),
    );
  }

  /// Chọn một giá trị trong sheet con (dòng chọn ✓), như "Chuyển sang kế
  /// hoạch". Trả khoá đã chọn; null khi đóng.
  Future<String?> _choose({
    required String title,
    required List<(String, String)> options,
    required String? current,
  }) => showOmniViecSheet<String>(
    context: context,
    builder: (sheet) => OmniSheetBody(
      semanticsLabel: title,
      header: OmniSheetHeader(title: title),
      children: [
        OmniGroupSection(
          dividerIndent: 14,
          children: [
            for (final (key, label) in options)
              OmniGroupRow(
                title: label,
                selected: key == current,
                onTap: () => Navigator.of(sheet).pop(key),
              ),
          ],
        ),
      ],
    ),
  );

  /// Ba dòng Team / Kế hoạch / Nhóm việc mở sheet con; đang tải thì vòng
  /// xoay, lỗi thì "Thử lại" (như `move_task_sheet.dart`).
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
          child: Center(child: CircularProgressIndicator.adaptive()),
        ),
      ];
    }
    final plan = _personal ? null : _plan;
    // "Không thuộc kế hoạch" thì chưa có team để lọc: liệt kê mọi kế hoạch.
    final teamPlans = [
      for (final p in plans)
        if (_personal || _teamOf(p) == _team) p,
    ];
    final teams = _teams(plans);
    final sections = plan?.sections ?? const <TaskSection>[];
    final section = sections.where((s) => s.id == _sectionId).firstOrNull;

    return [
      OmniGroupSection(
        dividerIndent: 14,
        children: [
          if (!_personal)
            OmniGroupRow(
              key: const ValueKey('copy-team'),
              title: 'Team',
              value: [
                for (final (id, name) in teams)
                  if (id == _team) name,
              ].firstOrNull,
              onTap: () async {
                final id = await _choose(
                  title: 'Team',
                  options: teams,
                  current: _team,
                );
                _pickTeam(id);
              },
            ),
          OmniGroupRow(
            key: const ValueKey('copy-plan'),
            title: 'Kế hoạch',
            value: _personal ? 'Không thuộc kế hoạch' : plan?.name,
            onTap: () async {
              final id = await _choose(
                title: 'Kế hoạch',
                options: [
                  if (_personalSource) (_noPlan, 'Không thuộc kế hoạch'),
                  for (final p in teamPlans) (p.id, p.name),
                ],
                current: _personal ? _noPlan : plan?.id,
              );
              _pickPlan(id);
            },
          ),
          if (!_personal)
            OmniGroupRow(
              key: const ValueKey('copy-section'),
              title: 'Nhóm việc',
              value: section?.name ?? 'Chưa xếp nhóm',
              onTap: sections.isEmpty
                  ? null
                  : () async {
                      final id = await _choose(
                        title: 'Nhóm việc',
                        options: [for (final s in sections) (s.id, s.name)],
                        current: _sectionId,
                      );
                      if (id != null && mounted) {
                        setState(() => _sectionId = id);
                      }
                    },
            ),
        ],
      ),
    ];
  }

  List<Widget> _dates(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    Widget dateRow({
      required Key key,
      required String title,
      required DateTime? value,
      required String clearTooltip,
      required bool start,
    }) => OmniGroupRow(
      key: key,
      title: title,
      value: value == null ? 'Chưa đặt' : Formatters.date(value),
      trailing: value == null
          ? null
          : IconButton(
              tooltip: clearTooltip,
              onPressed: () =>
                  setState(() => start ? _start = null : _due = null),
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
      onTap: () => _pickDate(start: start),
    );

    return [
      OmniGroupSection(
        dividerIndent: 14,
        children: [
          dateRow(
            key: const ValueKey('copy-start'),
            title: 'Từ ngày',
            value: _start,
            clearTooltip: 'Xoá ngày bắt đầu',
            start: true,
          ),
          dateRow(
            key: const ValueKey('copy-due'),
            title: 'Đến ngày',
            value: _due,
            clearTooltip: 'Xoá ngày kết thúc',
            start: false,
          ),
        ],
      ),
      if (_datesInvalid)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            'Ngày kết thúc phải từ ngày bắt đầu trở đi.',
            style: OmniType.caption.copyWith(color: scheme.error),
          ),
        ),
    ];
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

/// Nhãn phụ ngoài thẻ (như nhãn nhóm) + nội dung, cách 6.
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
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Text(
          label,
          style: OmniType.caption.copyWith(
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
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
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8),
    child: Text(
      text,
      style: OmniType.caption.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        height: 1.45,
      ),
    ),
  );
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
    final dark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      height: 44,
      child: Stack(
        children: [
          Positioned.fill(
            top: 4,
            bottom: 4,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.onSurface.withValues(alpha: dark ? .08 : .05),
                borderRadius: BorderRadius.circular(999),
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

/// Chip kính "+ Thêm người" (vẽ 36, vùng chạm 44).
class _AddPersonChip extends StatelessWidget {
  const _AddPersonChip({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
    key: const ValueKey('copy-add-person'),
    height: 44,
    child: Center(
      widthFactor: 1,
      child: OmniChoicePill(
        label: '+ Thêm người',
        selected: false,
        onTap: onTap,
      ),
    ),
  );
}

/// Dòng có công tắc trong nhóm riêng: tiêu đề, ghi chú, `Switch.adaptive`.
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
  Widget build(BuildContext context) => OmniGroupSection(
    dividerIndent: 14,
    children: [
      // Cả dòng chạm được (bật/tắt), không chỉ con công tắc.
      OmniGroupRow(
        title: label,
        subtitle: note,
        onTap: () => onChanged(!value),
        trailing: Semantics(
          label: label,
          child: Switch.adaptive(
            value: value,
            onChanged: (v) {
              HapticFeedback.selectionClick();
              onChanged(v);
            },
          ),
        ),
      ),
    ],
  );
}
