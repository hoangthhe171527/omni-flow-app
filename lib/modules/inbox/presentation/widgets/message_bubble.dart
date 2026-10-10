import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/utils/formatters.dart';
import '../../../../design/components/components.dart';
import '../../../../design/tokens/tokens.dart';
import '../../domain/message.dart';
import 'message_attachments.dart';
import 'message_images.dart';
import 'message_actions_overlay.dart';
import 'message_link_preview.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    this.showSender = false,
    this.groupedWithPrevious = false,
    this.isLastInGroup = true,
    this.onRetry,
    this.onDiscard,
    this.onReply,
    this.onPin,
    this.onCreateTask,
    this.onCreateOpportunity,
  });

  final Message message;

  /// Group threads: the member who sent it, above the bubble.
  final bool showSender;

  /// The message directly above came from the same side. Consecutive messages
  /// used to sit the same distance apart as a change of speaker, so the thread
  /// had no rhythm — a run of five replies looked like five unrelated events.
  final bool groupedWithPrevious;

  /// Last of a run from the same side. Only this one wears the avatar, the way
  /// Zalo does; the others reserve the space so the column stays aligned.
  final bool isLastInGroup;

  final VoidCallback? onRetry;
  final VoidCallback? onDiscard;
  final VoidCallback? onReply;
  final VoidCallback? onPin;

  /// Menu bấm giữ: ẩn mục tương ứng khi null (thiếu quyền / tính năng tắt).
  final VoidCallback? onCreateTask;
  final VoidCallback? onCreateOpportunity;

  Future<void> _copy(BuildContext context) async {
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    await Clipboard.setData(ClipboardData(text: message.text));
    messenger?.showSnackBar(const SnackBar(content: Text('Đã sao chép.')));
  }

  @override
  Widget build(BuildContext context) {
    if (message.isNote) return _NoteBubble(message: message);

    final scheme = Theme.of(context).colorScheme;
    final outbound = message.isOutbound;
    final failed = message.status == DeliveryStatus.failed;

    // Measured against Zalo itself rather than from memory: the outgoing bubble
    // is a MUTED blue-grey, not a saturated blue — a bright bubble is exhausting
    // to read a long thread on. Corners are evenly rounded on all four, with no
    // sharp tail, which is what lets a run of messages read as one calm column.
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bubbleColor = failed
        ? scheme.errorContainer
        : outbound
        ? OmniColors.chat(
            context,
            OmniColors.primary,
            OmniColors.chatOutboundDark,
          )
        : OmniColors.chat(
            context,
            OmniColors.chatInbound,
            OmniColors.chatInboundDark,
          );
    // Tin ra sáng là nền primary chữ trắng; dark mode trắng cả hai phía; tin
    // vào sáng là chữ tối trên nền trắng.
    final onBubble = failed
        ? scheme.onErrorContainer
        : dark || outbound
        ? Colors.white
        : scheme.onSurface;
    final metaColor = dark
        ? Colors.white.withValues(alpha: 0.55)
        : outbound && !failed
        ? Colors.white.withValues(alpha: 0.9)
        : OmniColors.chatMeta;
    // Góc ngoài 18; phía "đuôi" (phải với tin ra, trái với tin vào) chỉ bo 4
    // khi tin nằm trong một nhóm: đầu nhóm giữ 18 ở trên, cuối nhóm giữ 18 ở
    // dưới, tin giữa nhóm cả hai góc 4.
    final onPrimaryBubble = outbound && !dark && !failed;
    final tailTop = Radius.circular(groupedWithPrevious ? 4 : 18);
    final tailBottom = Radius.circular(isLastInGroup ? 18 : 4);
    const round = Radius.circular(18);
    final bubbleRadius = outbound
        ? BorderRadius.only(
            topLeft: round,
            bottomLeft: round,
            topRight: tailTop,
            bottomRight: tailBottom,
          )
        : BorderRadius.only(
            topRight: round,
            bottomRight: round,
            topLeft: tailTop,
            bottomLeft: tailBottom,
          );

    final images = message.recalled
        ? const <MessageAttachment>[]
        : message.attachments
              .where((attachment) => attachment.isImage)
              .toList();
    final videos = message.recalled
        ? const <MessageAttachment>[]
        : message.attachments
              .where((attachment) => attachment.isVideo)
              .toList();
    final files = message.attachments
        .where((attachment) => !attachment.isImage && !attachment.isVideo)
        .toList();
    final hasBubbleContent =
        message.recalled ||
        message.text.isNotEmpty ||
        files.isNotEmpty ||
        videos.isNotEmpty;
    final mediaHeroPrefix = message.id.isNotEmpty
        ? message.id
        : 'local-${identityHashCode(message)}';

    Widget messageMeta(Color color) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          Formatters.time(message.sentAt),
          style: OmniChatType.meta.copyWith(color: color),
        ),
        if (outbound) ...[
          const SizedBox(width: 5),
          _DeliveryReceipt(
            status: message.status,
            fallbackColor: color,
            showLabel: isLastInGroup,
            onPrimary: onPrimaryBubble,
          ),
        ],
        if (message.pinned) ...[
          const SizedBox(width: 5),
          Icon(Icons.push_pin_rounded, size: OmniIconSize.xs, color: color),
        ],
      ],
    );

    final bubble = Container(
      constraints: BoxConstraints(
        maxWidth: math.min(MediaQuery.sizeOf(context).width * 0.76, 560),
      ),
      // Symmetric vertical padding. The 6 at the bottom against 8 at the top
      // made every bubble sit slightly high in its own box.
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: bubbleColor,
        borderRadius: bubbleRadius,
        // Chỉ tin vào (sáng) có bóng nhẹ `0 1 2 rgba(11,26,51,.08)` để nổi
        // khỏi nền; tin ra đã đủ tương phản bằng màu.
        boxShadow: !outbound && !dark && !failed
            ? const [
                BoxShadow(
                  color: Color(0x140B1A33),
                  blurRadius: 2,
                  offset: Offset(0, 1),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (message.replyToMessageId != null)
            _QuotedMessage(message: message, onPrimary: onPrimaryBubble),
          if (files.isNotEmpty) ...[
            if (onPrimaryBubble)
              // Tệp trên nền primary: đảo sang chữ trắng.
              Theme(
                data: Theme.of(context).copyWith(
                  colorScheme: scheme.copyWith(
                    onSurface: Colors.white,
                    onSurfaceVariant: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
                child: MessageFileAttachments(attachments: files),
              )
            else
              MessageFileAttachments(attachments: files),
            if (message.text.isNotEmpty) const SizedBox(height: OmniSpacing.sm),
          ],
          if (message.recalled)
            Text(
              'Tin nhắn đã được thu hồi',
              style: OmniType.caption.copyWith(
                color: metaColor,
                fontStyle: FontStyle.italic,
              ),
            )
          else if (message.text.isNotEmpty)
            _MessageText(
              text: message.text,
              color: onBubble,
              linkColor: onPrimaryBubble ? Colors.white : null,
            ),
          if (message.text.isNotEmpty && _urlPattern.hasMatch(message.text))
            MessageLinkPreview(
              url: _urlPattern.firstMatch(message.text)!.group(0)!,
            ),
          // Time and tick inside the bubble, bottom-LEFT. Zalo puts them there
          // on both sides — checked against the real app, not from memory — and
          // they used to sit on their own line underneath, costing a full row of
          // vertical space per message.
          const SizedBox(height: 4),
          messageMeta(metaColor),
        ],
      ),
    );

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: outbound
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        if (images.isNotEmpty)
          MessageImageGallery(images: images, heroPrefix: mediaHeroPrefix),
        if (videos.isNotEmpty) MessageVideoAttachments(attachments: videos),
        if (images.isNotEmpty && !hasBubbleContent)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
            child: messageMeta(metaColor),
          ),
        if (hasBubbleContent) ...[
          if (images.isNotEmpty) const SizedBox(height: 4),
          bubble,
        ],
      ],
    );

    // Incoming messages sit beside the sender's avatar — Zalo shows one on
    // every incoming message, 1-1 threads included, and it is what anchors the
    // left column visually. Outgoing has none, so the right side stays clean.
    final avatarGutter = outbound
        ? const SizedBox(width: 8)
        : Padding(
            padding: const EdgeInsets.only(right: 6),
            child: isLastInGroup
                ? OmniAvatar(
                    name: message.senderName ?? '?',
                    imageUrl: message.senderAvatar,
                    size: OmniIconSize.hero,
                  )
                // Reserve the width so bubbles above stay in the same column.
                : const SizedBox(width: 32),
          );

    return _ReplySwipe(
      enabled: onReply != null,
      outbound: outbound,
      onReply: onReply,
      onPin: onPin,
      onCopy: message.text.isEmpty || message.recalled
          ? null
          : () => _copy(context),
      onCreateTask: onCreateTask,
      onCreateOpportunity: onCreateOpportunity,
      child: Padding(
        // 2 within a run, 10 when the speaker changes: the gap is what tells the
        // eye where one person stopped and the other started.
        padding: EdgeInsets.only(top: groupedWithPrevious ? 2 : 10),
        child: Row(
          mainAxisAlignment: outbound
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!outbound) avatarGutter,
            Flexible(
              child: Column(
                crossAxisAlignment: outbound
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  if (showSender && message.senderName != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 3),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          OmniAvatar(
                            name: message.senderName!,
                            imageUrl: message.senderAvatar,
                            size: OmniIconSize.sm,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            message.senderName!,
                            style: OmniType.micro.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      content,
                      if (message.reaction != null &&
                          message.reaction!.isNotEmpty)
                        Positioned(
                          right: outbound ? null : -6,
                          left: outbound ? -6 : null,
                          bottom: -8,
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: scheme.surface,
                              shape: BoxShape.circle,
                              border: Border.all(color: scheme.outline),
                            ),
                            child: Text(
                              message.reaction!,
                              style: OmniChatType.meta,
                            ),
                          ),
                        ),
                    ],
                  ),
                  _MetaLine(
                    message: message,
                    onRetry: onRetry,
                    onDiscard: onDiscard,
                  ),
                ],
              ),
            ),
            if (outbound) avatarGutter,
          ],
        ),
      ),
    );
  }
}

