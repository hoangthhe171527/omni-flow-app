import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../../design/components/components.dart';
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
  const CreateTaskArgs({
    this.planId,
    this.sectionId,
    this.order,
    this.sections = const [],
    this.initialTitle,
  });

  final String? planId;
  final String? sectionId;
  final double? order;
  final List<TaskSection> sections;

  /// Tên việc điền sẵn (vd "Liên hệ {khách}" từ hộp thư).
  final String? initialTitle;
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
    this.order,
    this.sections = const [],
    this.initialTitle,
  });

  /// Tên việc điền sẵn.
  final String? initialTitle;

  /// Dự án việc này thuộc về. Null = việc rời, không nằm trên bảng nào.
  final String? planId;

  /// Nhóm việc điền sẵn — cột người dùng đang đứng lúc bấm tạo.
  final String? sectionId;
  final double? order;

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
  void initState() {
    super.initState();
    final initial = widget.initialTitle;
    if (initial != null) _title.text = initial;
  }

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

    // Nền xám, ô tên lớn, một nhóm ba dòng "nhãn — giá trị" và nút "Tạo việc"
    // ghim ở đáy (liquid, đợt 2 duyệt 08/11/2026).
    return Scaffold(
      appBar: OmniAppBar(
        title: 'Việc mới',
        close: true,
        fallbackBack: () => context.go('/tasks'),
      ),
      body: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(16, OmniSpacing.md, 16, 24),
        children: [
          OmniGroupSection(
            dividerIndent: 14,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            'Tên việc',
                            style: OmniType.caption.copyWith(
                              color: scheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          ' *',
                          style: OmniType.caption.copyWith(color: scheme.error),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _title,
                      autofocus: true,
                      textCapitalization: TextCapitalization.sentences,
                      style: OmniType.listTitle.copyWith(
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Việc cần làm là gì?',
                        hintStyle: OmniType.listTitle.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: OmniGroupSection.gap),
          OmniGroupSection(
            dividerIndent: 14,
            children: [
              if (widget.sections.isNotEmpty)
                OmniGroupRow(
                  title: 'Nhóm việc',
                  value: _sectionName,
                  onTap: _pickSection,
                ),
              OmniGroupRow(
                title: 'Người làm',
                value: _assigneeIds.isEmpty
                    ? 'Chưa gán ai'
                    : _assigneeIds
                          .map((id) => names[id]?.name ?? 'Người đã rời')
                          .join(', '),
                onTap: _pickAssignees,
              ),
              OmniGroupRow(
                title: 'Hạn',
                value: _dueDate == null
                    ? 'Chưa đặt hạn'
                    : Formatters.date(_dueDate!),
                onTap: _pickDueDate,
                // Đặt nhầm hạn rồi không gỡ được là một cái bẫy: hạn trống
                // có nghĩa ("chưa hẹn"), khác hẳn một ngày đại khái nào đó.
                trailing: _dueDate == null
                    ? null
                    : IconButton(
                        onPressed: () => setState(() => _dueDate = null),
                        icon: const Icon(Icons.close_rounded),
                        iconSize: OmniIconSize.md,
                        tooltip: 'Xoá Hạn',
                      ),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: OmniGroupSection.gap),
            Text(
              _error!,
              style: text.bodyMedium?.copyWith(
                color: OmniColors.dangerTextOf(context),
              ),
            ),
          ],
        ],
      ),
      bottomNavigationBar: OmniActionBar(
        children: [
          OutlinedButton(
            onPressed: _saving
                ? null
                : () {
                    final nav = Navigator.of(context);
                    if (nav.canPop()) {
                      nav.maybePop();
                    } else {
                      context.go('/tasks');
                    }
                  },
            child: const Text('Huỷ'),
          ),
          FilledButton(
            onPressed: _canSave ? _save : null,
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                  )
                : const Text('Tạo việc'),
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
    final chosen = await showOmniSheet<String>(
      context: context,
      builder: (context) => OmniSheetBody(
        semanticsLabel: 'Nhóm việc',
        header: const OmniSheetHeader(title: 'Nhóm việc'),
        children: [
          OmniGroupSection(
            dividerIndent: 14,
            children: [
              for (final section in widget.sections)
                OmniGroupRow(
                  title: section.name,
                  selected: section.id == _sectionId,
                  chevron: false,
                  onTap: () => Navigator.of(context).pop(section.id),
                ),
            ],
          ),
        ],
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
    final chosen = await pickOmniDate(
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
            // Chỉ giữ vị trí gợi ý khi người dùng không đổi sang nhóm khác.
            order: _sectionId == widget.sectionId ? widget.order : null,
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
