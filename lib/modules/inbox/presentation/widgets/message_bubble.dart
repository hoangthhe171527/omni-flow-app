import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/utils/formatters.dart';
import '../../../../design/components/components.dart';
import '../../../../design/tokens/tokens.dart';
import '../../domain/message.dart';

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
            OmniColors.chatOutbound,
            OmniColors.chatOutboundDark,
          )
        : OmniColors.chat(
            context,
            OmniColors.chatInbound,
            OmniColors.chatInboundDark,
          );
    // Dark mode carries white text on both sides; light mode is dark-on-pale.
    final onBubble = failed
        ? scheme.onErrorContainer
        : dark
        ? Colors.white
        : scheme.onSurface;
    final metaColor = dark
        ? Colors.white.withValues(alpha: 0.55)
        : OmniColors.chatMeta;

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
          ),
        ],
        if (message.pinned) ...[
          const SizedBox(width: 5),
          Icon(Icons.push_pin_rounded, size: 13, color: color),
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
        borderRadius: BorderRadius.circular(18),
        // No shadow at all. The tinted canvas already separates the bubbles by
        // value, so the drop shadow was doing no work — it only fuzzed every
        // edge in the thread, which is what reads as cheap at this scale.
        boxShadow: null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (message.replyToMessageId != null)
            _QuotedMessage(message: message),
          if (files.isNotEmpty) ...[
            _FileAttachments(attachments: files),
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
            _MessageText(text: message.text, color: onBubble),
          if (message.text.isNotEmpty && _urlPattern.hasMatch(message.text))
            _LinkPreviewCard(
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
          _ImageGallery(images: images, heroPrefix: mediaHeroPrefix),
        if (videos.isNotEmpty) _VideoAttachments(attachments: videos),
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
                    size: 32,
                  )
                // Reserve the width so bubbles above stay in the same column.
                : const SizedBox(width: 32),
          );

    return _ReplySwipe(
      enabled: onReply != null,
      outbound: outbound,
      onReply: onReply,
      onPin: onPin,
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
                            size: 16,
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
                              style: const TextStyle(fontSize: 11),
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
  const _MessageText({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  State<_MessageText> createState() => _MessageTextState();
}

class _MessageTextState extends State<_MessageText> {
  final _recognizers = <TapGestureRecognizer>[];

  @override
  void dispose() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();

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
            color: OmniColors.chatPrimary,
            decoration: TextDecoration.underline,
            decorationColor: OmniColors.chatPrimary,
          ),
        ),
      );
      cursor = match.end;
    }
    if (cursor < widget.text.length) {
      spans.add(TextSpan(text: widget.text.substring(cursor)));
    }

    return Text.rich(
      TextSpan(
        style: OmniChatType.message.copyWith(color: widget.color),
        children: spans,
      ),
    );
  }
}

class _LinkPreviewCard extends StatefulWidget {
  const _LinkPreviewCard({required this.url});

  final String url;

  @override
  State<_LinkPreviewCard> createState() => _LinkPreviewCardState();
}

class _LinkPreviewCardState extends State<_LinkPreviewCard> {
  static final Map<String, Future<_LinkMetadata>> _metadataCache = {};
  static final Dio _previewClient = Dio(
    BaseOptions(
      connectTimeout: Duration(seconds: 4),
      receiveTimeout: Duration(seconds: 4),
      sendTimeout: Duration(seconds: 4),
      responseType: ResponseType.plain,
      headers: {'User-Agent': 'Viomni Link Preview'},
    ),
  );
  late final Future<_LinkMetadata> _metadata = _cachedMetadata(widget.url);

  Future<_LinkMetadata> _cachedMetadata(String url) {
    final existing = _metadataCache[url];
    if (existing != null) return existing;
    final future = _fetchMetadata(url);
    // Bound the in-memory cache so a long inbox session cannot retain an
    // unbounded number of one-off links.
    if (_metadataCache.length >= 40) {
      _metadataCache.remove(_metadataCache.keys.first);
    }
    _metadataCache[url] = future;
    return future;
  }

