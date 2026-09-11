import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../design/tokens/tokens.dart';
import '../../application/task_controller.dart';
import '../../domain/mention.dart';
import '../../domain/task.dart';

/// Trao đổi trên một công việc.
///
/// §B3: QC không đạt thì "@mention người phụ trách công đoạn lỗi, kéo về Đang
/// phục chế". Đây là chỗ duy nhất trong cả luồng ghi lại LÝ DO một cây bị trả
/// về — nhật ký hoạt động chỉ biết nó đã chuyển cột, không biết vì sao.
///
/// Cho tới giờ app không có màn hình nào cho việc này, nên người thợ bị trả
/// việc về mà không đọc được lời giải thích ở đâu, trừ khi mở máy tính. Ở
/// xưởng thì không ai mở máy tính.
///
/// Đặt DƯỚI danh sách công đoạn: người thợ mở việc ra để tick, không phải để
/// đọc. Nhưng vẫn nằm trên màn chi tiết chứ không giấu sau một nút — một lời
/// giải thích không ai thấy thì bằng không có.
class CommentSection extends ConsumerStatefulWidget {
  const CommentSection({
    super.key,
    required this.task,
    required this.taskId,
    required this.canWrite,
  });

  final Task task;
  final String taskId;
  final bool canWrite;

  @override
  ConsumerState<CommentSection> createState() => _CommentSectionState();
}

