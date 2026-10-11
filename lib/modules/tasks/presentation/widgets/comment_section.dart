import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../design/components/components.dart';
import '../../../../design/tokens/tokens.dart';
import '../../application/task_comments_controller.dart';
import '../../application/task_controller.dart';
import '../../domain/mention.dart';
import '../../domain/task.dart';
import 'task_detail/section_title.dart';
import 'task_detail/task_viewers.dart';

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

  /// Xin trang cũ hơn. Lỗi hiện ra, không im lặng: bấm mà không thấy gì xảy
  /// ra là kiểu hỏng đã lặp lại nhiều lần ở dự án này.
  Future<void> _loadOlder() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(taskCommentsProvider(widget.taskId).notifier).loadOlder();
    } on AppException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } on Object {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Chưa tải được bình luận cũ. Thử lại khi có mạng.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Hạt giống là `task.comments`; provider cộng thêm những trang cũ đã xin.
    // Nó giữ mới nhất trước (thứ tự API); lật lại để đọc như trò chuyện: cũ
    // nhất trên, mới nhất dưới.
    final thread = ref.watch(taskCommentsProvider(widget.taskId)).valueOrNull;
    // Chưa gieo hạt (chi tiết còn đang tải) thì vẽ từ Task đang cầm, không vẽ
    // một danh sách trống rồi nháy sang có.
    final ready = thread != null && thread.seeded;
    final comments = ready
        ? thread.items.reversed.toList()
        : widget.task.comments;
    final viewers = widget.task.viewers;

    // Không đọc được mà cũng không viết được thì đừng chiếm chỗ — trừ dải
    // "Đã xem", vốn trước đây là một khối riêng và không được mất theo.
    if (comments.isEmpty && !widget.canWrite) {
      if (viewers.isEmpty) return const SizedBox.shrink();

      return Align(
        alignment: Alignment.centerRight,
        child: TaskViewers(viewers: viewers, compact: true),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(child: DetailSectionTitle('TRAO ĐỔI')),
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: TaskViewers(viewers: viewers, compact: true),
            ),
          ],
        ),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: scheme.outlineVariant),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Phần cũ đọc được NGAY ĐÂY. Bản trước viết "xem trên web" — ở
              // xưởng không ai mở web, và lý do một cây bị trả về ba tuần
              // trước nằm đúng trong phần bị cắt.
              if (ready && thread.hasMore)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: thread.loadingOlder ? null : _loadOlder,
                    icon: thread.loadingOlder
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.history_rounded),
                    label: Text(
                      'Xem thêm ${thread.hiddenCount} bình luận cũ hơn',
                    ),
                  ),
                ),
              for (final comment in comments)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: _Comment(comment: comment),
                ),
              if (widget.canWrite) ...[
                // §B3: QC trượt thì phải nhắc tên người phụ trách công đoạn
                // lỗi. Gõ `@` là ra gợi ý — quy ước mọi app trao đổi đều dùng
                // — và chọn thì `@Tên` nằm ngay trong câu. Gõ tên trơn chỉ ra
                // một chuỗi chữ; `@Tên` mới thành lời nhắc người kia đọc được
                // ở máy của họ.
                if (_query case final String q)
                  if (Mentions.suggest(_candidates, q) case final hits
                      when hits.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Wrap(
                        spacing: OmniSpacing.xs,
                        runSpacing: OmniSpacing.xs,
                        children: [
                          for (final person in hits)
                            ActionChip(
                              key: ValueKey('mention:${person.key}'),
                              label: Text('@${person.value}'),
                              onPressed: _sending
                                  ? null
                                  : () => _pick(person.value),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: OmniSpacing.sm),
                  ],
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: _composer(context),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// Ô nhập bo 17 cao ≥ 44 nền xám nhạt + nút "Gửi" bo 17.
  Widget _composer(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
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
            // Enter gửi: `text` chứ không phải `multiline` (mặc định khi
            // maxLines > 1), vì multiline biến Enter thành xuống dòng và
            // `onSubmitted` không bao giờ chạy. Chữ dài vẫn tự xuống dòng.
            keyboardType: TextInputType.text,
            textInputAction: TextInputAction.send,
            style: OmniType.caption.copyWith(color: scheme.onSurface),
            decoration: InputDecoration(
              hintText: 'Viết trao đổi… (@ để nhắc tên)',
              isDense: true,
              filled: true,
              fillColor: OmniColors.trackOf(context),
              constraints: const BoxConstraints(minHeight: 44),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(17),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(17),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(17),
                borderSide: BorderSide(color: scheme.primary),
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(17),
                borderSide: BorderSide.none,
              ),
            ),
            onSubmitted: (_) => _send(),
          ),
        ),
        if (_candidates.isNotEmpty) ...[
          const SizedBox(width: OmniSpacing.xs),
          // Cho người không biết quy ước `@`: bấm là thấy tên để chọn, như nút
          // @ trên web.
          IconButton(
            onPressed: _sending ? null : _startMention,
            icon: const Icon(Icons.alternate_email_rounded),
            tooltip: 'Nhắc tên',
            style: IconButton.styleFrom(minimumSize: const Size(44, 44)),
          ),
        ],
        const SizedBox(width: OmniSpacing.xs),
        // Nghe chính ô nhập: nút phải tắt/mở theo chữ, không chỉ theo gợi ý @.
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _controller,
          builder: (context, value, _) {
            final enabled = !_sending && value.text.trim().isNotEmpty;

            return Opacity(
              opacity: enabled || _sending ? 1 : 0.4,
              // Tooltip chỉ để chuột/test tìm được; nhãn đọc to đã là chữ
              // "Gửi" trên nút, không đọc hai lần.
              child: Tooltip(
                message: 'Gửi',
                excludeFromSemantics: true,
                child: FilledButton(
                  onPressed: enabled ? _send : null,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(44, 44),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(17),
                    ),
                  ),
                  child: _sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Gửi'),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _Comment extends StatelessWidget {
  const _Comment({required this.comment});

  final TaskComment comment;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = OmniColors.byBrightness(
      context,
      OmniColors.mutedForeground,
      scheme.onSurfaceVariant,
    );
    // Nội dung 13 cao 1.45. Màu chữ CHÍNH, đặt tường minh: `bodyMedium` của
    // theme mang màu phụ, và thân bình luận — lý do một cây đàn bị trả về —
    // từng in mờ hơn cả tên người.
    final body = OmniType.caption.copyWith(height: 1.45);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // Mặt người trước tên: một chuỗi trao đổi đọc bằng mặt, như mọi
            // app chat. Chưa có ảnh thì OmniAvatar tự vẽ chữ tắt.
            OmniAvatar(
              name: comment.author,
              imageUrl: comment.userAvatar,
              size: 22,
            ),
            const SizedBox(width: OmniSpacing.sm),
            Flexible(
              child: Text(
                comment.author,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: body.copyWith(
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                ),
              ),
            ),
            const SizedBox(width: OmniSpacing.sm),
            if (comment.createdAt != null)
              Text(
                Formatters.relative(comment.createdAt),
                style: OmniType.micro.copyWith(color: muted),
              ),
          ],
        ),
        const SizedBox(height: OmniSpacing.xs),
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
                  // vào một span ngoài mang style mặc định (màu phụ), nên một
                  // đoạn không style sẽ thừa kế nhầm màu đó.
                  style: part.isMention
                      ? body.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.w600,
                        )
                      : body.copyWith(color: scheme.onSurface),
                ),
            ],
          ),
        ),
        // Người thợ không có hộp thư, nên thông báo "bạn được nhắc tên" rơi
        // vào chỗ họ không mở được. Dòng này là kênh DUY NHẤT báo cho họ biết
        // công đoạn của mình là chỗ bị trả về — nhưng chỉ khi tên KHÔNG đã nằm
        // trong câu (bình luận từ web nhắc bằng nút, không có `@` trong chữ).
        // Có `@Tên` rồi mà lặp lại là nói hai lần.
        if (comment.mentionedUserNames.where(
              (n) => !comment.body.contains('@$n'),
            )
            case final missing when missing.isNotEmpty) ...[
          const SizedBox(height: OmniSpacing.xs),
          Text(
            'Nhắc: ${missing.join(', ')}',
            style: OmniType.micro.copyWith(color: scheme.primary),
          ),
        ],
      ],
    );
  }
}