  Future<_LinkMetadata> _fetchMetadata(String rawUrl) async {
    final normalized = rawUrl.toLowerCase().startsWith('http')
        ? rawUrl
        : 'https://$rawUrl';
    final uri = Uri.tryParse(normalized);
    if (uri == null || !_isPreviewSafe(uri)) {
      final host = uri?.host;
      return _LinkMetadata(
        domain: host != null && host.isNotEmpty ? host : rawUrl,
      );
    }

    try {
      final response = await _previewClient.get<String>(normalized);
      // Metadata is near the head of normal pages. Avoid retaining/parsing a
      // multi-megabyte response when a server returns a large document.
      final rawHtml = response.data ?? '';
      final html = rawHtml.substring(
        0,
        rawHtml.length > 512 * 1024 ? 512 * 1024 : rawHtml.length,
      );
      String readMeta(String property) {
        final pattern = RegExp(
          "<meta[^>]+(?:property|name)=[\\\"']$property[\\\"'][^>]+content=[\\\"']([^\\\"']+)",
          caseSensitive: false,
        );
        return pattern.firstMatch(html)?.group(1) ?? '';
      }

      final title = readMeta('og:title');
      final description = readMeta('og:description');
      final image = readMeta('og:image');
      return _LinkMetadata(
        domain: uri.host,
        title: title.isNotEmpty ? title : uri.host,
        description: description,
        imageUrl: image,
      );
    } catch (_) {
      return _LinkMetadata(domain: uri.host, title: uri.host);
    }
  }

  static bool _isPreviewSafe(Uri uri) {
    if (uri.scheme != 'http' && uri.scheme != 'https') return false;
    final host = uri.host.toLowerCase();
    if (host.isEmpty || host == 'localhost' || host.endsWith('.local')) {
      return false;
    }
    final ipv4 = RegExp(r'^\d{1,3}(?:\.\d{1,3}){3}$');
    if (!ipv4.hasMatch(host)) return true;
    final parts = host.split('.').map(int.parse).toList();
    return parts[0] != 10 &&
        !(parts[0] == 172 && parts[1] >= 16 && parts[1] <= 31) &&
        !(parts[0] == 192 && parts[1] == 168) &&
        parts[0] != 127 &&
        !(parts[0] == 169 && parts[1] == 254);
  }

