import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../design/platform/omni_motion_scope.dart';
import '../../../../design/tokens/tokens.dart';
import '../../domain/message.dart';

/// Thanh nhập kiểu Messenger (`Thread.dc.html`): một hàng gồm cụm công cụ
/// (`+`, chụp ảnh, ảnh), ô nhập bo tròn có mặt cười, và nút cuối.
///
/// Nút cuối là 👍 khi ô trống (gửi đúng một tin 👍) và đổi thành nút Gửi ngay
/// khi có chữ hoặc ảnh. Khi gõ, cụm công cụ thu về 0 và để lại `›` để bung lại.
/// `+` mở khay bốn cột chỉ chứa những việc máy chủ thật sự hỗ trợ.
///
/// Không có chế độ ghi chú nội bộ: gửi nhầm ghi chú cho khách là lỗi không thu
/// hồi được, nên composer này chỉ có một việc là trả lời khách.
class MessageComposer extends StatefulWidget {
  const MessageComposer({
    super.key,
    required this.onSend,
    required this.onPickImages,
    this.onTakePhoto,
    this.onCreateTask,
    this.loadTemplates,
    this.enabled = true,
    this.replyTo,
    this.onCancelReply,
  });

  final Future<void> Function(String text, List<XFile> images, Message? replyTo)
  onSend;

  /// Picks every image selected from the gallery. Keeping selection in the
  /// composer lets a rep add a caption, remove a mistake, then send one batch.
  final Future<List<XFile>> Function() onPickImages;

  /// Take a photo. Null hides the entry rather than offering a dead button.
  final Future<XFile?> Function()? onTakePhoto;

  /// Mở màn tạo việc. Null ẩn mục "Tạo việc" trong khay (không đủ quyền).
  final VoidCallback? onCreateTask;

  /// Nạp danh sách mẫu trả lời. Null ẩn mục "Mẫu trả lời".
  final Future<List<String>> Function()? loadTemplates;

  final bool enabled;
  final Message? replyTo;
  final VoidCallback? onCancelReply;

  @override
  State<MessageComposer> createState() => _MessageComposerState();
}

const _likeText = '👍';
const _toolWidth = 44.0;
const _slowMotion = Duration(milliseconds: 350);

