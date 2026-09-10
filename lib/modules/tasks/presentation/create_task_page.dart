import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../../design/tokens/tokens.dart';
import '../../team/team.dart';
import '../data/tasks_api.dart';
import '../domain/task.dart';
import 'widgets/assign_task_sheet.dart';

/// Bối cảnh đi kèm khi mở màn tạo việc từ một cái bảng.
///
/// Truyền qua `extra` của go_router chứ không qua query string: `sections` là
/// một danh sách vật thể, và nhét nó vào URL nghĩa là tuần tự hoá rồi giải mã
/// lại một thứ đã nằm sẵn trong bộ nhớ.
class CreateTaskArgs {
  const CreateTaskArgs({this.planId, this.sectionId, this.sections = const []});

  final String? planId;
  final String? sectionId;
  final List<TaskSection> sections;
}

/// Tạo một công việc, từ điện thoại.
///
/// Trước đây không tạo được việc ở đâu trong app: `TasksApi` có tick, đổi
/// trạng thái, chuyển nhóm việc, bình luận, đính ảnh — không có tạo. Nên bước
/// đầu tiên của mọi quy trình đều bắt buộc mở máy tính, kể cả khi người tạo
/// đang đứng ngay cạnh thứ cần ghi lại.
///
/// Chỉ TÊN là bắt buộc. Người tạo việc thường đang giữa ca làm và chỉ kịp gõ
/// cái tên; điền nốt là chuyện của màn chi tiết sau đó. Bắt điền đủ năm ô mới
/// cho lưu là cách nhanh nhất để họ quay lại dùng giấy.
class CreateTaskPage extends ConsumerStatefulWidget {
  const CreateTaskPage({
    super.key,
    this.planId,
    this.sectionId,
    this.sections = const [],
  });

  /// Dự án việc này thuộc về. Null = việc rời, không nằm trên bảng nào.
  final String? planId;

  /// Nhóm việc điền sẵn — cột người dùng đang đứng lúc bấm tạo.
  final String? sectionId;

  /// Các nhóm việc của dự án, để đổi cột mà không phải gọi mạng lần nữa.
  final List<TaskSection> sections;

  @override
  ConsumerState<CreateTaskPage> createState() => _CreateTaskPageState();
}

