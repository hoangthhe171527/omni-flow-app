import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../design/tokens/tokens.dart';
import '../../domain/message.dart';

enum ComposeMode { reply, note }

/// Reply box shaped like Zalo's: one flat line of emoji, input, more, image.
///
/// It used to be a raised rounded card carrying a permanent two-button
/// reply/note switch and a row of suggestion chips — three bands of chrome under
/// every conversation. Zalo spends one line, and everything that is not typing
/// lives behind an icon.
///
/// The note mode survived that move, because sending an internal note to a
/// customer is the one mistake on this screen that cannot be undone. It is now
/// chosen in the "more" sheet, and while it is on the composer turns amber and
/// says so — a state you cannot miss beats a toggle you must remember to read.
class MessageComposer extends StatefulWidget {
  const MessageComposer({
    super.key,
    required this.onSend,
    required this.onPickImages,
    this.onTakePhoto,
    this.suggestions = const [],
    this.canNote = true,
    this.enabled = true,
    this.replyTo,
    this.onCancelReply,
  });

  final Future<void> Function(
    String text,
    ComposeMode mode,
    List<XFile> images,
    Message? replyTo,
  )
  onSend;

  /// Picks every image selected from the gallery. Keeping selection in the
  /// composer lets a rep add a caption, remove a mistake, then send one batch.
  final Future<List<XFile>> Function() onPickImages;

  /// Take a photo. Null hides the entry rather than offering a dead button.
  final Future<XFile?> Function()? onTakePhoto;

  final List<String> suggestions;
  final bool canNote;
  final bool enabled;
  final Message? replyTo;
  final VoidCallback? onCancelReply;

  @override
  State<MessageComposer> createState() => _MessageComposerState();
}

