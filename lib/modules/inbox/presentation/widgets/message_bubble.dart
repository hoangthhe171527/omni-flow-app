import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

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
    final files = message.attachments
        .where((attachment) => !attachment.isImage)
        .toList();
    final hasBubbleContent =
        message.recalled || message.text.isNotEmpty || files.isNotEmpty;
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
      ],
    );

    final bubble = Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * 0.76,
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
            Text(
              message.text,
              style: OmniChatType.message.copyWith(color: onBubble),
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

    return Padding(
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
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline_rounded, size: 13, color: scheme.error),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              message.error ?? 'Gửi lỗi',
              style: OmniType.micro.copyWith(color: scheme.error),
            ),
          ),
          if (onRetry != null)
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Gửi lại'),
            ),
          if (onDiscard != null)
            TextButton(
              onPressed: onDiscard,
              style: TextButton.styleFrom(
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                foregroundColor: scheme.onSurfaceVariant,
              ),
              child: const Text('Bỏ'),
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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final attachment in attachments)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.attach_file_rounded,
                  size: 15,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    attachment.name ?? 'Tệp đính kèm',
                    overflow: TextOverflow.ellipsis,
                    style: OmniType.caption,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