final _urlPattern = RegExp(
  r'(?:(?:https?://|www\.)[a-zA-Z0-9][^\s<>()]+|(?:[a-zA-Z0-9-]+\.)+(?:vn|com|net|org|io)(?:/[^\s<>()]*)?)',
  caseSensitive: false,
);

class _MessageText extends StatefulWidget {
  const _MessageText({required this.text, required this.color, this.linkColor});

  final String text;
  final Color color;

  /// Màu liên kết; null = xanh kênh chat. Tin ra nền primary dùng trắng.
  final Color? linkColor;

  @override
  State<_MessageText> createState() => _MessageTextState();
}

class _MessageTextState extends State<_MessageText> {
  final _recognizers = <TapGestureRecognizer>[];

  /// Spans (and the recognizers inside them) follow the widget's LIFECYCLE,
  /// not its builds. They used to be rebuilt in `build`, and a bubble rebuilds
  /// whenever the list does — a keystroke in the composer, a receipt, a scroll
  /// — so a link-heavy thread allocated and disposed N recognizers per frame
  /// to produce the same text. Only the text decides them; the colour is
  /// applied on the root span in `build`.
  late List<InlineSpan> _spans = _buildSpans();

  @override
  void didUpdateWidget(covariant _MessageText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text ||
        oldWidget.linkColor != widget.linkColor) {
      _spans = _buildSpans();
    }
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  void _disposeRecognizers() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();
  }

  Future<void> _open(String value) async {
    final normalized = value.toLowerCase().startsWith('http')
        ? value
        : 'https://$value';
    await launchUrl(
      Uri.parse(normalized),
      mode: LaunchMode.externalApplication,
    );
  }

  List<InlineSpan> _buildSpans() {
    _disposeRecognizers();

    final spans = <TextSpan>[];
    var cursor = 0;
    for (final match in _urlPattern.allMatches(widget.text)) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: widget.text.substring(cursor, match.start)));
      }
      final url = match.group(0)!;
      final recognizer = TapGestureRecognizer()..onTap = () => _open(url);
      _recognizers.add(recognizer);
      spans.add(
        TextSpan(
          text: url,
          recognizer: recognizer,
          style: TextStyle(
            color: widget.linkColor ?? OmniColors.chatPrimary,
            decoration: TextDecoration.underline,
            decorationColor: widget.linkColor ?? OmniColors.chatPrimary,
          ),
        ),
      );
      cursor = match.end;
    }
    if (cursor < widget.text.length) {
      spans.add(TextSpan(text: widget.text.substring(cursor)));
    }
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        style: OmniChatType.message.copyWith(color: widget.color),
        children: _spans,
      ),
    );
  }
}

