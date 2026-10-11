import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/error/app_exception.dart';
import '../../../../../design/tokens/tokens.dart';
import '../../../application/task_controller.dart';
import '../../../domain/mention.dart';
import '../../../domain/task.dart';

/// Ô bình luận cố định ở đáy chi tiết việc (`TaskDetail.dc.html` `footer`):
/// nền sáng .82 (không blur), ô nhập bo tròn nền `#EEF1F5` chữ 15
/// "Bình luận, @ để nhắc tên", nút gửi 44 màu chính.
///
/// Gõ `@` thì hiện gợi ý tên ngay trên thanh; chọn thì `@Tên` nằm trong câu.
/// Khi gửi, id người được nhắc đọc lại từ CHỮ (`Mentions.idsIn`): xoá `@Tên`
/// khỏi câu là hết nhắc.
///
/// Nhóm 2 (chưa có trên API cũ) KHÔNG vẽ: nút ảnh đính kèm bình luận. Mặt
/// cười của bản mẫu chỉ trang trí nên cũng không vẽ; chỗ đó là nút `@` (năng
/// lực cũ của ô trao đổi).
class CommentBar extends ConsumerStatefulWidget {
  const CommentBar({super.key, required this.task, required this.taskId});

  final Task task;
  final String taskId;

  @override
  ConsumerState<CommentBar> createState() => _CommentBarState();
}

class _CommentBarState extends ConsumerState<CommentBar> {
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

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
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

  /// Ai có thể bị nhắc: người của việc và người của từng công đoạn — lấy từ
  /// chính việc đang mở, KHÔNG gọi danh bạ (vai thợ không có quyền đó).
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

  Future<void> _send() async {
    final body = _controller.text.trim();
    if (body.isEmpty || _sending) return;

    final messenger = ScaffoldMessenger.of(context);
    setState(() => _sending = true);
    try {
      await ref
          .read(taskDetailProvider(widget.taskId).notifier)
          .comment(body, mentionedUserIds: Mentions.idsIn(body, _candidates));
      // Xoá ô nhập CHỈ khi server đã nhận: chữ đó là lý do một cây bị trả về.
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
    final secondary = OmniColors.byBrightness(
      context,
      OmniColors.mutedForeground,
      scheme.onSurfaceVariant,
    );
    // `padding` (đã trừ phần bàn phím che): bàn phím mở thì thanh nằm sát nó.
    final bottom = math.max(8.0, MediaQuery.paddingOf(context).bottom);
    final candidates = _candidates;
    final hits = _query == null
        ? const <MapEntry<String, String>>[]
        : Mentions.suggest(candidates, _query!);

    // Nền .82, KHÔNG blur: một BackdropFilter cố định đáy dựng lại lớp mờ ở
    // mỗi khung cuộn của cả màn (rà soát Task 9).
    return DecoratedBox(
      key: const ValueKey('comment-bar'),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).scaffoldBackgroundColor.withValues(alpha: 0.82),
        border: Border(
          top: BorderSide(color: scheme.onSurface.withValues(alpha: 0.06)),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(8, 6, 8, bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (hits.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
                child: Wrap(
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
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const SizedBox(width: 4),
                Expanded(
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 44),
                    padding: const EdgeInsets.only(left: 14, right: 0),
                    decoration: BoxDecoration(
                      color: OmniColors.trackOf(context),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Row(
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
                            // Enter gửi: `text` chứ không `multiline`.
                            keyboardType: TextInputType.text,
                            textInputAction: TextInputAction.send,
                            style: OmniType.body.copyWith(
                              color: scheme.onSurface,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Bình luận, @ để nhắc tên',
                              hintStyle: OmniType.body.copyWith(
                                color: secondary,
                              ),
                              semanticCounterText: '',
                              isDense: true,
                              filled: false,
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              disabledBorder: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 11,
                              ),
                            ),
                            onSubmitted: (_) => _send(),
                          ),
                        ),
                        if (candidates.isNotEmpty)
                          IconButton(
                            onPressed: _sending ? null : _startMention,
                            icon: const Icon(
                              Icons.alternate_email_rounded,
                              size: OmniIconSize.lg,
                            ),
                            color: secondary,
                            tooltip: 'Nhắc tên',
                            style: IconButton.styleFrom(
                              minimumSize: const Size(44, 44),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              maximumSize: const Size(44, 44),
                              padding: EdgeInsets.zero,
                            ),
                          )
                        else
                          const SizedBox(width: 10),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 2),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _controller,
                  builder: (context, value, _) {
                    final enabled = !_sending && value.text.trim().isNotEmpty;

                    return IconButton(
                      tooltip: 'Gửi bình luận',
                      onPressed: enabled ? _send : null,
                      style: IconButton.styleFrom(
                        minimumSize: const Size(44, 44),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        maximumSize: const Size(44, 44),
                        padding: EdgeInsets.zero,
                        foregroundColor: scheme.primary,
                        disabledForegroundColor: scheme.primary.withValues(
                          alpha: 0.4,
                        ),
                      ),
                      icon: _sending
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send_rounded, size: 22),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
