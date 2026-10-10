import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../design/components/components.dart';
import '../../../../design/platform/omni_motion_scope.dart';
import '../../../../design/tokens/tokens.dart';
import '../../application/voice_recorder.dart';
import '../../data/inbox_api.dart';
import '../../domain/message.dart';
import '../../domain/outbound_capabilities.dart';
import '../../domain/pending_attachment.dart';
import 'composer_snack_bar.dart';
import 'voice_record_bar.dart';

/// Thanh nhập kiểu Messenger (`Thread.dc.html`): một hàng gồm cụm công cụ
/// (`+`, chụp ảnh, ảnh, ghi âm), ô nhập bo tròn có mặt cười, và nút cuối.
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
    this.onPickFiles,
    this.voiceRecorder,
    this.onSendVoice,
    this.warnVoiceAsLink = false,
    this.channelName,
    this.capabilities,
    this.errorText,
    this.onCreateTask,
    this.loadTemplates,
    this.enabled = true,
    this.replyTo,
    this.onCancelReply,
  });

  final Future<void> Function(
    String text,
    List<PendingAttachment> attachments,
    Message? replyTo,
  )
  onSend;

  /// Picks every image selected from the gallery. Keeping selection in the
  /// composer lets a rep add a caption, remove a mistake, then send one batch.
  /// Nhận số chỗ còn lại (trần [InboxApi.maxAttachmentsPerMessage]); composer
  /// vẫn tự cắt vì có trình chọn bỏ qua `limit`.
  final Future<List<PendingAttachment>> Function(int remaining) onPickImages;

  /// Take a photo. Null hides the entry rather than offering a dead button.
  final Future<PendingAttachment?> Function()? onTakePhoto;

  /// Chọn tài liệu. Null (hoặc kênh không gửi tệp) ẩn mục "Tệp" trong khay.
  final Future<List<PendingAttachment>> Function(int remaining)? onPickFiles;

  /// Máy ghi âm (tiêm được; trang hội thoại lấy từ `voiceRecorderProvider`).
  final VoiceRecorder? voiceRecorder;

  /// Gửi ngay một bản ghi thành tin chỉ có tệp `audio`. Null (hoặc kênh không
  /// gửi audio, hoặc thiếu [voiceRecorder]) ẩn nút mic. Ném lỗi thì thanh ghi
  /// được giữ để gửi lại.
  final Future<void> Function(PendingAttachment voice)? onSendVoice;

  /// Kênh gửi audio thành đường link (Zalo OA `audio: link`): hỏi một lần mỗi
  /// phiên composer, trước lượt ghi đầu tiên.
  final bool warnVoiceAsLink;

  /// Tên kênh cho câu cảnh báo ("Zalo OA chỉ gửi …"). Null = "Kênh này".
  final String? channelName;

  /// Kênh gửi được gì (`outbound_capabilities`). Null = API cũ: giữ chữ + ảnh,
  /// ẩn Tệp và Ghi âm.
  final OutboundCapabilities? capabilities;

  /// Lỗi gửi của server (vd 422 `channel_send_unsupported`), hiện ngay trên
  /// ô nhập — nháp vẫn giữ nguyên.
  final String? errorText;

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

  /// Ảnh và tệp đang chờ gửi, theo thứ tự chọn.
  final List<PendingAttachment> _pendingImages = [];

  int get _remaining =>
      InboxApi.maxAttachmentsPerMessage - _pendingImages.length;

  bool get _full => _remaining <= 0;

  bool get _showImages => widget.capabilities?.canSendImages ?? true;

  bool get _showFiles =>
      widget.onPickFiles != null &&
      (widget.capabilities?.canSendFiles ?? false);

  /// Mic chỉ khi kênh gửi được audio (API cũ thiếu khoá thì ẩn).
  bool get _showVoice =>
      widget.onSendVoice != null &&
      widget.voiceRecorder != null &&
      (widget.capabilities?.canSendVoice ?? false);

  // --- Ghi âm ---------------------------------------------------------------

  /// Đang có thanh ghi (đang ghi, hoặc đã tự dừng ở 5:00 chờ Gửi/Huỷ).
  bool _voiceActive = false;

  /// Đang chạy chuỗi xin quyền/bắt đầu: chặn bấm mic hai lần.
  bool _voiceStarting = false;

  /// Đã dừng (tự dừng ở trần, hoặc dừng để gửi): [_voicePath] là tệp xong.
  bool _voiceStopped = false;
  String? _voicePath;
  Duration _voiceElapsed = Duration.zero;
  StreamSubscription<Duration>? _voiceTicks;

  /// Đã hỏi cảnh báo "gửi thành đường link" trong phiên này.
  bool _voiceWarned = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
    _focus.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _dropVoiceTicks();
    // Rời trang khi đang ghi (hoặc còn bản ghi chưa gửi): dừng và xoá tệp.
    if (_voiceActive) unawaited(widget.voiceRecorder?.cancel());
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
    if (_full) return;
    await _accept(await widget.onPickImages(_remaining));
  }

  Future<void> _takePhoto() async {
    if (_full) return;
    final image = await widget.onTakePhoto?.call();
    if (image != null) await _accept([image]);
  }

  Future<void> _pickFiles() async {
    final pick = widget.onPickFiles;
    if (pick == null || _full) return;
    setState(() => _trayOpen = false);
    await _accept(await pick(_remaining));
  }

  /// Nhận tệp vừa chọn: bỏ tệp quá 25MB, cắt theo trần 10, hỏi trước khi thêm
  /// tệp/ảnh mà kênh sẽ gửi thành đường link (hoặc không nhận). Không bao giờ
  /// lặng lẽ bỏ: mọi tệp bị bỏ đều được báo.
  Future<void> _accept(List<PendingAttachment> picked) async {
    if (!mounted || picked.isEmpty) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    final notes = <String>[];

    var items = [
      for (final a in picked)
        if ((a.size ?? 0) <= InboxApi.maxUploadBytes) a,
    ];
    if (items.length < picked.length) {
      notes.add('Tệp vượt 25MB, không gửi được.');
    }
    final room = _remaining;
    if (items.length > room) {
      notes.add(
        'Mỗi tin tối đa ${InboxApi.maxAttachmentsPerMessage} tệp — '
        'đã bỏ ${items.length - room} tệp.',
      );
      items = items.take(room).toList();
    }

    final warning = _channelWarning(
      items,
      widget.capabilities,
      channel: widget.channelName,
    );
    if (warning != null) {
      final ok = await showOmniConfirm(
        context: context,
        title: warning.title,
        message: warning.message,
        confirmLabel: 'Vẫn gửi',
      );
      if (!mounted) return;
      if (!ok) {
        items = [
          for (final a in items)
            if (!warning.affected.contains(a)) a,
        ];
      }
    }

    if (items.isNotEmpty) setState(() => _pendingImages.addAll(items));
    if (notes.isNotEmpty) _notify(messenger, notes.join(' '));
  }

  /// Snackbar nổi phía trên composer (không che nút Gửi). [messenger] lấy
  /// TRƯỚC khi chờ.
  ///
  /// Đo composer SAU khung hình kế: khay ảnh vừa thêm (hay thanh ghi vừa
  /// đóng) đổi chiều cao, đo ngay thì snackbar nằm theo cỡ cũ và đè khay.
  void _notify(ScaffoldMessengerState? messenger, String text) {
    if (!mounted || messenger == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      messenger.showSnackBar(composerSnackBar(context, text));
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  Future<void> _startVoice() async {
    final recorder = widget.voiceRecorder;
    if (recorder == null || _voiceActive || _voiceStarting || _sending) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    _voiceStarting = true;
    try {
      if (widget.warnVoiceAsLink && !_voiceWarned) {
        final ok = await showOmniConfirm(
          context: context,
          title: 'Gửi ghi âm thành đường link?',
          message:
              '${widget.channelName ?? 'Kênh này'} không nhận tin thoại — bản '
              'ghi sẽ gửi dưới dạng '
              'đường link, khách bấm để nghe.',
          confirmLabel: 'Vẫn ghi âm',
        );
        if (!mounted || !ok) return;
        _voiceWarned = true;
      }
      if (!await recorder.ensurePermission()) {
        _notify(
          messenger,
          'Chưa có quyền micro — bật trong Cài đặt để ghi âm.',
        );
        return;
      }
      final path = await recorder.newRecordingPath();
      if (!mounted) return;
      _dropVoiceTicks();
      _voiceStopped = false;
      _voiceTicks = recorder.elapsed.listen(_onVoiceTick);
      await recorder.start(path);
      if (!mounted) {
        unawaited(recorder.cancel());
        return;
      }
      setState(() {
        _voiceActive = true;
        _voiceStopped = false;
        _voicePath = path;
        _voiceElapsed = Duration.zero;
        _trayOpen = false;
      });
    } on Object {
      _dropVoiceTicks();
      _notify(messenger, 'Không ghi âm được. Vui lòng thử lại.');
    } finally {
      _voiceStarting = false;
    }
  }

  void _onVoiceTick(Duration elapsed) {
    if (!mounted || _voiceStopped) return;
    final capped = elapsed >= kVoiceMaxDuration ? kVoiceMaxDuration : elapsed;
    setState(() => _voiceElapsed = capped);
    // Tới trần thì tự dừng nhưng KHÔNG tự gửi: người dùng nghe lại trong đầu
    // điều mình vừa nói rồi mới quyết.
    if (elapsed >= kVoiceMaxDuration) unawaited(_stopVoiceRecording());
  }

  /// Dừng máy ghi, giữ tệp. Trả đường dẫn, null nếu lỗi.
  Future<String?> _stopVoiceRecording() async {
    if (_voiceStopped) return _voicePath;
    _voiceStopped = true;
    _dropVoiceTicks();
    final path = await widget.voiceRecorder?.stop();
    if (mounted) setState(() => _voicePath = path ?? _voicePath);
    return path;
  }

  /// Bỏ nghe nhịp đồng hồ. Không chờ `cancel()` của subscription: chỉ cần
  /// dừng nhận nhịp, và chờ thì lượt Huỷ/Gửi trễ một nhịp sự kiện.
  void _dropVoiceTicks() {
    final ticks = _voiceTicks;
    _voiceTicks = null;
    if (ticks != null) unawaited(ticks.cancel());
  }

  void _resetVoice() {
    _voiceActive = false;
    _voiceStopped = false;
    _voicePath = null;
    _voiceElapsed = Duration.zero;
  }

  Future<void> _cancelVoice() async {
    _dropVoiceTicks();
    if (mounted) setState(_resetVoice);
    await widget.voiceRecorder?.cancel();
  }

  Future<void> _sendVoice() async {
    final send = widget.onSendVoice;
    if (send == null || _sending) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (_voiceElapsed < kVoiceMinDuration) {
      await _cancelVoice();
      _notify(messenger, 'Ghi âm quá ngắn.');
      return;
    }
    setState(() => _sending = true);
    try {
      final path = await _stopVoiceRecording();
      if (path == null) {
        await _cancelVoice();
        _notify(messenger, 'Không ghi âm được. Vui lòng thử lại.');
        return;
      }
      final name = path.split(RegExp(r'[\\/]')).last;
      await send(
        PendingAttachment(path: path, name: name, kind: PendingKind.voice),
      );
      if (mounted) setState(_resetVoice);
    } on Object {
      // Trang đã báo lỗi tải/gửi. Giữ thanh và tệp để bấm Gửi lại.
    } finally {
      if (mounted) setState(() => _sending = false);
    }
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
    // Đủ 10 tệp: nút vẫn hiện nhưng khoá, nói rõ vì sao.
    if (_showImages && widget.onTakePhoto != null)
      _ComposerIcon(
        icon: Icons.photo_camera_rounded,
        tooltip: _full ? _fullLabel : 'Chụp ảnh',
        onTap: widget.enabled && !_sending && !_full ? _takePhoto : null,
      ),
    if (_showImages)
      _ComposerIcon(
        icon: Icons.image_rounded,
        tooltip: _full ? _fullLabel : 'Ảnh',
        onTap: widget.enabled && !_sending && !_full ? _pickImages : null,
      ),
    if (_showVoice)
      _ComposerIcon(
        icon: Icons.mic_none_rounded,
        tooltip: 'Ghi âm',
        onTap: widget.enabled && !_sending ? _startVoice : null,
      ),
  ];

  int get _toolCount =>
      1 +
      (_showImages && widget.onTakePhoto != null ? 1 : 0) +
      (_showImages ? 1 : 0) +
      (_showVoice ? 1 : 0);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final motion = OmniMotion.enabled(context);
    final duration = motion ? _slowMotion : Duration.zero;
    final toolsWidth = _toolWidth * _toolCount;
    final fieldFill = OmniColors.byBrightness(
      context,
      OmniColors.muted,
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
            showFiles: _showFiles,
            onFiles: _full || _sending ? null : _pickFiles,
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
              if (widget.errorText != null)
                _ComposerError(text: widget.errorText!),
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
                // Đang ghi âm: thanh ghi thay cả hàng — các nút khác khoá.
                child: _voiceActive
                    ? VoiceRecordBar(
                        elapsed: _voiceElapsed,
                        stopped: _voiceStopped && !_sending,
                        onCancel: _sending ? null : _cancelVoice,
                        sendButton: _SendButton(
                          sending: _sending,
                          tooltip: 'Gửi ghi âm',
                          onTap: widget.enabled ? _sendVoice : null,
                        ),
                      )
                    : Row(
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
                                textCapitalization:
                                    TextCapitalization.sentences,
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
                                    onPressed: widget.enabled
                                        ? _openEmoji
                                        : null,
                                    tooltip: 'Biểu tượng cảm xúc',
                                    padding: EdgeInsets.zero,
                                    style: IconButton.styleFrom(
                                      fixedSize: const Size(44, 44),
                                      minimumSize: const Size(44, 44),
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
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
  const _Tray({
    required this.onCreateTask,
    required this.onTemplates,
    this.showFiles = false,
    this.onFiles,
  });

  final VoidCallback? onCreateTask;
  final VoidCallback? onTemplates;

  /// Mục "Tệp" hiện (kênh gửi được tệp); [onFiles] null = khoá (đủ 10 tệp).
  final bool showFiles;
  final VoidCallback? onFiles;

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[
      if (showFiles)
        _TrayItem(
          icon: Icons.attach_file_rounded,
          label: 'Tệp',
          hue: OmniHue.neutral,
          onTap: onFiles,
          disabledLabel: _fullLabel,
        ),
      if (onCreateTask != null)
        _TrayItem(
          icon: Icons.task_alt_rounded,
          label: 'Tạo việc',
          hue: OmniHue.orange,
          onTap: onCreateTask!,
        ),
      if (onTemplates != null)
        _TrayItem(
          icon: Icons.bolt_rounded,
          label: 'Mẫu trả lời',
          hue: OmniHue.teal,
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
    required this.hue,
    required this.onTap,
    this.disabledLabel,
  });

  final IconData icon;
  final String label;
  final OmniHue hue;
  final VoidCallback? onTap;

  /// Semantics khi [onTap] null (vd "Đã đủ 10 tệp").
  final String? disabledLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Cặp nền/chữ theo sắc của tính năng, có bản tối.
    final tone = OmniFeatureTones.of(context, hue);
    final enabled = onTap != null;
    final bg = tone.background;
    final fg = enabled ? tone.foreground : Theme.of(context).disabledColor;

    return Semantics(
      button: true,
      enabled: enabled,
      hint: enabled ? null : disabledLabel,
      child: _trayInk(context, scheme, bg, fg),
    );
  }

  Widget _trayInk(
    BuildContext context,
    ColorScheme scheme,
    Color bg,
    Color fg,
  ) {
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

  final List<PendingAttachment> images;
  final ValueChanged<PendingAttachment> onRemove;

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
          if (!image.isImage) {
            return _FileTile(file: image, onRemove: () => onRemove(image));
          }
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

const _fullLabel = 'Đã đủ ${InboxApi.maxAttachmentsPerMessage} tệp';

/// Tệp (không phải ảnh) trong khay chờ: ô 56 có đuôi, tên một dòng, nút ✕ 44.
class _FileTile extends StatelessWidget {
  const _FileTile({required this.file, required this.onRemove});

  final PendingAttachment file;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ext = file.extension.toUpperCase();
    return Container(
      width: 208,
      padding: const EdgeInsets.only(left: 6),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: OmniRadius.smAll,
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: OmniRadius.smAll,
            ),
            child: ext.isEmpty
                ? Icon(
                    Icons.insert_drive_file_outlined,
                    color: scheme.onSurfaceVariant,
                  )
                : Text(
                    ext,
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    style: OmniType.micro.copyWith(
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                  ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              file.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: OmniType.caption.copyWith(color: scheme.onSurface),
            ),
          ),
          IconButton(
            onPressed: onRemove,
            tooltip: 'Bỏ tệp',
            padding: EdgeInsets.zero,
            style: IconButton.styleFrom(
              fixedSize: const Size(44, 44),
              minimumSize: const Size(44, 44),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            icon: Icon(
              Icons.close_rounded,
              size: OmniIconSize.md,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Lỗi gửi của server ngay trên ô nhập (nháp vẫn giữ).
class _ComposerError extends StatelessWidget {
  const _ComposerError({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: OmniIconSize.sm,
              color: scheme.error,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                text,
                style: OmniType.caption.copyWith(color: scheme.error),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Cảnh báo trước khi thêm tệp/ảnh mà kênh không gửi thành tệp thật.
typedef _ChannelWarning = ({
  String title,
  String message,
  List<PendingAttachment> affected,
});

String _mb(int? bytes) =>
    bytes == null ? '' : ' dưới ${(bytes / (1024 * 1024)).round()}MB';

String _exts(List<String> exts) => exts.map((e) => e.toUpperCase()).join(', ');

/// Null = không có gì cần hỏi. Ảnh và tệp được chọn ở hai lối riêng nên một
/// lượt chỉ có một loại.
_ChannelWarning? _channelWarning(
  List<PendingAttachment> items,
  OutboundCapabilities? caps, {
  String? channel,
}) {
  if (caps == null || items.isEmpty) return null;
  final who = channel ?? 'Kênh này';

  final images = items.where((a) => a.isImage).toList();
  final files = items.where((a) => a.kind == PendingKind.file).toList();

  // Ảnh: `image_constraints` (Zalo OA: JPG/PNG). Chỉ xét ĐUÔI: server nén
  // JPG/PNG/WebP lớn xuống ≤ 1MB lúc tải lên (`InboxImageCompressor`), nên cỡ
  // không làm ảnh thành link. Đuôi ngoài danh sách (GIF, WebP nhỏ) thì server
  // gửi thành link (`fallback: link`) hoặc nền tảng từ chối (`failed`).
  final ic = caps.imageConstraints;
  if (ic != null) {
    final off = [
      for (final a in images)
        if (!ic.allowsExtension(a.name)) a,
    ];
    if (off.isNotEmpty) {
      final rule = _exts(ic.nativeExtensions);
      final these = off.length == 1 ? 'Ảnh này' : '${off.length} ảnh này';
      return ic.failsOutside
          ? (
              title: 'Ảnh có thể không tới khách',
              message:
                  '$who không nhận ảnh ngoài $rule — $these có thể bị '
                  'từ chối và tin báo lỗi.',
              affected: off,
            )
          : (
              title: 'Gửi thành đường link?',
              message:
                  '$who chỉ gửi ảnh $rule thành ảnh — $these sẽ gửi dưới '
                  'dạng đường link, khách bấm để xem.',
              affected: off,
            );
    }
  }

  if (files.isEmpty) return null;
  if (caps.file == OutboundMode.link) {
    return (
      title: 'Gửi thành đường link?',
      message: '$who gửi tệp dưới dạng đường link — khách bấm vào link để tải.',
      affected: files,
    );
  }
  if (caps.file == OutboundMode.docsOnly) {
    final off = [
      for (final a in files)
        if (!caps.sendsFileNatively(a.name, a.size ?? 0)) a,
    ];
    if (off.isEmpty) return null;
    final fc = caps.fileConstraints ?? FileConstraints.zaloOaFallback;
    final these = off.length == 1 ? 'tệp này' : '${off.length} tệp này';
    return (
      title: 'Gửi thành đường link?',
      message:
          '$who chỉ gửi ${_exts(fc.nativeExtensions)}${_mb(fc.nativeMaxBytes)} '
          'thành tệp — $these sẽ gửi dưới dạng đường link.',
      affected: off,
    );
  }
  return null;
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
  const _SendButton({
    required this.sending,
    required this.onTap,
    this.tooltip = 'Gửi',
  });

  final bool sending;
  final VoidCallback? onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = !sending && onTap != null;
    // Hộp chạm 44x44, nút vẽ 34 (giữ kích thước biểu tượng của thiết kế).
    return Tooltip(
      message: tooltip,
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