  Future<void> _open() async {
    final raw = widget.url.toLowerCase().startsWith('http')
        ? widget.url
        : 'https://${widget.url}';
    await launchUrl(Uri.parse(raw), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return FutureBuilder<_LinkMetadata>(
      future: _metadata,
      builder: (context, snapshot) {
        final meta = snapshot.data ?? _LinkMetadata(domain: widget.url);
        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Material(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: _open,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (meta.imageUrl != null && meta.imageUrl!.isNotEmpty)
                    AspectRatio(
                      aspectRatio: 1.9,
                      child: CachedNetworkImage(
                        imageUrl: meta.imageUrl!,
                        fit: BoxFit.cover,
                        errorWidget: (_, _, _) => const SizedBox.shrink(),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 9, 12, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          meta.title ?? meta.domain,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: OmniType.bodyStrong,
                        ),
                        if (meta.description != null &&
                            meta.description!.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            meta.description!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: OmniType.caption.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                        const SizedBox(height: 3),
                        Text(
                          meta.domain,
                          style: OmniType.caption.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _LinkMetadata {
  const _LinkMetadata({
    required this.domain,
    this.title,
    this.description,
    this.imageUrl,
  });

  final String domain;
  final String? title;
  final String? description;
  final String? imageUrl;
}

class _ReplySwipe extends StatefulWidget {
  const _ReplySwipe({
    required this.child,
    required this.outbound,
    required this.enabled,
    this.onReply,
    this.onPin,
  });

  final Widget child;
  final bool outbound;
  final bool enabled;
  final VoidCallback? onReply;
  final VoidCallback? onPin;

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

  Future<void> _showActions() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 520),
      builder: (context) => SafeArea(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 220),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.only(bottom: 8),
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Text(
                  'Thao tác tin nhắn',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              if (widget.onReply != null)
                ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  leading: const Icon(Icons.reply_rounded),
                  title: const Text(
                    'Trả lời',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => Navigator.pop(context, 'reply'),
                ),
              if (widget.onPin != null)
                ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  leading: const Icon(Icons.push_pin_outlined),
                  title: const Text(
                    'Ghim hoặc bỏ ghim',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => Navigator.pop(context, 'pin'),
                ),
            ],
          ),
        ),
      ),
    );
    if (!mounted) return;
    if (action == 'reply') widget.onReply?.call();
    if (action == 'pin') widget.onPin?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;

    final direction = widget.outbound ? -1.0 : 1.0;
    final progress = (_distance / _triggerDistance).clamp(0.0, 1.0);

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onLongPress: _showActions,
      onHorizontalDragUpdate: _onDragUpdate,
      onHorizontalDragEnd: _onDragEnd,
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
                    size: 22,
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
  const _QuotedMessage({required this.message});

  final Message message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final author = message.replyToAuthorName ?? 'Tin nhắn trước đó';
    final text = message.replyToText?.trim();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.fromLTRB(8, 5, 8, 5),
      decoration: BoxDecoration(
        color: scheme.onSurface.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(
            color: OmniColors.chatPrimary.withValues(alpha: 0.85),
            width: 3,
          ),
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
              color: OmniColors.chatPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            text == null || text.isEmpty ? 'Tin nhắn được trích dẫn' : text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: OmniChatType.meta.copyWith(color: scheme.onSurfaceVariant),
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
              Icon(Icons.error_outline_rounded, size: 15, color: scheme.error),
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
  });

  final DeliveryStatus status;
  final Color fallbackColor;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final read = status == DeliveryStatus.read;
    final failed = status == DeliveryStatus.failed;
    final color = read
        ? OmniColors.chatPrimary
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
        duration: const Duration(milliseconds: 220),
        reverseDuration: const Duration(milliseconds: 140),
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
            Icon(icon, size: 16, color: color),
            if (showLabel) ...[
              const SizedBox(width: 3),
              Text(
                label,
                style: OmniChatType.meta.copyWith(
                  color: color,
                  fontSize: 10.5,
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
    const amber = OmniColors.warning;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: OmniSpacing.sm),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(OmniSpacing.md),
        decoration: BoxDecoration(
          color: amber.withValues(alpha: 0.09),
          borderRadius: OmniRadius.mdAll,
          border: Border.all(color: amber.withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.sticky_note_2_outlined,
                  size: 14,
                  color: amber,
                ),
                const SizedBox(width: 5),
                Text(
                  'GHI CHÚ NỘI BỘ',
                  style: OmniChatType.meta.copyWith(
                    color: amber,
                    // The one place bold is right: this label is the guard
                    // against a note being mistaken for a customer message.
                    fontWeight: FontWeight.w700,
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
              style: OmniChatType.meta.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImageGallery extends StatelessWidget {
  const _ImageGallery({required this.images, required this.heroPrefix});

  final List<MessageAttachment> images;
  final String heroPrefix;

  @override
  Widget build(BuildContext context) {
    final availableWidth = MediaQuery.sizeOf(context).width;
    final width = math.min(availableWidth * 0.72, 292.0);

    if (images.length == 1) {
      return _SingleImage(
        image: images.first,
        width: width,
        heroTag: _heroTag(0),
        onTap: () => _openViewer(context, 0),
      );
    }

    return _StackedImageCarousel(
      images: images,
      width: width,
      heroTagFor: _heroTag,
      onOpen: (index) => _openViewer(context, index),
    );
  }

  String _heroTag(int index) => '$heroPrefix-image-$index';

  void _openViewer(BuildContext context, int index) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: true,
        barrierColor: Colors.black,
        transitionDuration: const Duration(milliseconds: 220),
        reverseTransitionDuration: const Duration(milliseconds: 180),
        pageBuilder: (_, animation, _) => FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: _ImageViewer(
            images: images,
            initialIndex: index,
            heroPrefix: heroPrefix,
          ),
        ),
      ),
    );
  }
}

class _StackedImageCarousel extends StatefulWidget {
  const _StackedImageCarousel({
    required this.images,
    required this.width,
    required this.heroTagFor,
    required this.onOpen,
  });

  final List<MessageAttachment> images;
  final double width;
  final String Function(int index) heroTagFor;
  final ValueChanged<int> onOpen;

  @override
  State<_StackedImageCarousel> createState() => _StackedImageCarouselState();
}

class _StackedImageCarouselState extends State<_StackedImageCarousel> {
  static const _viewportFraction = 0.88;

  late final PageController _controller;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController(viewportFraction: _viewportFraction);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cardWidth = widget.width * _viewportFraction;
    final cardHeight = cardWidth * 0.78;
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      label: '${widget.images.length} ảnh, vuốt ngang để xem',
      child: SizedBox(
        key: const ValueKey('message-image-gallery'),
        width: widget.width,
        height: cardHeight + 20,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            PageView.builder(
              key: const ValueKey('message-image-inline-page-view'),
              controller: _controller,
              clipBehavior: Clip.none,
              padEnds: false,
              itemCount: widget.images.length,
              onPageChanged: (index) => setState(() => _index = index),
              itemBuilder: (context, index) => AnimatedBuilder(
                animation: _controller,
                child: Padding(
                  padding: const EdgeInsets.only(right: 10, top: 7, bottom: 7),
                  child: DecoratedBox(
                    key: ValueKey('message-image-card-$index'),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: scheme.shadow.withValues(alpha: 0.18),
                          blurRadius: 16,
                          offset: const Offset(0, 7),
                        ),
                        BoxShadow(
                          color: scheme.surface.withValues(alpha: 0.22),
                          blurRadius: 0,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: _GalleryTile(
                      key: ValueKey('message-image-tile-$index'),
                      image: widget.images[index],
                      heroTag: widget.heroTagFor(index),
                      onTap: () => widget.onOpen(index),
                    ),
                  ),
                ),
                builder: (context, child) {
                  final page = _controller.hasClients
                      ? (_controller.page ?? _index.toDouble())
                      : _index.toDouble();
                  final delta = (index - page).clamp(-1.0, 1.0);
                  final distance = delta.abs();

                  // The next photograph stays visibly tucked under the current
                  // one. A tiny tilt + lower baseline makes the stack feel like
                  // loose prints, while the real PageView preserves the native
                  // horizontal swipe instead of faking it with decoration.
                  return Transform.translate(
                    offset: Offset(
                      delta > 0 ? -5 * distance : 3 * distance,
                      7 * distance,
                    ),
                    child: Transform.rotate(
                      angle: delta * 0.022,
                      child: Transform.scale(
                        alignment: delta >= 0
                            ? Alignment.centerLeft
                            : Alignment.centerRight,
                        scale: 1 - (distance * 0.045),
                        child: child,
                      ),
                    ),
                  );
                },
              ),
            ),
            Positioned(
              right: (widget.width * (1 - _viewportFraction)) + 14,
              bottom: 16,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.56),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    child: Text(
                      '${_index + 1} / ${widget.images.length}',
                      key: const ValueKey('message-image-inline-counter'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        height: 1,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SingleImage extends StatelessWidget {
  const _SingleImage({
    required this.image,
    required this.width,
    required this.heroTag,
    required this.onTap,
  });

  final MessageAttachment image;
  final double width;
  final String heroTag;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Mở ảnh',
      child: GestureDetector(
        onTap: onTap,
        child: Hero(
          tag: heroTag,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: width,
                maxWidth: width,
                minHeight: 150,
                maxHeight: 360,
              ),
              child: _NetworkMediaImage(url: image.url, fit: BoxFit.cover),
            ),
          ),
        ),
      ),
    );
  }
}

class _GalleryTile extends StatelessWidget {
  const _GalleryTile({
    super.key,
    required this.image,
    required this.heroTag,
    required this.onTap,
  });

  final MessageAttachment image;
  final String heroTag;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Hero(
          tag: heroTag,
          child: _NetworkMediaImage(url: image.url, fit: BoxFit.cover),
        ),
      ),
    );
  }
}

class _NetworkMediaImage extends StatefulWidget {
  const _NetworkMediaImage({required this.url, required this.fit});

