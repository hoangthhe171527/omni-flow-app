import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

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

part 'message_composer_parts.dart';

/// Ô soạn kiểu iOS (duyệt 26/11/2026): nút ⊕ tròn xám bên trái, ô nhập bo 19
/// viền mảnh có mặt cười NẰM TRONG ô, và nút cuối.
///
/// ⊕ mở menu nổi tại chỗ gộp Ảnh, Máy ảnh, Tệp, Mẫu trả lời, Tạo việc — chỉ
/// những mục kênh và quyền cho phép. Nút cuối: ô trống = mic (ghi âm, khi kênh
/// nhận tin thoại); có chữ hoặc ảnh = nút ↑ tròn xanh. Bỏ nút 👍 và cụm icon
/// xanh + `›` bung công cụ.
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

  /// Chọn tài liệu. Null (hoặc kênh không gửi tệp) ẩn mục "Tệp" trong menu.
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

  /// Mở màn tạo việc. Null ẩn mục "Tạo việc" trong menu (không đủ quyền).
  final VoidCallback? onCreateTask;

  /// Nạp danh sách mẫu trả lời. Null ẩn mục "Mẫu trả lời".
  final Future<List<String>> Function()? loadTemplates;

  final bool enabled;
  final Message? replyTo;
  final VoidCallback? onCancelReply;

  @override
  State<MessageComposer> createState() => _MessageComposerState();
}

const _toolWidth = 44.0;