class _MessageComposerState extends State<MessageComposer> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  ComposeMode _mode = ComposeMode.reply;
  bool _sending = false;
  final List<XFile> _pendingImages = [];

  @override
  void initState() {
    super.initState();
    // Drives the image↔send swap, so the button reflects what typing did.
    _controller.addListener(_onTextChanged);
  }

  void _onTextChanged() => setState(() {});

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if ((text.isEmpty && _pendingImages.isEmpty) || _sending) return;

    setState(() => _sending = true);
    try {
      await widget.onSend(text, _mode, _pendingImages, widget.replyTo);
      if (!mounted) return;
      setState(() {
        _controller.clear();
        _pendingImages.clear();
      });
    } catch (_) {
      // The upload error is shown by the thread. Keep the caption and tray so
      // the rep can retry instead of selecting every image again.
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _pickImages() async {
    final images = await widget.onPickImages();
    if (!mounted || images.isEmpty) return;
    setState(() => _pendingImages.addAll(images));
  }

  Future<void> _takePhoto() async {
    final image = await widget.onTakePhoto?.call();
    if (!mounted || image == null) return;
    setState(() => _pendingImages.add(image));
  }

  /// Insert at the caret rather than appending: an emoji picked mid-sentence
  /// belongs where the caret is, and appending silently moved it to the end.
  void _insert(String text) {
    final value = _controller.value;
    final selection = value.selection.isValid
        ? value.selection
        : TextSelection.collapsed(offset: value.text.length);
    final next = value.text.replaceRange(selection.start, selection.end, text);

    _controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: selection.start + text.length),
    );
    _focus.requestFocus();
  }

  Future<void> _openEmoji() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (_) => const _EmojiSheet(),
    );
    if (picked != null) _insert(picked);
  }

  Future<void> _openMore() async {
    final action = await showModalBottomSheet<_MoreAction>(
      context: context,
      showDragHandle: true,
      builder: (_) => _MoreSheet(
        mode: _mode,
        canNote: widget.canNote,
        canCamera: widget.onTakePhoto != null,
        suggestions: widget.suggestions,
      ),
    );
    if (action == null || !mounted) return;

    switch (action) {
      case _ModeAction(:final mode):
        if (mode == ComposeMode.note && _pendingImages.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Gửi hoặc bỏ ảnh trước khi tạo ghi chú nội bộ.'),
            ),
          );
          return;
        }
        setState(() => _mode = mode);
        _focus.requestFocus();
      case _CameraAction():
        _takePhoto();
      case _SuggestionAction(:final text):
        _insert(text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isNote = _mode == ComposeMode.note;
    final canSend =
        _controller.text.trim().isNotEmpty || _pendingImages.isNotEmpty;
    final tint = isNote ? OmniColors.warning : OmniColors.chatPrimary;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(
          top: BorderSide(color: scheme.outline.withValues(alpha: 0.5)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.replyTo != null)
              _ReplyPreview(
                message: widget.replyTo!,
                onClose: widget.onCancelReply,
              ),
            // Note mode is a state you cannot miss: a labelled amber strip, not
            // a toggle you have to remember to look at.
            if (isNote)
              Container(
                width: double.infinity,
                color: OmniColors.warning.withValues(alpha: 0.12),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.sticky_note_2_outlined,
                      size: 14,
                      color: OmniColors.warning,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Ghi chú nội bộ — khách KHÔNG nhìn thấy',
                        style: OmniType.micro.copyWith(
                          color: OmniColors.warning,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _mode = ComposeMode.reply),
                      child: Text(
                        'Bỏ',
                        style: OmniType.micro.copyWith(
                          color: OmniColors.warning,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (_pendingImages.isNotEmpty)
              _ImageTray(
                images: _pendingImages,
                onRemove: (image) =>
                    setState(() => _pendingImages.remove(image)),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 6, 4, 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _ComposerIcon(
                    icon: Icons.emoji_emotions_outlined,
                    tooltip: 'Biểu tượng cảm xúc',
                    onTap: widget.enabled ? _openEmoji : null,
                  ),
                  Expanded(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 120),
                      child: TextField(
                        controller: _controller,
                        focusNode: _focus,
                        enabled: widget.enabled,
                        minLines: 1,
                        maxLines: null,
                        textCapitalization: TextCapitalization.sentences,
                        style: OmniType.body.copyWith(
                          fontSize: 15,
                          color: scheme.onSurface,
                        ),
                        decoration: InputDecoration(
                          hintText: isNote ? 'Ghi chú nội bộ…' : 'Tin nhắn',
                          hintStyle: OmniType.body.copyWith(
                            fontSize: 15,
                            color: scheme.onSurfaceVariant,
                          ),
                          isDense: true,
                          filled: false,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 10,
                          ),
                        ),
                        onSubmitted: (_) => _send(),
                      ),
                    ),
                  ),
                  if (!isNote)
                    _ComposerIcon(
                      icon: Icons.image_outlined,
                      tooltip: 'Thêm ảnh',
                      onTap: widget.enabled && !_sending ? _pickImages : null,
                    ),
                  _ComposerIcon(
                    icon: Icons.more_horiz_rounded,
                    tooltip: 'Thêm',
                    onTap: widget.enabled ? _openMore : null,
                  ),
                  // Zalo swaps the trailing icon for send the moment there is
                  // something to send, so the primary action is never a second
                  // button competing for the same corner.
                  if (canSend || _sending)
                    _SendButton(
                      sending: _sending,
                      tint: tint,
                      onTap: widget.enabled ? _send : null,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReplyPreview extends StatelessWidget {
  const _ReplyPreview({required this.message, this.onClose});

  final Message message;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final author = message.isOutbound
        ? 'Bạn'
        : (message.senderName ?? 'Khách hàng');
    final preview = message.text.trim().isEmpty
        ? (message.hasAttachments ? 'Tệp đính kèm' : 'Tin nhắn')
        : message.text.trim();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        border: Border(
          left: BorderSide(color: OmniColors.chatPrimary, width: 3),
          bottom: BorderSide(color: scheme.outline.withValues(alpha: 0.4)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Đang trả lời $author',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: OmniType.micro.copyWith(
                    color: OmniColors.chatPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  preview,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: OmniType.caption.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Hủy trả lời',
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded, size: 20),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

class _ComposerIcon extends StatelessWidget {
  const _ComposerIcon({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return IconButton(
      onPressed: onTap,
      tooltip: tooltip,
      // 44 keeps every icon past the touch minimum even though it reads small.
      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      icon: Icon(icon, size: 24, color: scheme.onSurfaceVariant),
    );
  }
}

class _ImageTray extends StatelessWidget {
  const _ImageTray({required this.images, required this.onRemove});

  final List<XFile> images;
  final ValueChanged<XFile> onRemove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      height: 86,
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        border: Border(
          bottom: BorderSide(color: scheme.outline.withValues(alpha: 0.42)),
        ),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: images.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final image = images[index];
          return Stack(
            clipBehavior: Clip.none,
            children: [
              ClipRRect(
                borderRadius: OmniRadius.smAll,
                child: Image.file(
                  File(image.path),
                  width: 68,
                  height: 68,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    width: 68,
                    height: 68,
                    color: scheme.surfaceContainerHighest,
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: -6,
                right: -6,
                child: Material(
                  color: scheme.inverseSurface,
                  shape: const CircleBorder(),
                  child: InkWell(
                    onTap: () => onRemove(image),
                    customBorder: const CircleBorder(),
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: Icon(
                        Icons.close_rounded,
                        size: 15,
                        color: scheme.onInverseSurface,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({
    required this.sending,
    required this.tint,
    required this.onTap,
  });

  final bool sending;
  final Color tint;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 2),
      child: SizedBox(
        width: 40,
        height: 40,
        child: FilledButton(
          onPressed: sending ? null : onTap,
          style: FilledButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
            backgroundColor: tint,
            shape: const CircleBorder(),
          ),
          child: sending
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.send_rounded, size: 18, color: Colors.white),
        ),
      ),
    );
  }
}

/// Emoji grid.
///
/// A hand-picked set rather than a dependency: these are the ones a sales rep
/// actually sends, they render from the system font on every platform, and the
/// sheet stays instant with nothing to download or index.
class _EmojiSheet extends StatelessWidget {
  const _EmojiSheet();

  static const _emojis = <String>[
    '😀',
    '😁',
    '😂',
    '🤣',
    '😊',
    '😍',
    '🥰',
    '😘',
    '😉',
    '😌',
    '😎',
    '🤗',
    '🤔',
    '😅',
    '😇',
    '🙂',
    '😢',
    '😭',
    '😤',
    '😱',
    '😴',
    '🥳',
    '😋',
    '🤝',
    '👍',
    '👎',
    '👏',
    '🙏',
    '💪',
    '✌️',
    '👌',
    '🤞',
    '❤️',
    '💛',
    '💚',
    '💙',
    '💜',
    '🔥',
    '✨',
    '⭐',
    '🎉',
    '🎁',
    '💰',
    '💳',
    '🛒',
    '📦',
    '🚚',
    '📞',
    '✅',
    '❌',
    '⚠️',
    '❓',
    '❗',
    '⏰',
    '📅',
    '📝',
    '🎹',
    '🎵',
    '🎶',
    '🏠',
    '🚗',
    '☕',
    '🌸',
    '🌟',
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          OmniSpacing.md,
          0,
          OmniSpacing.md,
          OmniSpacing.md,
        ),
        child: GridView.builder(
          shrinkWrap: true,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 8,
          ),
          itemCount: _emojis.length,
          itemBuilder: (context, index) => InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              Navigator.pop(context, _emojis[index]);
            },
            borderRadius: OmniRadius.smAll,
            child: Center(
              child: Text(_emojis[index], style: const TextStyle(fontSize: 26)),
            ),
          ),
        ),
      ),
    );
  }
}

sealed class _MoreAction {
  const _MoreAction();
}

class _ModeAction extends _MoreAction {
  const _ModeAction(this.mode);
  final ComposeMode mode;
}

class _CameraAction extends _MoreAction {
  const _CameraAction();
}

class _SuggestionAction extends _MoreAction {
  const _SuggestionAction(this.text);
  final String text;
}

/// Everything the composer no longer keeps on screen permanently.
class _MoreSheet extends StatelessWidget {
  const _MoreSheet({
    required this.mode,
    required this.canNote,
    required this.canCamera,
    required this.suggestions,
  });

  final ComposeMode mode;
  final bool canNote;
  final bool canCamera;
  final List<String> suggestions;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isNote = mode == ComposeMode.note;

    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (canCamera)
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Chụp ảnh'),
                onTap: () => Navigator.pop(context, const _CameraAction()),
              ),
            if (canNote)
              ListTile(
                leading: Icon(
                  Icons.sticky_note_2_outlined,
                  color: isNote ? OmniColors.warning : null,
                ),
                title: Text(
                  isNote ? 'Chuyển về trả lời khách' : 'Ghi chú nội bộ',
                ),
                subtitle: Text(
                  isNote
                      ? 'Tin sẽ được gửi cho khách'
                      : 'Chỉ đồng nghiệp nhìn thấy, khách không',
                  style: OmniType.micro.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                onTap: () => Navigator.pop(
                  context,
                  _ModeAction(isNote ? ComposeMode.reply : ComposeMode.note),
                ),
              ),
            if (suggestions.isNotEmpty) ...[
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  OmniSpacing.lg,
                  OmniSpacing.md,
                  OmniSpacing.lg,
                  OmniSpacing.sm,
                ),
                child: Text('Câu trả lời nhanh', style: OmniType.bodyStrong),
              ),
              for (final suggestion in suggestions)
                ListTile(
                  dense: true,
                  title: Text(suggestion, style: OmniType.caption),
                  onTap: () =>
                      Navigator.pop(context, _SuggestionAction(suggestion)),
                ),
            ],
            const SizedBox(height: OmniSpacing.md),
          ],
        ),
      ),
    );
  }
}
