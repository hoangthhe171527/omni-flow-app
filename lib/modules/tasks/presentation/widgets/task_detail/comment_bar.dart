import 'dart:io';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../../core/error/app_exception.dart';
import '../../../../../design/tokens/tokens.dart';
import '../../../application/task_controller.dart';
import '../../../domain/mention.dart';
import '../../../domain/task.dart';
import '../../../domain/task_reminder.dart';
import 'menu_sheet.dart';

/// Nguồn tệp cho bình luận.
enum CommentFileSource { camera, gallery, files }

/// Chọn tối đa [remaining] tệp từ [source]; rỗng = huỷ.
typedef CommentFilePicker =
    Future<List<CommentUpload>> Function(
      CommentFileSource source,
      int remaining,
    );

/// Mười tệp mỗi bình luận (`CreateTaskCommentRequest::MAX_ATTACHMENTS`).
const kCommentMaxFiles = 10;

/// 25MB mỗi tệp (`TaskUploads::fileRules` `max:25600`).
const kCommentMaxFileBytes = 25 * 1024 * 1024;

/// 64MB cả lượt gửi (`post_max_size`, DEPLOY.md).
const kCommentMaxTotalBytes = 64 * 1024 * 1024;

/// Bộ chọn thật: `image_picker` cho ảnh (nén ≤2048px, 85), `file_picker`
/// cho tài liệu. Hệ điều hành từ chối thì ném [NetworkException] có câu.
Future<List<CommentUpload>> pickCommentFiles(
  CommentFileSource source,
  int remaining,
) async {
  if (remaining <= 0) return const [];
  final picker = ImagePicker();
  Future<CommentUpload> image(XFile x) async {
    int? size;
    try {
      size = await x.length();
    } on Object {
      size = null;
    }
    return CommentUpload(path: x.path, name: x.name, isImage: true, size: size);
  }

  try {
    switch (source) {
      case CommentFileSource.camera:
        final x = await picker.pickImage(
          source: ImageSource.camera,
          imageQuality: 85,
          maxWidth: 2048,
          maxHeight: 2048,
        );
        return x == null ? const [] : [await image(x)];
      case CommentFileSource.gallery:
        final picked = remaining == 1
            ? [
                ?await picker.pickImage(
                  source: ImageSource.gallery,
                  imageQuality: 85,
                  maxWidth: 2048,
                  maxHeight: 2048,
                ),
              ]
            : await picker.pickMultiImage(
                imageQuality: 85,
                maxWidth: 2048,
                maxHeight: 2048,
                limit: remaining,
              );
        return [for (final x in picked) await image(x)];
      case CommentFileSource.files:
        final result = await FilePicker.pickFiles(allowMultiple: true);
        return [
          for (final f in result?.files ?? const <PlatformFile>[])
            if (f.path != null)
              CommentUpload(
                path: f.path!,
                name: f.name,
                isImage: false,
                size: f.size,
              ),
        ];
    }
  } on PlatformException {
    throw const NetworkException(
      'Không mở được trình chọn — kiểm tra quyền ảnh / máy ảnh trong Cài đặt.',
      code: 'picker_unavailable',
    );
  }
}

/// Ô bình luận cố định ở đáy chi tiết việc (`TaskDetail.dc.html` `footer`):
/// nền sáng .82 (không blur), ô nhập bo tròn nền `#EEF1F5` chữ 15
/// "Bình luận, @ để nhắc tên", nút gửi 44 màu chính.
///
/// Gõ `@` thì hiện gợi ý tên ngay trên thanh; chọn thì `@Tên` nằm trong câu.
/// Khi gửi, id người được nhắc đọc lại từ CHỮ (`Mentions.idsIn`): xoá `@Tên`
/// khỏi câu là hết nhắc.
///
/// Nút ảnh 44 (Nhóm 2, [canAttachFiles]): chụp / chọn ảnh / chọn tệp, xem
/// trước có × bỏ từng tệp, gửi CÙNG bình luận (multipart `files[]`, ≤10 tệp,
/// mỗi tệp ≤25MB, cả lượt ≤64MB); có tệp thì thân rỗng vẫn gửi được. Mặt
/// cười của bản mẫu chỉ trang trí nên cũng không vẽ; chỗ đó là nút `@` (năng
/// lực cũ của ô trao đổi).
class CommentBar extends ConsumerStatefulWidget {
  const CommentBar({
    super.key,
    required this.task,
    required this.taskId,
    this.canAttachFiles = false,
    this.pickFiles = pickCommentFiles,
  });

  final Task task;
  final String taskId;

  /// Phiên khai `tasks.comment_attachments`: nút ảnh 44 và xem trước tệp.
  final bool canAttachFiles;

  /// Chọn tệp; tiêm được để test không gọi plugin.
  final CommentFilePicker pickFiles;

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

  /// Tệp đã chọn, chờ gửi cùng bình luận.
  final _files = <CommentUpload>[];

