import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/error/app_exception.dart';
import '../../../../../core/utils/formatters.dart';
import '../../../../../design/components/components.dart';
import '../../../../../design/tokens/tokens.dart';
import '../../../../team/team.dart';
import '../../../application/tasks_providers.dart';
import '../../../domain/task.dart';
import '../subtask_assignee_sheet.dart';
import 'detail_card.dart';

/// Thứ người dùng nhập ở sheet "Việc con mới".
typedef SubtaskDraft = ({
  String title,
  String? assigneeId,
  String? description,
  DateTime? startDate,
  DateTime? dueDate,
});

/// Chọn một ngày (mặc định `pickOmniDate`); tiêm được để test.
typedef SubtaskDatePicker =
    Future<DateTime?> Function(BuildContext context, DateTime initial);

Future<DateTime?> _pickWithCalendar(BuildContext context, DateTime initial) {
  final today = DateUtils.dateOnly(DateTime.now());

  return pickOmniDate(
    context: context,
    initialDate: initial,
    firstDate: DateTime(today.year - 1),
    lastDate: DateTime(today.year + 3),
  );
}

/// Sheet "Việc con mới" (`SubtaskCreate.dc.html`): gần toàn màn (cách trên
/// 54), đầu Huỷ / "Việc con mới" / Tạo, ô tên, dòng Người làm.
///
/// [details] (phiên khai `tasks.subtask_fields`): thêm ô mô tả nhiều dòng 76,
/// hai ô ngày (bắt đầu, hạn; có giá trị thì viền màu chính) và chip nhanh 36
/// "Hôm nay / Ngày mai / Tuần sau" (+0 / +1 / +7 ngày) đặt HẠN. Không có thì
/// KHÔNG vẽ (API cũ bỏ qua các khoá đó).
///
/// [onCreate] chạy khi bấm Tạo; xong thì sheet đóng. Nó ném [AppException]
/// thì sheet ở lại (giữ chữ đã gõ) và báo lỗi.
Future<void> showSubtaskCreateSheet(
  BuildContext context, {
  required String? projectId,
  required bool canAssign,
  required Future<void> Function(SubtaskDraft draft) onCreate,
  bool details = false,
  SubtaskDatePicker pickDate = _pickWithCalendar,
}) {
  final height = MediaQuery.sizeOf(context).height;

  return showOmniSheet<void>(
    context: context,
    barrierColor: OmniColors.ink.withValues(alpha: 0.4),
    maxHeight: height - 54,
    animationStyle: const AnimationStyle(
      duration: OmniDuration.sheet,
      curve: OmniCurves.sheet,
      reverseDuration: OmniDuration.base,
    ),
    builder: (_) => SubtaskCreateSheet(
      projectId: projectId,
      canAssign: canAssign,
      onCreate: onCreate,
      details: details,
      pickDate: pickDate,
    ),
  );
}

class SubtaskCreateSheet extends ConsumerStatefulWidget {
  const SubtaskCreateSheet({
    super.key,
    required this.projectId,
    required this.canAssign,
    required this.onCreate,
    this.details = false,
    this.pickDate = _pickWithCalendar,
  });

  final String? projectId;
  final bool canAssign;
  final Future<void> Function(SubtaskDraft draft) onCreate;

  /// Vẽ mô tả, ngày, chip nhanh (Nhóm 2).
  final bool details;
  final SubtaskDatePicker pickDate;

  @override
  ConsumerState<SubtaskCreateSheet> createState() => _SubtaskCreateSheetState();
}

class _SubtaskCreateSheetState extends ConsumerState<SubtaskCreateSheet> {
  final _name = TextEditingController();
  final _description = TextEditingController();
  String? _assigneeId;
  DateTime? _start;
  DateTime? _due;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  bool get _canCreate => !_busy && _name.text.trim().isNotEmpty;

  static DateTime _today() => DateUtils.dateOnly(DateTime.now());