class _MessageComposerState extends State<MessageComposer> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  bool _sending = false;
  bool _trayOpen = false;
  bool _toolsForced = false;
  bool _loadingTemplates = false;
  final List<XFile> _pendingImages = [];

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
    _focus.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _focus.removeListener(_onFocusChanged);
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// Gõ chữ là bỏ qua khay: ô nhập lấy tiêu điểm thì đóng khay `+`.
  void _onFocusChanged() {
    if (_focus.hasFocus && _trayOpen) setState(() => _trayOpen = false);
  }

  @override
  void didUpdateWidget(MessageComposer old) {
    super.didUpdateWidget(old);
    if (!widget.enabled && _trayOpen) _trayOpen = false;
  }

  /// Ô trống trở lại thì cụm công cụ về trạng thái thu/bung mặc định.
  void _onTextChanged() {
    if (_toolsForced && _controller.text.isEmpty) {
      setState(() => _toolsForced = false);
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if ((text.isEmpty && _pendingImages.isEmpty) || _sending) return;
    await _dispatch(text, fromField: true);
  }

  /// Ô trống và không ảnh: gửi 👍 như Messenger.
  Future<void> _sendLike() async {
    if (_sending) return;
    await _dispatch(_likeText);
  }

  Future<void> _dispatch(String text, {bool fromField = false}) async {
    setState(() => _sending = true);
    try {
      await widget.onSend(text, _pendingImages, widget.replyTo);
      if (!mounted) return;
      setState(() {
        if (fromField) _controller.clear();
        _pendingImages.clear();
        _toolsForced = false;
        _trayOpen = false;
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
    if (picked != null && mounted) _insert(picked);
  }

  /// Mẫu trả lời: chọn là chèn vào ô, KHÔNG gửi — người bán thường sửa một chữ.
  Future<void> _openTemplates() async {
    final load = widget.loadTemplates;
    if (load == null || _loadingTemplates) return;
    _loadingTemplates = true;
    List<String> templates;
    try {
      templates = await load();
    } catch (_) {
      templates = const [];
    }
    _loadingTemplates = false;
    if (!mounted) return;

    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _TemplateSheet(templates: templates),
    );
    if (picked == null || !mounted) return;
    setState(() => _trayOpen = false);
    _insert(picked);
  }

  List<Widget> _tools() => [
    _ComposerIcon(
      icon: Icons.add_circle_rounded,
      tooltip: 'Thêm',
      rotated: _trayOpen,
      onTap: widget.enabled
          ? () => setState(() => _trayOpen = !_trayOpen)
          : null,
    ),
    if (widget.onTakePhoto != null)
      _ComposerIcon(
        icon: Icons.photo_camera_rounded,
        tooltip: 'Chụp ảnh',
        onTap: widget.enabled && !_sending ? _takePhoto : null,
      ),
    _ComposerIcon(
      icon: Icons.image_rounded,
      tooltip: 'Ảnh',
      onTap: widget.enabled && !_sending ? _pickImages : null,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final motion = OmniMotion.enabled(context);
    final duration = motion ? _slowMotion : Duration.zero;
    final toolsWidth = _toolWidth * (widget.onTakePhoto != null ? 3 : 2);
    final fieldFill = OmniColors.byBrightness(
      context,
      const Color(0xFFEEF1F5),
      scheme.surfaceContainerHighest,
    );
    final tray = _trayOpen && widget.enabled
        ? _Tray(
            onCreateTask: widget.onCreateTask == null
                ? null
                : () {
                    setState(() => _trayOpen = false);
                    widget.onCreateTask!();
                  },
            onTemplates: widget.loadTemplates == null ? null : _openTemplates,
          )
        : const SizedBox(width: double.infinity);
    const border = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(18)),
      borderSide: BorderSide.none,
    );

    // Lớp vẽ riêng: gõ phím, nháy con trỏ, đổi nút gửi — chỉ composer raster
    // lại, danh sách tin nhắn và nền phía trên nó thì không.
    return RepaintBoundary(
      child: Container(
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
              if (_pendingImages.isNotEmpty)
                _ImageTray(
                  images: _pendingImages,
                  onRemove: (image) =>
                      setState(() => _pendingImages.remove(image)),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Chỉ cụm công cụ và cụm nút cuối nghe controller. Trước đây
                    // cả composer `setState` theo từng ký tự — dựng lại ô nhập
                    // và khay ảnh cho một phím gõ.
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _controller,
                      builder: (context, value, _) {
                        final typing = value.text.isNotEmpty;
                        final collapsed = typing && !_toolsForced;
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ExcludeFocus(
                              excluding: collapsed,
                              child: ExcludeSemantics(
                                excluding: collapsed,
                                child: IgnorePointer(
                                  ignoring: collapsed,
                                  child: AnimatedContainer(
                                    duration: duration,
                                    curve: OmniCurves.standard,
                                    width: collapsed ? 0 : toolsWidth,
                                    height: _toolWidth,
                                    child: ClipRect(
                                      child: OverflowBox(
                                        alignment: Alignment.centerLeft,
                                        minWidth: 0,
                                        maxWidth: toolsWidth,
                                        child: Row(children: _tools()),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            if (collapsed)
                              _ComposerIcon(
                                icon: Icons.chevron_right_rounded,
                                tooltip: 'Hiện công cụ',
                                onTap: () =>
                                    setState(() => _toolsForced = true),
                              ),
                          ],
                        );
                      },
                    ),
                    Expanded(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          minHeight: 44,
                          maxHeight: 120,
                        ),
                        child: TextField(
                          controller: _controller,
                          focusNode: _focus,
                          enabled: widget.enabled,
                          minLines: 1,
                          maxLines: null,
                          textCapitalization: TextCapitalization.sentences,
                          style: OmniType.input.copyWith(
                            color: scheme.onSurface,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Nhắn tin…',
                            hintStyle: OmniType.input.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                            isDense: true,
                            filled: true,
                            fillColor: fieldFill,
                            border: border,
                            enabledBorder: border,
                            focusedBorder: border,
                            disabledBorder: border,
                            contentPadding: const EdgeInsets.fromLTRB(
                              14,
                              8,
                              4,
                              8,
                            ),
                            suffixIconConstraints: const BoxConstraints(
                              minWidth: 44,
                              minHeight: 44,
                            ),
                            suffixIcon: IconButton(
                              onPressed: widget.enabled ? _openEmoji : null,
                              tooltip: 'Biểu tượng cảm xúc',
                              padding: EdgeInsets.zero,
                              style: IconButton.styleFrom(
                                fixedSize: const Size(44, 44),
                                minimumSize: const Size(44, 44),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              icon: Icon(
                                Icons.emoji_emotions_outlined,
                                size: OmniIconSize.xl,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          onSubmitted: (_) => _send(),
                        ),
                      ),
                    ),
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _controller,
                      builder: (context, value, _) {
                        final canSend =
                            value.text.trim().isNotEmpty ||
                            _pendingImages.isNotEmpty;
                        if (canSend || _sending) {
                          return _SendButton(
                            sending: _sending,
                            onTap: widget.enabled ? _send : null,
                          );
                        }
                        return _LikeButton(
                          onTap: widget.enabled ? _sendLike : null,
                        );
                      },
                    ),
                  ],
                ),
              ),
              // Giảm chuyển động: không dựng AnimatedSize (thời lượng 0 vẫn chạy một
              // controller và đánh dấu layout trong lúc layout).
              if (motion)
                AnimatedSize(
                  duration: duration,
                  curve: OmniCurves.standard,
                  alignment: Alignment.topCenter,
                  child: tray,
                )
              else
                tray,
            ],
          ),
        ),
      ),
    );
  }
}