  /// Nút ảnh: chọn nguồn, rồi thêm tệp trong giới hạn (10 tệp, 25MB / tệp,
  /// 64MB cả lượt). Tệp vượt bị bỏ kèm một câu báo.
  Future<void> _attach() async {
    final messenger = ScaffoldMessenger.of(context);
    final remaining = kCommentMaxFiles - _files.length;
    if (remaining <= 0) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Tối đa 10 tệp mỗi bình luận.')),
      );
      return;
    }
    final source = await showDetailMenuSheet<CommentFileSource>(
      context,
      semanticsLabel: 'Đính kèm vào bình luận',
      groups: const [
        [
          DetailMenuItem(
            value: CommentFileSource.camera,
            icon: Icons.photo_camera_outlined,
            label: 'Chụp ảnh',
          ),
          DetailMenuItem(
            value: CommentFileSource.gallery,
            icon: Icons.photo_library_outlined,
            label: 'Chọn ảnh có sẵn',
          ),
          DetailMenuItem(
            value: CommentFileSource.files,
            icon: Icons.insert_drive_file_outlined,
            label: 'Chọn tệp',
          ),
        ],
      ],
    );
    if (source == null) return;

    final List<CommentUpload> picked;
    try {
      picked = await widget.pickFiles(source, remaining);
    } on AppException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
      return;
    }
    if (picked.isEmpty || !mounted) return;

    var total = _files.fold<int>(0, (sum, f) => sum + (f.size ?? 0));
    final accepted = <CommentUpload>[];
    String? refused;
    for (final f in picked) {
      final size = f.size ?? 0;
      if (_files.length + accepted.length >= kCommentMaxFiles) {
        refused = 'Tối đa 10 tệp mỗi bình luận.';
      } else if (size > kCommentMaxFileBytes) {
        refused = '“${f.name}” lớn hơn 25MB.';
      } else if (total + size > kCommentMaxTotalBytes) {
        refused = 'Cả lượt gửi tối đa 64MB.';
      } else {
        total += size;
        accepted.add(f);
      }
    }
    setState(() => _files.addAll(accepted));
    if (refused != null) {
      messenger.showSnackBar(SnackBar(content: Text(refused)));
    }
  }

  Future<void> _send() async {
    final body = _controller.text.trim();
    final files = List<CommentUpload>.of(_files);
    if ((body.isEmpty && files.isEmpty) || _sending) return;

    final messenger = ScaffoldMessenger.of(context);
    final controller = ref.read(taskDetailProvider(widget.taskId).notifier);
    final mentions = Mentions.idsIn(body, _candidates);
    setState(() => _sending = true);
    try {
      if (files.isEmpty) {
        await controller.comment(body, mentionedUserIds: mentions);
      } else {
        await controller.commentWithFiles(
          body,
          mentionedUserIds: mentions,
          files: files,
        );
      }
      // Xoá ô nhập CHỈ khi server đã nhận: chữ đó là lý do một cây bị trả về.
      if (mounted) {
        _controller.clear();
        setState(_files.clear);
      }
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
            if (_files.isNotEmpty)
              SizedBox(
                key: const ValueKey('comment-files-preview'),
                height: 76,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(6, 4, 6, 8),
                  itemCount: _files.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 4),
                  itemBuilder: (context, i) => _Preview(
                    file: _files[i],
                    onRemove: _sending
                        ? null
                        : () => setState(() => _files.removeAt(i)),
                  ),
                ),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (widget.canAttachFiles)
                  IconButton(
                    tooltip: 'Đính kèm ảnh hoặc tệp',
                    onPressed: _sending ? null : _attach,
                    style: IconButton.styleFrom(
                      minimumSize: const Size(44, 44),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      maximumSize: const Size(44, 44),
                      padding: EdgeInsets.zero,
                      foregroundColor: secondary,
                    ),
                    icon: const Icon(Icons.image_outlined, size: 22),
                  )
                else
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
                    final enabled =
                        !_sending &&
                        (value.text.trim().isNotEmpty || _files.isNotEmpty);

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

/// Ô xem trước 56 của một tệp chờ gửi, × 44 ở góc để bỏ.
class _Preview extends StatelessWidget {
  const _Preview({required this.file, required this.onRemove});

  final CommentUpload file;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final secondary = scheme.onSurfaceVariant;
    Widget fallback() => Padding(
      padding: const EdgeInsets.all(4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.insert_drive_file_outlined, size: 18, color: secondary),
          Text(
            file.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: OmniType.micro.copyWith(color: secondary),
          ),
        ],
      ),
    );

    return SizedBox(
      width: 72,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 8,
            child: Semantics(
              label: 'Tệp đính kèm: ${file.name}',
              excludeSemantics: true,
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                clipBehavior: Clip.antiAlias,
                child: file.isImage
                    ? Image.file(
                        File(file.path),
                        fit: BoxFit.cover,
                        cacheWidth: 168,
                        errorBuilder: (_, _, _) => fallback(),
                      )
                    : fallback(),
              ),
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            child: IconButton(
              tooltip: 'Bỏ ${file.name}',
              onPressed: onRemove,
              style: IconButton.styleFrom(
                minimumSize: const Size(44, 44),
                maximumSize: const Size(44, 44),
                padding: EdgeInsets.zero,
              ),
              icon: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: scheme.onSurface.withValues(alpha: 0.7),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.close_rounded,
                  size: 14,
                  color: scheme.surface,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