class _CreateTaskPageState extends ConsumerState<CreateTaskPage> {
  final _title = TextEditingController();
  late String? _sectionId = widget.sectionId;
  List<String> _assigneeIds = const [];
  DateTime? _dueDate;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  bool get _canSave => _title.text.trim().isNotEmpty && !_saving;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final names = ref.watch(teamMemberByIdProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Việc mới')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          OmniSpacing.lg,
          OmniSpacing.lg,
          OmniSpacing.lg,
          OmniSpacing.bottomSafe,
        ),
        children: [
          TextField(
            controller: _title,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Tên việc',
              hintText: 'Việc cần làm là gì?',
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: OmniSpacing.xl),
          if (widget.sections.isNotEmpty)
            _Field(
              icon: Icons.view_column_outlined,
              label: 'Nhóm việc',
              value: _sectionName,
              muted: _sectionId == null,
              onTap: _pickSection,
            ),
          _Field(
            icon: Icons.person_outline_rounded,
            label: 'Người làm',
            value: _assigneeIds.isEmpty
                ? 'Chưa gán ai'
                : _assigneeIds
                      .map((id) => names[id]?.name ?? 'Người đã rời')
                      .join(', '),
            muted: _assigneeIds.isEmpty,
            onTap: _pickAssignees,
          ),
          _Field(
            icon: Icons.event_outlined,
            label: 'Hạn',
            value: _dueDate == null
                ? 'Chưa đặt hạn'
                : Formatters.date(_dueDate!),
            muted: _dueDate == null,
            onTap: _pickDueDate,
            // Đặt nhầm hạn rồi không gỡ được là một cái bẫy: hạn trống có
            // nghĩa ("chưa hẹn"), khác hẳn một ngày đại khái nào đó.
            onClear: _dueDate == null
                ? null
                : () => setState(() => _dueDate = null),
          ),
          if (_error != null) ...[
            const SizedBox(height: OmniSpacing.lg),
            Text(
              _error!,
              style: text.bodyMedium?.copyWith(
                color: OmniColors.dangerTextOf(context),
              ),
            ),
          ],
          const SizedBox(height: OmniSpacing.xxl),
          FilledButton(
            onPressed: _canSave ? _save : null,
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Tạo việc'),
          ),
          const SizedBox(height: OmniSpacing.md),
          Text(
            'Chỉ cần tên là tạo được. Hạn, người làm, việc con điền sau cũng '
            'kịp.',
            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  String get _sectionName =>
      widget.sections
          .where((s) => s.id == _sectionId)
          .map((s) => s.name)
          .firstOrNull ??
      'Chưa xếp nhóm việc';

  Future<void> _pickSection() async {
    final chosen = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final section in widget.sections)
              ListTile(
                title: Text(section.name),
                trailing: section.id == _sectionId
                    ? const Icon(Icons.check_rounded)
                    : null,
                onTap: () => Navigator.of(context).pop(section.id),
              ),
          ],
        ),
      ),
    );

    if (chosen != null) setState(() => _sectionId = chosen);
  }

  Future<void> _pickAssignees() async {
    final chosen = await showAssignTaskSheet(
      context: context,
      currentIds: _assigneeIds,
    );

    if (chosen != null) setState(() => _assigneeIds = chosen);
  }

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final chosen = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now,
      // Hạn trong quá khứ vẫn chọn được: người ta hay nhập lại việc đã trễ.
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
    );

    if (chosen != null) setState(() => _dueDate = chosen);
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final task = await ref
          .read(tasksApiProvider)
          .create(
            title: _title.text.trim(),
            projectId: widget.planId,
            sectionId: _sectionId,
            assigneeIds: _assigneeIds,
            dueDate: _dueDate,
          );

      if (!mounted) return;
      // Trả id lên chỗ gọi: màn bảng dùng nó để làm mới, và nó cũng là bằng
      // chứng đã tạo xong — khác hẳn một pop trống.
      //
      // Navigator.pop chứ không phải context.pop của go_router: cái sau đòi
      // một GoRouter trong cây widget, nên màn này không dựng riêng ra để kiểm
      // được. Với một route đã push thì hai cái làm đúng một việc.
      Navigator.of(context).pop(task.id);
    } on AppException catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.message;
      });
    }
  }
}

/// Một dòng "nhãn — giá trị" bấm được, giống bảng điều phối ở màn chi tiết.
class _Field extends StatelessWidget {
  const _Field({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
    this.muted = false,
    this.onClear,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;
  final bool muted;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return InkWell(
      onTap: onTap,
      borderRadius: OmniRadius.mdAll,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: OmniSpacing.md),
        child: Row(
          children: [
            Icon(icon, size: OmniIconSize.md, color: scheme.onSurfaceVariant),
            const SizedBox(width: OmniSpacing.md),
            SizedBox(
              width: 92,
              child: Text(
                label,
                style: text.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: text.bodyMedium?.copyWith(
                  fontWeight: muted ? FontWeight.w400 : FontWeight.w600,
                  fontStyle: muted ? FontStyle.italic : FontStyle.normal,
                  color: muted ? scheme.onSurfaceVariant : scheme.onSurface,
                ),
              ),
            ),
            if (onClear != null)
              IconButton(
                onPressed: onClear,
                icon: const Icon(Icons.close_rounded),
                iconSize: OmniIconSize.md,
                tooltip: 'Xoá $label',
              )
            else
              Icon(
                Icons.chevron_right_rounded,
                size: OmniIconSize.md,
                color: scheme.onSurfaceVariant,
              ),
          ],
        ),
      ),
    );
  }
}