/// Khay `+`: lưới 4 cột, chỉ những mục có việc thật phía sau.
class _Tray extends StatelessWidget {
  const _Tray({required this.onCreateTask, required this.onTemplates});

  final VoidCallback? onCreateTask;
  final VoidCallback? onTemplates;

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[
      if (onCreateTask != null)
        _TrayItem(
          icon: Icons.task_alt_rounded,
          label: 'Tạo việc',
          background: const Color(0xFFFFF7E0),
          foreground: const Color(0xFF8A5A00),
          onTap: onCreateTask!,
        ),
      if (onTemplates != null)
        _TrayItem(
          icon: Icons.bolt_rounded,
          label: 'Mẫu trả lời',
          background: const Color(0xFFE6F3F2),
          foreground: const Color(0xFF075E59),
          onTap: onTemplates!,
        ),
    ];
    if (items.isEmpty) return const SizedBox(width: double.infinity);

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: Row(
        children: [
          for (final item in items) Expanded(child: item),
          for (var i = items.length; i < 4; i++)
            const Expanded(child: SizedBox()),
        ],
      ),
    );
  }
}

class _TrayItem extends StatelessWidget {
  const _TrayItem({
    required this.icon,
    required this.label,
    required this.background,
    required this.foreground,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color background;
  final Color foreground;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Nền pastel của thiết kế chỉ đúng với giao diện sáng; tối thì dùng nền
    // thẻ của theme và chữ theo màu chủ đề.
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = dark ? scheme.surfaceContainerHighest : background;
    final fg = dark ? scheme.onSurface : foreground;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
              child: Icon(icon, size: OmniIconSize.lg, color: fg),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: OmniType.micro.copyWith(color: scheme.onSurface),
            ),
          ],
        ),
      ),
    );
  }
}

class _TemplateSheet extends StatelessWidget {
  const _TemplateSheet({required this.templates});

  final List<String> templates;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.6,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                OmniSpacing.lg,
                0,
                OmniSpacing.lg,
                OmniSpacing.sm,
              ),
              child: Text('Mẫu trả lời', style: OmniType.bodyStrong),
            ),
            if (templates.isEmpty)
              Padding(
                padding: const EdgeInsets.all(OmniSpacing.lg),
                child: Text(
                  'Chưa có mẫu trả lời nào.',
                  style: OmniType.caption.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final text in templates)
                      ListTile(
                        dense: true,
                        title: Text(text, style: OmniType.caption),
                        onTap: () => Navigator.pop(context, text),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: OmniSpacing.md),
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
                    fontWeight: FontWeight.w600,
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
    this.rotated = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  /// `+` xoay 45° (thành ×) khi khay đang mở.
  final bool rotated;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = onTap == null
        ? theme.disabledColor
        : theme.colorScheme.primary;
    final turn = OmniMotion.enabled(context) ? _slowMotion : Duration.zero;

    return IconButton(
      onPressed: onTap,
      tooltip: tooltip,
      padding: EdgeInsets.zero,
      style: IconButton.styleFrom(
        minimumSize: const Size(_toolWidth, _toolWidth),
        fixedSize: const Size(_toolWidth, _toolWidth),
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        // Giảm chuyển động: bỏ cả gợn mực lẫn lớp sáng khi chạm.
        splashFactory: OmniMotion.enabled(context)
            ? null
            : NoSplash.splashFactory,
        overlayColor: OmniMotion.enabled(context) ? null : Colors.transparent,
      ),
      icon: AnimatedRotation(
        turns: rotated ? 0.125 : 0,
        duration: turn,
        curve: OmniCurves.standard,
        child: Icon(icon, size: OmniIconSize.xl, color: color),
      ),
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
                        size: OmniIconSize.sm,
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

class _LikeButton extends StatelessWidget {
  const _LikeButton({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      tooltip: 'Gửi like',
      padding: EdgeInsets.zero,
      style: IconButton.styleFrom(
        fixedSize: const Size(44, 44),
        minimumSize: const Size(44, 44),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      icon: const Text(_likeText, style: OmniChatType.emoji),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({required this.sending, required this.onTap});

  final bool sending;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = !sending && onTap != null;
    // Hộp chạm 44x44, nút vẽ 34 (giữ kích thước biểu tượng của thiết kế).
    return Tooltip(
      message: 'Gửi',
      child: Semantics(
        button: true,
        enabled: enabled,
        child: InkResponse(
          onTap: enabled ? onTap : null,
          radius: 22,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Center(
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: enabled
                      ? scheme.primary
                      : scheme.primary.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: sending
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: scheme.onPrimary,
                        ),
                      )
                    : Icon(
                        Icons.send_rounded,
                        size: OmniIconSize.md,
                        color: scheme.onPrimary,
                      ),
              ),
            ),
          ),
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
              child: Text(_emojis[index], style: OmniChatType.emoji),
            ),
          ),
        ),
      ),
    );
  }
}