  Future<void> _create() async {
    if (!_canCreate) return;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    // Server KHÔNG kiểm bắt đầu ≤ hạn: chặn ở đây.
    final start = _start;
    final due = _due;
    if (start != null && due != null && start.isAfter(due)) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Ngày bắt đầu phải trước hạn.')),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.onCreate((
        title: _name.text.trim(),
        assigneeId: _assigneeId,
        description: widget.details ? _description.text.trim() : null,
        startDate: widget.details ? start : null,
        dueDate: widget.details ? due : null,
      ));
      navigator.pop();
    } on AppException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickAssignee() async {
    final result = await showSubtaskAssigneeSheet(
      context,
      projectId: widget.projectId,
      subtask: Subtask(
        id: '',
        title: _name.text.trim(),
        done: false,
        assigneeId: _assigneeId,
      ),
    );
    if (result == null || !mounted) return;
    setState(
      () => _assigneeId = result is SubtaskAssignTo ? result.userId : null,
    );
  }

  Future<void> _pick({required bool start}) async {
    final current = start ? _start : _due;
    final chosen = await widget.pickDate(
      context,
      current ?? (start ? null : _start) ?? _today(),
    );
    if (chosen == null || !mounted) return;
    final day = DateUtils.dateOnly(chosen);
    setState(() => start ? _start = day : _due = day);
  }

  TeamMember? _member(String id) {
    final list = widget.projectId == null
        ? ref.watch(teamMembersProvider).valueOrNull
        : ref.watch(projectMembersProvider(widget.projectId!)).valueOrNull;
    for (final m in list ?? const <TeamMember>[]) {
      if (m.userId == id) return m;
    }

    return ref.watch(teamMemberByIdProvider)[id];
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final secondary = detailSecondary(context);
    final picked = _assigneeId;
    final member = picked == null ? null : _member(picked);

    return Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      label: 'Tạo việc con',
      child: OmniSheetBody(
        header: OmniSheetHeader(
          title: 'Việc con mới',
          trailing: OmniGlassCircle(
            child: IconButton(
              tooltip: 'Huỷ',
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close_rounded, size: OmniIconSize.lg),
            ),
          ),
        ),
        footer: ValueListenableBuilder<TextEditingValue>(
          valueListenable: _name,
          builder: (context, _, _) => FilledButton(
            onPressed: _canCreate ? _create : null,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
            child: _busy
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                  )
                : const Text('Tạo'),
          ),
        ),
        children: [
          OmniGroupSection(
            dividerIndent: 14,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: TextField(
                  controller: _name,
                  autofocus: true,
                  enabled: !_busy,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _create(),
                  style: OmniType.body.copyWith(color: scheme.onSurface),
                  decoration: InputDecoration(
                    hintText: 'Tên việc con',
                    hintStyle: OmniType.body.copyWith(color: secondary),
                    isDense: true,
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              if (widget.details)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: TextField(
                    key: const ValueKey('subtask-create-description'),
                    controller: _description,
                    enabled: !_busy,
                    minLines: 3,
                    maxLines: 6,
                    // `CreateChecklistItemRequest` `description` `max:2000`.
                    maxLength: 2000,
                    textCapitalization: TextCapitalization.sentences,
                    style: OmniType.body.copyWith(color: scheme.onSurface),
                    decoration: InputDecoration(
                      hintText: 'Mô tả (không bắt buộc)',
                      hintStyle: OmniType.body.copyWith(color: secondary),
                      counterText: '',
                      isDense: true,
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
            ],
          ),
          if (widget.canAssign)
            OmniGroupSection(
              dividerIndent: 14,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: Padding(
                    padding: const EdgeInsets.only(left: 14, right: 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Người làm',
                            style: OmniType.body.copyWith(
                              fontWeight: FontWeight.w500,
                              color: scheme.onSurface,
                            ),
                          ),
                        ),
                        if (picked != null)
                          Semantics(
                            label: 'Người làm: ${member?.name ?? 'đã chọn'}',
                            excludeSemantics: true,
                            child: OmniAvatar(
                              name: member?.name ?? '?',
                              imageUrl: member?.avatarUrl,
                              size: 30,
                            ),
                          ),
                        Semantics(
                          button: true,
                          label: 'Chọn người làm',
                          excludeSemantics: true,
                          child: InkWell(
                            onTap: _busy ? null : _pickAssignee,
                            customBorder: const CircleBorder(),
                            child: SizedBox.square(
                              dimension: 44,
                              child: Center(
                                child: OmniDashedCircle(
                                  size: 30,
                                  color: scheme.primary,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          if (widget.details)
            Row(
              children: [
                Expanded(
                  child: _DateBox(
                    key: const ValueKey('subtask-create-start'),
                    empty: 'Ngày bắt đầu',
                    prefix: 'Bắt đầu',
                    value: _start,
                    clearLabel: 'Xoá ngày bắt đầu',
                    onTap: _busy ? null : () => _pick(start: true),
                    onClear: _busy ? null : () => setState(() => _start = null),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _DateBox(
                    key: const ValueKey('subtask-create-due'),
                    empty: 'Hạn',
                    prefix: 'Hạn',
                    value: _due,
                    clearLabel: 'Xoá hạn',
                    onTap: _busy ? null : () => _pick(start: false),
                    onClear: _busy ? null : () => setState(() => _due = null),
                  ),
                ),
              ],
            ),
          if (widget.details)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final (label, days) in const [
                    ('Hôm nay', 0),
                    ('Ngày mai', 1),
                    ('Tuần sau', 7),
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _QuickChip(
                        label: label,
                        on: _due == _today().add(Duration(days: days)),
                        onTap: _busy
                            ? null
                            : () => setState(
                                () => _due = _today().add(Duration(days: days)),
                              ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Ô ngày: nền mờ của ô nhập (theme), bo 14, không viền; có giá trị thì
/// chữ màu chính và nút × 44 để xoá.
class _DateBox extends StatelessWidget {
  const _DateBox({
    super.key,
    required this.empty,
    required this.prefix,
    required this.value,
    required this.clearLabel,
    required this.onTap,
    required this.onClear,
  });

  final String empty;
  final String prefix;
  final DateTime? value;
  final String clearLabel;
  final VoidCallback? onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final date = value;
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: scheme.onSurface.withValues(alpha: dark ? .08 : .05),
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 48,
          child: Row(
            children: [
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  date == null ? empty : '$prefix ${Formatters.dayMonth(date)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: OmniType.bodySm.copyWith(
                    fontWeight: date == null ? null : FontWeight.w600,
                    color: date == null
                        ? detailSecondary(context)
                        : scheme.primary,
                  ),
                ),
              ),
              if (date != null)
                IconButton(
                  tooltip: clearLabel,
                  onPressed: onClear,
                  style: IconButton.styleFrom(
                    minimumSize: const Size(44, 44),
                    maximumSize: const Size(44, 44),
                    padding: EdgeInsets.zero,
                  ),
                  icon: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: detailSecondary(context),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Chip ngày nhanh: chip kính, chọn = trắng mờ.
class _QuickChip extends StatelessWidget {
  const _QuickChip({
    required this.label,
    required this.on,
    required this.onTap,
  });

  final String label;
  final bool on;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Hạn: $label',
      excludeSemantics: true,
      button: true,
      selected: on,
      onTap: onTap,
      child: OmniChoicePill(
        key: ValueKey('quick-chip-$label'),
        label: label,
        selected: on,
        onTap: onTap,
      ),
    );
  }
}