class _ReplySwipe extends StatefulWidget {
  const _ReplySwipe({
    required this.child,
    required this.outbound,
    required this.enabled,
    this.onReply,
    this.onPin,
    this.onCopy,
    this.onCreateTask,
    this.onCreateOpportunity,
  });

  final Widget child;
  final bool outbound;
  final bool enabled;
  final VoidCallback? onReply;
  final VoidCallback? onPin;
  final VoidCallback? onCopy;
  final VoidCallback? onCreateTask;
  final VoidCallback? onCreateOpportunity;

  @override
  State<_ReplySwipe> createState() => _ReplySwipeState();
}

class _ReplySwipeState extends State<_ReplySwipe>
    with SingleTickerProviderStateMixin {
  static const _triggerDistance = 64.0;
  static const _maxDistance = 88.0;

  AnimationController? _controller;
  double _distance = 0;
  double _drag = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _reset() {
    _controller?.forward(from: 0).then((_) {
      if (mounted) setState(() => _distance = 0);
    });
  }

  void _onDragUpdate(DragUpdateDetails details) {
    _drag += details.delta.dx;
    final towardCenter = widget.outbound ? -_drag : _drag;
    setState(() {
      _distance = towardCenter.clamp(0, _maxDistance);
    });
  }

  void _onDragEnd(DragEndDetails details) {
    if (_distance >= _triggerDistance) {
      HapticFeedback.selectionClick();
      widget.onReply?.call();
    }
    _drag = 0;
    _reset();
  }

  /// Chạy sau khi hộp thoại đã đóng; cây có thể đã đổi (tin bị thu hồi, trang
  /// đóng) nên không chạm gì nếu state đã gỡ.
  VoidCallback _guarded(VoidCallback? action) => () {
    if (mounted) action?.call();
  };

  void _showActions() {
    HapticFeedback.selectionClick();
    showMessageActions(
      context: context,
      bubble: widget.child,
      outbound: widget.outbound,
      items: [
        if (widget.onReply != null)
          MessageActionItem(
            label: 'Trả lời',
            icon: Icons.reply_rounded,
            onTap: _guarded(widget.onReply),
          ),
        if (widget.onCopy != null)
          MessageActionItem(
            label: 'Sao chép',
            icon: Icons.copy_rounded,
            onTap: _guarded(widget.onCopy),
          ),
        if (widget.onPin != null)
          MessageActionItem(
            label: 'Ghim tin',
            icon: Icons.push_pin_outlined,
            onTap: _guarded(widget.onPin),
          ),
        if (widget.onCreateTask != null)
          MessageActionItem(
            label: 'Tạo việc từ tin này',
            icon: Icons.task_alt_rounded,
            onTap: _guarded(widget.onCreateTask),
          ),
        if (widget.onCreateOpportunity != null)
          MessageActionItem(
            label: 'Tạo cơ hội',
            icon: Icons.trending_up_rounded,
            onTap: _guarded(widget.onCreateOpportunity),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;

    final direction = widget.outbound ? -1.0 : 1.0;
    final progress = (_distance / _triggerDistance).clamp(0.0, 1.0);

    return RawGestureDetector(
      behavior: HitTestBehavior.translucent,
      gestures: {
        // 420ms như bản mẫu (mặc định của Flutter là 500). Kéo ngang thắng cuộc
        // đua nếu ngón tay đã đi trước khi đủ giờ, nên vuốt-để-trả-lời và cuộn
        // danh sách không bị bấm giữ nuốt.
        LongPressGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
              () => LongPressGestureRecognizer(
                duration: const Duration(milliseconds: 420),
              ),
              (recognizer) => recognizer.onLongPress = _showActions,
            ),
        HorizontalDragGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<
              HorizontalDragGestureRecognizer
            >(
              HorizontalDragGestureRecognizer.new,
              (recognizer) => recognizer
                ..onUpdate = _onDragUpdate
                ..onEnd = _onDragEnd,
            ),
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Align(
              alignment: widget.outbound
                  ? Alignment.centerRight
                  : Alignment.centerLeft,
              child: Padding(
                padding: EdgeInsets.only(
                  left: widget.outbound ? 0 : 14,
                  right: widget.outbound ? 14 : 0,
                ),
                child: Opacity(
                  opacity: progress,
                  child: Icon(
                    Icons.reply_rounded,
                    size: OmniIconSize.lg,
                    color: OmniColors.chatPrimary,
                  ),
                ),
              ),
            ),
          ),
          Transform.translate(
            offset: Offset(direction * _distance, 0),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}

class _QuotedMessage extends StatelessWidget {
  const _QuotedMessage({required this.message, this.onPrimary = false});

  final Message message;

  /// Nằm trong bong bóng tin ra nền primary: màu phải đảo sang trắng.
  final bool onPrimary;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = onPrimary ? Colors.white : OmniColors.chatPrimary;
    final bodyColor = onPrimary
        ? Colors.white.withValues(alpha: 0.85)
        : scheme.onSurfaceVariant;
    final author = message.replyToAuthorName ?? 'Tin nhắn trước đó';
    final text = message.replyToText?.trim();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.fromLTRB(8, 5, 8, 5),
      decoration: BoxDecoration(
        color: onPrimary
            ? Colors.white.withValues(alpha: 0.16)
            : scheme.onSurface.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(color: accent.withValues(alpha: 0.85), width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            author,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: OmniChatType.meta.copyWith(
              color: accent,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            text == null || text.isEmpty ? 'Tin nhắn được trích dẫn' : text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: OmniChatType.meta.copyWith(color: bodyColor),
          ),
        ],
      ),
    );
  }
}

class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.message, this.onRetry, this.onDiscard});

  final Message message;
  final VoidCallback? onRetry;
  final VoidCallback? onDiscard;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final failed = message.status == DeliveryStatus.failed;

    if (failed) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: OmniIconSize.sm,
                color: scheme.error,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  message.error ?? 'Gửi lỗi',
                  style: OmniType.micro.copyWith(color: scheme.error),
                ),
              ),
            ],
          ),
          if (onRetry != null || onDiscard != null)
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Wrap(
                spacing: 2,
                children: [
                  if (onRetry != null)
                    TextButton(
                      onPressed: onRetry,
                      style: TextButton.styleFrom(
                        minimumSize: const Size(48, 40),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('Gửi lại'),
                    ),
                  if (onDiscard != null)
                    TextButton(
                      onPressed: onDiscard,
                      style: TextButton.styleFrom(
                        minimumSize: const Size(48, 40),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        foregroundColor: scheme.onSurfaceVariant,
                      ),
                      child: const Text('Bỏ'),
                    ),
                ],
              ),
            ),
        ],
      );
    }

    // Time and tick now live inside the bubble, so a delivered message needs
    // nothing here at all — this line exists only to explain a failure.
    return const SizedBox.shrink();
  }
}