class _MessageComposerState extends State<MessageComposer> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  bool _sending = false;
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
  void dispose() {
    _dropVoiceTicks();
    // Rời trang khi đang ghi (hoặc còn bản ghi chưa gửi): dừng và xoá tệp.
    if (_voiceActive) unawaited(widget.voiceRecorder?.cancel());
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(MessageComposer old) {
    super.didUpdateWidget(old);
    // Kênh/quyền đổi giữa chừng (mất onSendVoice hoặc máy ghi): thanh ghi
    // không còn nút Gửi dùng được — huỷ lượt ghi trên máy ghi CŨ, xoá tệp.
    // Đang gửi thì để lượt gửi tự kết thúc (tệp đang được tải lên).
    final lost = widget.onSendVoice == null || widget.voiceRecorder == null;
    if (lost && _voiceActive && !_sending) {
      _dropVoiceTicks();
      _resetVoice();
      unawaited(old.voiceRecorder?.cancel());
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if ((text.isEmpty && _pendingImages.isEmpty) || _sending) return;
    HapticFeedback.lightImpact();
    await _dispatch(text, fromField: true);
  }

  Future<void> _dispatch(String text, {bool fromField = false}) async {
    setState(() => _sending = true);
    try {
      await widget.onSend(text, _pendingImages, widget.replyTo);
      if (!mounted) return;
      setState(() {
        if (fromField) _controller.clear();
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
      showComposerToast(context, text, messenger: messenger);
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  Future<void> _startVoice() async {
    final recorder = widget.voiceRecorder;
    if (recorder == null || _voiceActive || _voiceStarting || _sending) return;
    HapticFeedback.lightImpact();
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
      _stopping = null;
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

  /// Lượt dừng đang chạy/đã xong của bản ghi hiện tại. Bấm Gửi đúng lúc tự
  /// dừng ở 5:00 thì chờ chung lượt này, không gửi tệp chưa chốt.
  Future<String?>? _stopping;

  /// Dừng máy ghi, giữ tệp. Trả đường dẫn, null nếu lỗi.
  Future<String?> _stopVoiceRecording() => _stopping ??= _stopOnce();

  Future<String?> _stopOnce() async {
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
    _stopping = null;
  }

  Future<void> _cancelVoice() async {
    _dropVoiceTicks();
    if (mounted) setState(_resetVoice);
    await widget.voiceRecorder?.cancel();
  }

  /// Gửi xong thì tệp WAV hết việc: xoá khỏi thư mục tạm. Lỗi xoá thì bỏ qua
  /// (hệ điều hành dọn sau) — tin đã đi rồi.
  Future<void> _discardSent(VoiceRecorder? recorder, String path) async {
    try {
      await recorder?.discard(path);
    } on Object {
      // bỏ qua
    }
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
    HapticFeedback.lightImpact();
    setState(() => _sending = true);
    try {
      final path = await _stopVoiceRecording();
      if (path == null) {
        await _cancelVoice();
        _notify(messenger, 'Không ghi âm được. Vui lòng thử lại.');
        return;
      }
      final name = path.split(RegExp(r'[\\/]')).last;
      final recorder = widget.voiceRecorder;
      await send(
        PendingAttachment(path: path, name: name, kind: PendingKind.voice),
      );
      if (mounted) setState(_resetVoice);
      await _discardSent(recorder, path);
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
    final picked = await showOmniSheet<String>(
      context: context,
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

    final picked = await showOmniSheet<String>(
      context: context,
      builder: (_) => _TemplateSheet(templates: templates),
    );
    if (picked == null || !mounted) return;
    _insert(picked);
  }

  /// Menu ⊕ có ít nhất một mục.
  bool get _hasMenuItems =>
      _showImages ||
      _showFiles ||
      widget.onCreateTask != null ||
      widget.loadTemplates != null;

  /// Menu ⊕ (duyệt 26/11/2026): Ảnh, Máy ảnh, Tệp, Mẫu trả lời, Tạo việc —
  /// chỉ mục kênh/quyền cho phép. Đủ 10 tệp: mục tệp vẫn hiện nhưng khoá,
  /// ghi rõ "Đủ 10".
  Future<void> _openAddMenu(Rect anchor) => showOmniAnchoredMenu<void>(
    context: context,
    anchor: anchor,
    width: 248,
    menuKey: const Key('composer-tools-menu'),
    semanticsLabel: 'Thêm vào tin nhắn',
    builder: (menuContext) {
      final locked = _full || _sending;
      Widget? fullNote() => _full
          ? Text(
              'Đủ ${InboxApi.maxAttachmentsPerMessage}',
              style: OmniType.micro.copyWith(
                color: Theme.of(menuContext).colorScheme.onSurfaceVariant,
              ),
            )
          : null;
      VoidCallback run(VoidCallback action) => () {
        Navigator.of(menuContext).pop();
        action();
      };
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_showImages)
            OmniAnchoredMenuItem(
              icon: LucideIcons.image,
              label: 'Ảnh',
              trailing: fullNote(),
              onTap: locked ? null : run(() => unawaited(_pickImages())),
            ),
          if (_showImages && widget.onTakePhoto != null)
            OmniAnchoredMenuItem(
              icon: LucideIcons.camera,
              label: 'Máy ảnh',
              trailing: fullNote(),
              onTap: locked ? null : run(() => unawaited(_takePhoto())),
            ),
          if (_showFiles)
            OmniAnchoredMenuItem(
              icon: LucideIcons.paperclip,
              label: 'Tệp',
              trailing: fullNote(),
              onTap: locked ? null : run(() => unawaited(_pickFiles())),
            ),
          if (widget.loadTemplates != null)
            OmniAnchoredMenuItem(
              icon: LucideIcons.zap,
              label: 'Mẫu trả lời',
              onTap: run(() => unawaited(_openTemplates())),
            ),
          if (widget.onCreateTask != null)
            OmniAnchoredMenuItem(
              icon: LucideIcons.circleCheckBig,
              label: 'Tạo việc',
              onTap: run(widget.onCreateTask!),
            ),
        ],
      );
    },
  );

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final highContrast = MediaQuery.highContrastOf(context);
    // Ô nhập bo 19 viền mảnh (bản duyệt: mực 14% / trắng 10%).
    final fieldBorder = OutlineInputBorder(
      borderRadius: const BorderRadius.all(Radius.circular(19)),
      borderSide: BorderSide(
        color: highContrast
            ? scheme.outline
            : OmniColors.byBrightness(
                context,
                OmniColors.ink.withValues(alpha: .14),
                Colors.white.withValues(alpha: .10),
              ),
      ),
    );

    // Lớp vẽ riêng: gõ phím, nháy con trỏ, đổi nút gửi — chỉ composer raster
    // lại, danh sách tin nhắn và nền phía trên nó thì không.
    //
    // Thanh soạn phẳng sát đáy, nền đặc + vạch mảnh trên (kiểu iMessage, duyệt
    // 26/11/2026) — không còn viên thuốc nổi.
    return RepaintBoundary(
      child: DecoratedBox(
        key: const ValueKey('composer-glass'),
        decoration: BoxDecoration(
          color: scheme.surface,
          border: Border(
            top: BorderSide(
              color: highContrast ? scheme.outline : scheme.outlineVariant,
              width: highContrast ? 1 : 0.5,
            ),
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
                padding: const EdgeInsets.all(4),
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
                        // Ô nhiều dòng: nút ⊕ và nút cuối nằm ở đáy như iOS.
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Builder(
                            builder: (buttonContext) => _AddButton(
                              onTap: widget.enabled && _hasMenuItems
                                  ? () {
                                      final box =
                                          buttonContext.findRenderObject()
                                              as RenderBox?;
                                      if (box == null || !box.hasSize) return;
                                      unawaited(
                                        _openAddMenu(
                                          box.localToGlobal(Offset.zero) &
                                              box.size,
                                        ),
                                      );
                                    }
                                  : null,
                            ),
                          ),
                          Expanded(
                            child: Padding(
                              // Ô 38 giữa hàng nút 44: lề 3 trên/dưới.
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  minHeight: 38,
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
                                    hintText: 'Nhắn tin',
                                    hintStyle: OmniType.input.copyWith(
                                      color: scheme.onSurfaceVariant,
                                    ),
                                    isDense: true,
                                    filled: true,
                                    fillColor: scheme.surface,
                                    border: fieldBorder,
                                    enabledBorder: fieldBorder,
                                    focusedBorder: fieldBorder,
                                    disabledBorder: fieldBorder,
                                    contentPadding: const EdgeInsets.fromLTRB(
                                      14,
                                      8,
                                      2,
                                      8,
                                    ),
                                    // Mặt cười NẰM TRONG ô, bên phải.
                                    suffixIconConstraints: const BoxConstraints(
                                      minWidth: 44,
                                      minHeight: 36,
                                    ),
                                    suffixIcon: IconButton(
                                      onPressed: widget.enabled
                                          ? _openEmoji
                                          : null,
                                      tooltip: 'Biểu tượng cảm xúc',
                                      padding: EdgeInsets.zero,
                                      style: IconButton.styleFrom(
                                        fixedSize: const Size(44, 36),
                                        minimumSize: const Size(44, 36),
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      icon: Icon(
                                        LucideIcons.smile,
                                        size: 22,
                                        color: scheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                  onSubmitted: (_) => _send(),
                                ),
                              ),
                            ),
                          ),
                          // Chỉ nút cuối nghe controller: một phím gõ không
                          // dựng lại ô nhập và khay ảnh.
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
                              // Ô trống: mic khi kênh nhận tin thoại; không
                              // thì nút ↑ mờ giữ chỗ để ô nhập không co giãn
                              // khi gõ (đã bỏ 👍).
                              if (_showVoice) {
                                return _ComposerIcon(
                                  icon: LucideIcons.mic,
                                  tooltip: 'Ghi âm',
                                  onTap: widget.enabled && !_sending
                                      ? _startVoice
                                      : null,
                                );
                              }
                              return const _SendButton(
                                sending: false,
                                onTap: null,
                              );
                            },
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