  final String url;
  final BoxFit fit;

  @override
  State<_NetworkMediaImage> createState() => _NetworkMediaImageState();
}

class _NetworkMediaImageState extends State<_NetworkMediaImage> {
  int _attempt = 0;

  Future<void> _retry() async {
    // A failed CDN response must not poison the next attempt in either Flutter's
    // memory cache or the persistent cache manager.
    await CachedNetworkImage.evictFromCache(widget.url);
    if (!mounted) return;
    setState(() => _attempt++);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final logicalWidth = MediaQuery.sizeOf(context).width;
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    final decodeWidth = math.min((logicalWidth * pixelRatio).round(), 1440);

    return CachedNetworkImage(
      key: ValueKey('${widget.url}#$_attempt'),
      imageUrl: widget.url,
      fit: widget.fit,
      fadeInDuration: const Duration(milliseconds: 140),
      fadeOutDuration: const Duration(milliseconds: 80),
      useOldImageOnUrlChange: true,
      memCacheWidth: decodeWidth,
      maxWidthDiskCache: 1440,
      progressIndicatorBuilder: (_, _, progress) => ColoredBox(
        color: scheme.surfaceContainerHighest,
        child: Center(
          child: SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(
              // Some CDNs omit Content-Length. Keep that state determinate so
              // an off-screen loading tile does not schedule animation frames
              // forever; PageView already builds/caches the next tile ahead.
              value: progress.progress ?? 0,
              strokeWidth: 2,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.45),
            ),
          ),
        ),
      ),
      errorWidget: (_, _, _) => ColoredBox(
        color: scheme.surfaceContainerHighest,
        child: Center(
          child: IconButton(
            tooltip: 'Táº£i láº¡i áº£nh',
            onPressed: _retry,
            icon: Icon(Icons.refresh_rounded, color: scheme.onSurfaceVariant),
          ),
        ),
      ),
    );
  }
}

