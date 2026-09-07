import 'package:flutter/material.dart';

import '../../../../design/components/components.dart';
import '../../../../design/tokens/tokens.dart';

/// Ba mức ưu tiên API nhận, kèm nhãn tiếng Việt.
///
/// Nguồn duy nhất cho cả chỗ hiện lẫn chỗ chọn: trước đây bảng điều phối tự
/// dịch `high → Cao` trong hàm riêng của nó, và một bộ chọn viết lại bảng dịch
/// đó là hai danh sách phải nhớ sửa cùng nhau.
const kPriorities = <String, String>{
  'high': 'Cao',
  'med': 'Bình thường',
  'low': 'Thấp',
};

/// Nhãn cho một mức ưu tiên.
///
/// Giá trị lạ hiện NGUYÊN VĂN chứ không rơi về "Bình thường": một dự án thêm
/// mức "khẩn" mà app im lặng hạ nó xuống bình thường là cách một việc gấp bị
/// bỏ quên.
String priorityLabel(String priority) =>
    kPriorities[priority == 'medium' ? 'med' : priority] ?? priority;

Future<String?> showPrioritySheet({
  required BuildContext context,
  required String current,
}) => showOmniSheet<String>(
  context: context,
  builder: (context) => SafeArea(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            OmniSpacing.lg,
            OmniSpacing.sm,
            OmniSpacing.lg,
            OmniSpacing.sm,
          ),
          child: Text(
            'Mức ưu tiên',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        for (final entry in kPriorities.entries)
          ListTile(
            title: Text(entry.value),
            trailing: entry.key == (current == 'medium' ? 'med' : current)
                ? const Icon(Icons.check_rounded)
                : null,
            onTap: () => Navigator.of(context).pop(entry.key),
          ),
      ],
    ),
  ),
);

/// Kết quả của bộ chọn hạn.
///
/// Ba khả năng, và cả ba đều khác nhau: chọn một ngày, xoá hạn, hoặc đóng lại
/// mà không quyết gì. Dùng `DateTime?` một mình thì hai cái sau lẫn vào nhau.
class DueDateChoice {
  const DueDateChoice.on(this.date) : clear = false;
  const DueDateChoice.cleared() : date = null, clear = true;

  final DateTime? date;
  final bool clear;
}

/// Đặt hoặc xoá hạn.
///
/// Chưa có hạn thì mở thẳng lịch — không ai muốn thêm một lần chạm để tới cái
/// duy nhất làm được. Đã có hạn thì hỏi trước, vì lúc đó "xoá" mới là một lựa
/// chọn thật.
Future<DueDateChoice?> showDueDateSheet({
  required BuildContext context,
  required DateTime? current,
  required DateTime firstDate,
  required DateTime lastDate,
}) async {
  Future<DueDateChoice?> pick() async {
    final chosen = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: firstDate,
      lastDate: lastDate,
    );

    return chosen == null ? null : DueDateChoice.on(chosen);
  }

  if (current == null) return pick();

  final action = await showOmniSheet<String>(
    context: context,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.event_outlined),
            title: const Text('Chọn ngày khác'),
            onTap: () => Navigator.of(context).pop('pick'),
          ),
          ListTile(
            leading: const Icon(Icons.event_busy_outlined),
            title: const Text('Xoá hạn'),
            subtitle: const Text('Việc vẫn còn, chỉ là chưa hẹn ngày'),
            onTap: () => Navigator.of(context).pop('clear'),
          ),
        ],
      ),
    ),
  );

  if (action == 'clear') return const DueDateChoice.cleared();
  if (action == 'pick') return pick();

  return null;
}

enum SubtaskAction { rename, remove }

/// Đổi tên hay xoá một việc con.
///
/// Hỏi trước rồi mới mở ô nhập, thay vì để một nút thùng rác cạnh mỗi hàng:
/// hàng việc con là chỗ thợ chạm hàng chục lần một ca với tay bẩn, và một nút
/// xoá nằm ngay đó là một cái bẫy. Ở đây phải cố ý mở ra mới thấy nó.
Future<SubtaskAction?> showSubtaskActionSheet({
  required BuildContext context,
  required String title,
}) => showOmniSheet<SubtaskAction>(
  context: context,
  builder: (context) => SafeArea(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            OmniSpacing.lg,
            OmniSpacing.sm,
            OmniSpacing.lg,
            OmniSpacing.sm,
          ),
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        ListTile(
          leading: const Icon(Icons.edit_outlined),
          title: const Text('Đổi tên'),
          onTap: () => Navigator.of(context).pop(SubtaskAction.rename),
        ),
        ListTile(
          leading: Icon(
            Icons.delete_outline_rounded,
            color: OmniColors.dangerTextOf(context),
          ),
          title: Text(
            'Xoá việc con',
            style: TextStyle(color: OmniColors.dangerTextOf(context)),
          ),
          onTap: () => Navigator.of(context).pop(SubtaskAction.remove),
        ),
      ],
    ),
  ),
);

/// Sửa một đoạn văn bản (tên việc, mô tả).
///
/// Trả về `null` khi người dùng đóng mà không lưu — khác hẳn chuỗi rỗng, vốn
/// là "xoá đi", một lựa chọn hợp lệ với mô tả.
Future<String?> showTextEditSheet({
  required BuildContext context,
  required String title,
  required String initial,
  String? hint,
  bool multiline = false,
  bool allowEmpty = false,
}) => showOmniSheet<String>(
  context: context,
  builder: (context) => _TextEditSheet(
    title: title,
    initial: initial,
    hint: hint,
    multiline: multiline,
    allowEmpty: allowEmpty,
  ),
);

class _TextEditSheet extends StatefulWidget {
  const _TextEditSheet({
    required this.title,
    required this.initial,
    required this.hint,
    required this.multiline,
    required this.allowEmpty,
  });

  final String title;
  final String initial;
  final String? hint;
  final bool multiline;
  final bool allowEmpty;

  @override
  State<_TextEditSheet> createState() => _TextEditSheetState();
}

class _TextEditSheetState extends State<_TextEditSheet> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _canSave {
    final value = _controller.text.trim();
    if (value == widget.initial.trim()) return false;

    return widget.allowEmpty || value.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Chừa chỗ cho bàn phím: không có dòng này thì ô nhập nằm dưới bàn phím
      // và người dùng gõ mù.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          OmniSpacing.lg,
          OmniSpacing.sm,
          OmniSpacing.lg,
          OmniSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: OmniSpacing.md),
            TextField(
              controller: _controller,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              minLines: widget.multiline ? 3 : 1,
              maxLines: widget.multiline ? 8 : 1,
              decoration: InputDecoration(hintText: widget.hint),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: OmniSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                // Tắt khi chưa đổi gì: lưu lại đúng nội dung cũ vẫn chạm
                // updated_at và đẻ ra một dòng nhật ký nói có người sửa.
                onPressed: _canSave
                    ? () => Navigator.of(context).pop(_controller.text.trim())
                    : null,
                child: const Text('Lưu'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