class _CommentSectionState extends ConsumerState<CommentSection> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  bool _sending = false;

  /// Đoạn `@…` đang gõ ngay trước con trỏ; null khi không gõ nhắc ai.
  String? _query;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTyped);
  }

  void _onTyped() {
    final sel = _controller.selection;
    final cursor = sel.isValid ? sel.baseOffset : _controller.text.length;
    final next = Mentions.queryAt(_controller.text, cursor);
    if (next != _query) setState(() => _query = next);
  }

  /// Thay đoạn `@…` đang gõ bằng `@Tên `, giữ bàn phím mở để gõ tiếp.
  void _pick(String name) {
    final sel = _controller.selection;
    final cursor = sel.isValid ? sel.baseOffset : _controller.text.length;
    final r = Mentions.insert(_controller.text, cursor, name);
    _controller.value = TextEditingValue(
      text: r.text,
      selection: TextSelection.collapsed(offset: r.cursor),
    );
    _focus.requestFocus();
  }

  /// Nút `@` cho người không biết quy ước: chèn `@` tại con trỏ và mở gợi ý.
  void _startMention() {
    final text = _controller.text;
    final sel = _controller.selection;
    final cursor = (sel.isValid ? sel.baseOffset : text.length).clamp(
      0,
      text.length,
    );
    final lead = cursor > 0 && text[cursor - 1].trim().isNotEmpty ? ' ' : '';
    final out = text.replaceRange(cursor, cursor, '$lead@');
    _controller.value = TextEditingValue(
      text: out,
      selection: TextSelection.collapsed(offset: cursor + lead.length + 1),
    );
    _focus.requestFocus();
  }

  /// Ai có thể bị nhắc: người của việc và người của từng công đoạn.
  ///
  /// Lấy từ chính công việc đang mở, KHÔNG gọi danh sách nhân sự: vai thợ cố ý
  /// không có quyền đó, nên một bộ chọn dựa vào /team sẽ rỗng đúng trong tay
  /// người hay phải trả việc về nhất. Đây cũng là cách duy nhất không viết
  /// cứng cho một loại việc nào — công đoạn nào cũng có người phụ trách.
  Map<String, String> get _candidates {
    final out = <String, String>{};
    final ids = widget.task.assigneeIds;
    final names = widget.task.assigneeNames;
    for (var i = 0; i < ids.length; i++) {
      final name = i < names.length ? names[i].trim() : '';
      if (name.isNotEmpty) out[ids[i]] = name;
    }
    for (final step in widget.task.subtasks) {
      final id = step.assigneeId ?? '';
      final name = (step.assigneeName ?? '').trim();
      if (id.isNotEmpty && name.isNotEmpty) out[id] = name;
    }

    return out;
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final body = _controller.text.trim();
    if (body.isEmpty) return;

    final messenger = ScaffoldMessenger.of(context);
    setState(() => _sending = true);
    try {
      await ref
          .read(taskDetailProvider(widget.taskId).notifier)
          .comment(
            body,
            // Đọc lại từ CHỮ lúc gửi: xoá `@Tên` khỏi câu là hết nhắc. Không có
            // trạng thái ngầm nào để lệch với cái đang nhìn thấy.
            mentionedUserIds: Mentions.idsIn(body, _candidates),
          );
      // Xoá ô nhập CHỈ khi server đã nhận. Xoá trước rồi lỗi mạng là mất chữ
      // người ta vừa gõ, và ở đây chữ đó là lý do một cây đàn bị trả về.
      if (mounted) _controller.clear();
    } on AppException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } on Object {
      messenger.showSnackBar(
        const SnackBar(content: Text('Chưa gửi được. Thử lại khi có mạng.')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final comments = widget.task.comments;

    // Không đọc được mà cũng không viết được thì đừng chiếm chỗ.
    if (comments.isEmpty && !widget.canWrite) return const SizedBox.shrink();

    // API cắt bớt phần cũ; `commentCount` mới là tổng thật.
    final hidden = widget.task.commentCount - comments.length;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: OmniSpacing.sm),
      color: scheme.surface,
      padding: const EdgeInsets.all(OmniSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.forum_outlined,
                size: OmniIconSize.sm,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: OmniSpacing.xs),
              Text(
                'Trao đổi',
                style: OmniType.overline.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          if (hidden > 0) ...[
            const SizedBox(height: OmniSpacing.sm),
            Text(
              'Còn $hidden bình luận cũ hơn, xem trên web.',
              style: text.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
          for (final comment in comments) ...[
            const SizedBox(height: OmniSpacing.md),
            _Comment(comment: comment),
          ],
          if (widget.canWrite) ...[
            const SizedBox(height: OmniSpacing.lg),
            // §B3: QC trượt thì phải nhắc tên người phụ trách công đoạn lỗi.
            // Gõ `@` là ra gợi ý — quy ước mọi app trao đổi đều dùng — và
            // chọn thì `@Tên` nằm ngay trong câu. Gõ tên trơn chỉ ra một chuỗi
            // chữ; `@Tên` mới thành lời nhắc người kia đọc được ở máy của họ.
            if (_query case final String q)
              if (Mentions.suggest(_candidates, q) case final hits
                  when hits.isNotEmpty) ...[
                Wrap(
                  spacing: OmniSpacing.xs,
                  runSpacing: OmniSpacing.xs,
                  children: [
                    for (final person in hits)
                      ActionChip(
                        key: ValueKey('mention:${person.key}'),
                        label: Text('@${person.value}'),
                        onPressed: _sending ? null : () => _pick(person.value),
                      ),
                  ],
                ),
                const SizedBox(height: OmniSpacing.sm),
              ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    focusNode: _focus,
                    enabled: !_sending,
                    minLines: 1,
                    maxLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      hintText: 'Viết trao đổi… gõ @ để nhắc tên',
                      isDense: true,
                    ),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                if (_candidates.isNotEmpty) ...[
                  const SizedBox(width: OmniSpacing.xs),
                  // Cho người không biết quy ước `@`: bấm là thấy tên để chọn,
                  // như nút @ trên web.
                  IconButton(
                    onPressed: _sending ? null : _startMention,
                    icon: const Icon(Icons.alternate_email_rounded),
                    tooltip: 'Nhắc tên',
                  ),
                ],
                const SizedBox(width: OmniSpacing.xs),
                IconButton.filled(
                  onPressed: _sending ? null : _send,
                  icon: _sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded),
                  tooltip: 'Gửi',
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Comment extends StatelessWidget {
  const _Comment({required this.comment});

  final TaskComment comment;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(comment.author, style: OmniType.bodyStrong),
            const SizedBox(width: OmniSpacing.sm),
            if (comment.createdAt != null)
              Text(
                Formatters.relative(comment.createdAt),
                style: text.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
        const SizedBox(height: OmniSpacing.xs),
        // Màu chữ CHÍNH: `bodyMedium` của theme mang màu phụ, và thân bình
        // luận — lý do một cây đàn bị trả về — từng in mờ hơn cả tên người.
        // `@Tên` được nhắc tô màu chính, ngay trong câu.
        Text.rich(
          TextSpan(
            children: [
              for (final part in Mentions.split(
                comment.body,
                comment.mentionedUserNames,
              ))
                TextSpan(
                  text: part.text,
                  // Style TƯỜNG MINH trên từng đoạn: `Text.rich` bọc span này
                  // vào một span ngoài mang style mặc định (màu phụ), nên
                  // một đoạn không style sẽ thừa kế nhầm màu đó.
                  style: part.isMention
                      ? text.bodyMedium?.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.w600,
                        )
                      : text.bodyMedium?.copyWith(color: scheme.onSurface),
                ),
            ],
          ),
        ),
        // Người thợ không có hộp thư, nên thông báo "bạn được nhắc tên" rơi
        // vào chỗ họ không mở được. Dòng này là kênh DUY NHẤT báo cho họ biết
        // công đoạn của mình là chỗ bị trả về — nhưng chỉ khi tên KHÔNG đã
        // nằm trong câu (bình luận từ web nhắc bằng nút, không có `@` trong
        // chữ). Có `@Tên` rồi mà lặp lại là nói hai lần.
        if (comment.mentionedUserNames.where(
          (n) => !comment.body.contains('@$n'),
        ) case final missing when missing.isNotEmpty) ...[
          const SizedBox(height: OmniSpacing.xs),
          Text(
            'Nhắc: ${missing.join(', ')}',
            style: text.labelSmall?.copyWith(color: scheme.primary),
          ),
        ],
      ],
    );
  }
}
