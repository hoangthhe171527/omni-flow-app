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

/// Chọn một ngày (mặc định `showDatePicker`); tiêm được để test.
typedef SubtaskDatePicker =
    Future<DateTime?> Function(BuildContext context, DateTime initial);

Future<DateTime?> _pickWithCalendar(BuildContext context, DateTime initial) {
  final today = DateUtils.dateOnly(DateTime.now());

  return showDatePicker(
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
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    barrierColor: OmniColors.ink.withValues(alpha: 0.4),
    maxHeight: height - 54,
    radius: OmniRadius.fab,
    showDragHandle: false,
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
    final focusRing = OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: scheme.primary),
    );

    return Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      label: 'Tạo việc con',
      child: SizedBox(
        height: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: scheme.outlineVariant),
                ),
              ),
              child: Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(64, 44),
                      foregroundColor: secondary,
                      textStyle: OmniType.body.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    child: const Text('Huỷ'),
                  ),
                  Expanded(
                    child: Text(
                      'Việc con mới',
                      textAlign: TextAlign.center,
                      style: OmniType.section.copyWith(color: scheme.onSurface),
                    ),
                  ),
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _name,
                    builder: (context, _, _) => TextButton(
                      onPressed: _canCreate ? _create : null,
                      style: TextButton.styleFrom(
                        minimumSize: const Size(64, 44),
                        foregroundColor: scheme.primary,
                        disabledForegroundColor: scheme.primary.withValues(
                          alpha: 0.4,
                        ),
                        textStyle: OmniType.bodyStrong,
                      ),
                      child: _busy
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Tạo'),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _name,
                      autofocus: true,
                      enabled: !_busy,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _create(),
                      style: OmniType.body.copyWith(color: scheme.onSurface),
                      decoration: InputDecoration(
                        hintText: 'Tên việc con',
                        filled: true,
                        fillColor: scheme.surface,
                        constraints: const BoxConstraints(minHeight: 48),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 13,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: scheme.outlineVariant),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: scheme.outlineVariant),
                        ),
                        focusedBorder: focusRing,
                      ),
                    ),
                    if (widget.details) ...[
                      const SizedBox(height: 12),
                      TextField(
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
                          filled: true,
                          fillColor: scheme.surface,
                          constraints: const BoxConstraints(minHeight: 76),
                          contentPadding: const EdgeInsets.all(12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: scheme.outlineVariant,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: scheme.outlineVariant,
                            ),
                          ),
                          focusedBorder: focusRing,
                        ),
                      ),
                    ],
                    if (widget.canAssign) ...[
                      const SizedBox(height: 12),
                      DetailCard(
                        flat: false,
                        children: [
                          DetailRow(
                            label: 'Người làm',
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                if (picked != null)
                                  Semantics(
                                    label:
                                        'Người làm: ${member?.name ?? 'đã chọn'}',
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
                                    borderRadius: BorderRadius.circular(6),
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
                        ],
                      ),
                    ],
                    if (widget.details) ...[
                      const SizedBox(height: 12),
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
                              onClear: _busy
                                  ? null
                                  : () => setState(() => _start = null),
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
                              onClear: _busy
                                  ? null
                                  : () => setState(() => _due = null),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        children: [
                          for (final (label, days) in const [
                            ('Hôm nay', 0),
                            ('Ngày mai', 1),
                            ('Tuần sau', 7),
                          ])
                            _QuickChip(
                              label: label,
                              on: _due == _today().add(Duration(days: days)),
                              onTap: _busy
                                  ? null
                                  : () => setState(
                                      () => _due = _today().add(
                                        Duration(days: days),
                                      ),
                                    ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ô ngày (`.in` của bản mẫu): cao 48, viền `#E3E8EF`; có giá trị thì viền
/// màu chính, chữ chính và nút × 44 để xoá.
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

    return Material(
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: date == null ? scheme.outlineVariant : scheme.primary,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 48,
          child: Row(
            children: [
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  date == null ? empty : '$prefix ${Formatters.dayMonth(date)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: OmniType.bodySm.copyWith(
                    color: date == null
                        ? detailSecondary(context)
                        : scheme.onSurface,
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

/// Chip nhanh `.qc`: cao 36 (vùng chạm 44), viền `#E3E8EF`; bật thì nền
/// `#E6F3F2` chữ `#075E59` viền màu chính.
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
    final scheme = Theme.of(context).colorScheme;
    final tone = OmniTaskTones.of(context).today;

    return Semantics(
      button: true,
      selected: on,
      label: 'Hạn: $label',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          height: 44,
          child: Center(
            widthFactor: 1,
            child: Container(
              key: ValueKey('quick-chip-$label'),
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: on ? tone.background : scheme.surface,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: on ? scheme.primary : scheme.outlineVariant,
                ),
              ),
              child: Text(
                label,
                style: OmniType.caption.copyWith(
                  fontWeight: FontWeight.w500,
                  color: on ? tone.foreground : detailSecondary(context),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
