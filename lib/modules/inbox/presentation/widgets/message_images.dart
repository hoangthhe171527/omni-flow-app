/// Ảnh trong một tin nhắn: một ảnh, thư viện nhiều ảnh, và trình xem toàn màn.
///
/// Tách khỏi `message_bubble.dart` — xem ghi chú trong `message_link_preview.dart`.
library;

import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../design/tokens/tokens.dart';
import '../../domain/message.dart';

class MessageImageGallery extends StatelessWidget {
  const MessageImageGallery({
    super.key,
    required this.images,
    required this.heroPrefix,
  });

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
        transitionDuration: OmniDuration.base,
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
      fadeInDuration: OmniDuration.fast,
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