class _ImageViewer extends StatefulWidget {
  const _ImageViewer({
    required this.images,
    required this.initialIndex,
    required this.heroPrefix,
  });

  final List<MessageAttachment> images;
  final int initialIndex;
  final String heroPrefix;

  @override
  State<_ImageViewer> createState() => _ImageViewerState();
}

class _ImageViewerState extends State<_ImageViewer> {
  late final PageController _controller;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const ValueKey('message-image-viewer'),
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: widget.images.length,
            onPageChanged: (index) => setState(() => _index = index),
            itemBuilder: (context, index) => Center(
              child: Hero(
                tag: '${widget.heroPrefix}-image-$index',
                child: InteractiveViewer(
                  // Let PageView own one-finger horizontal drags so moving
                  // between photos stays as effortless as Messenger/Zalo.
                  // Pinch-to-zoom remains available without stealing swipes.
                  panEnabled: false,
                  minScale: 1,
                  maxScale: 4,
                  child: SizedBox(
                    width: double.infinity,
                    height: MediaQuery.sizeOf(context).height,
                    child: _NetworkMediaImage(
                      url: widget.images[index].url,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Đóng',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                    color: Colors.white,
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black.withValues(alpha: 0.34),
                    ),
                  ),
                  const Spacer(),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.42),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 7,
                      ),
                      child: Text(
                        '${_index + 1} / ${widget.images.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FileAttachments extends StatelessWidget {
  const _FileAttachments({required this.attachments});

  final List<MessageAttachment> attachments;

  Future<void> _open(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final attachment in attachments)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Material(
              color: scheme.onSurface.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(9),
              child: InkWell(
                onTap: () => _open(attachment.url),
                borderRadius: BorderRadius.circular(9),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 7,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.insert_drive_file_outlined,
                        size: 18,
                        color: OmniColors.chatPrimary,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          attachment.name ?? 'Tệp đính kèm',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: OmniType.caption.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 7),
                      Icon(
                        Icons.download_rounded,
                        size: 17,
                        color: scheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _VideoAttachments extends StatelessWidget {
  const _VideoAttachments({required this.attachments});

  final List<MessageAttachment> attachments;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final attachment in attachments)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: _InlineVideo(url: attachment.url, name: attachment.name),
        ),
    ],
  );
}

class _InlineVideo extends StatefulWidget {
  const _InlineVideo({required this.url, this.name});

  final String url;
  final String? name;

  @override
  State<_InlineVideo> createState() => _InlineVideoState();
}

class _InlineVideoState extends State<_InlineVideo> {
  late final VideoPlayerController _controller =
      VideoPlayerController.networkUrl(Uri.parse(widget.url));

  @override
  void initState() {
    super.initState();
    _controller.initialize().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (!_controller.value.isInitialized) {
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: ColoredBox(
          color: scheme.onSurface.withValues(alpha: 0.08),
          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          AspectRatio(
            aspectRatio: _controller.value.aspectRatio,
            child: VideoPlayer(_controller),
          ),
          VideoProgressIndicator(
            _controller,
            allowScrubbing: true,
            colors: VideoProgressColors(
              playedColor: OmniColors.chatPrimary,
              bufferedColor: Colors.white54,
              backgroundColor: Colors.black38,
            ),
          ),
          Center(
            child: IconButton.filled(
              tooltip: _controller.value.isPlaying ? 'Tạm dừng' : 'Phát video',
              onPressed: () => setState(() {
                _controller.value.isPlaying
                    ? _controller.pause()
                    : _controller.play();
              }),
              icon: Icon(
                _controller.value.isPlaying
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