class _DeliveryReceipt extends StatelessWidget {
  const _DeliveryReceipt({
    required this.status,
    required this.fallbackColor,
    required this.showLabel,
    this.onPrimary = false,
  });

  final DeliveryStatus status;
  final Color fallbackColor;
  final bool showLabel;

  /// Trên bong bóng nền primary: "đã xem" là trắng, không phải xanh kênh.
  final bool onPrimary;

  @override
  Widget build(BuildContext context) {
    final read = status == DeliveryStatus.read;
    final failed = status == DeliveryStatus.failed;
    final color = read
        ? (onPrimary ? Colors.white : OmniColors.chatPrimary)
        : failed
        ? Theme.of(context).colorScheme.error
        : fallbackColor;
    final label = switch (status) {
      DeliveryStatus.queued => 'Đang gửi',
      DeliveryStatus.sent => 'Đã gửi',
      DeliveryStatus.delivered => 'Đã nhận',
      DeliveryStatus.read => 'Đã xem',
      DeliveryStatus.failed => 'Gửi lỗi',
      _ => 'Đã gửi',
    };
    final icon = switch (status) {
      DeliveryStatus.queued => Icons.schedule_rounded,
      DeliveryStatus.sent => Icons.check_rounded,
      DeliveryStatus.delivered || DeliveryStatus.read => Icons.done_all_rounded,
      DeliveryStatus.failed => Icons.error_outline_rounded,
      _ => Icons.check_rounded,
    };

    return Semantics(
      label: label,
      child: AnimatedSwitcher(
        duration: OmniDuration.base,
        reverseDuration: OmniDuration.fast,
        switchInCurve: Curves.easeOutBack,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: ScaleTransition(scale: animation, child: child),
        ),
        child: Row(
          key: ValueKey('delivery-receipt-${status.name}'),
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: OmniIconSize.sm, color: color),
            if (showLabel) ...[
              const SizedBox(width: 3),
              Text(
                label,
                style: OmniChatType.meta.copyWith(
                  color: color,
                  fontWeight: read ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Internal note. Deliberately unlike a message bubble — full width, amber,
/// labelled — so it can never be mistaken for something the customer saw.
class _NoteBubble extends StatelessWidget {
  const _NoteBubble({required this.message});

  final Message message;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final amber = OmniColors.warningTextOf(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: OmniSpacing.sm),
      child: FractionallySizedBox(
        widthFactor: 0.88,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: dark ? OmniColors.darkWarningSoft : OmniColors.noteSurface,
            borderRadius: OmniRadius.lgAll,
            border: Border.all(
              color: dark
                  ? OmniColors.warningTextDark.withValues(alpha: 0.4)
                  : OmniColors.noteBorder,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.sticky_note_2_outlined,
                    size: OmniIconSize.xs,
                    color: amber,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'GHI CHÚ NỘI BỘ',
                    style: OmniChatType.meta.copyWith(
                      color: amber,
                      // The one place bold is right: this label is the guard
                      // against a note being mistaken for a customer message.
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: OmniSpacing.sm),
              Text(message.text, style: OmniChatType.message),
              const SizedBox(height: OmniSpacing.sm),
              Text(
                'Bởi ${message.agentName ?? "bạn"} · ${Formatters.time(message.sentAt)}',
                style: OmniChatType.meta.copyWith(color: amber),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
