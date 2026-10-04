/// Ảnh trong một tin nhắn: một ảnh, thư viện nhiều ảnh, và trình xem toàn màn.
///
/// Tách khỏi `message_bubble.dart` — xem ghi chú trong `message_link_preview.dart`.
library;

import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../design/tokens/tokens.dart';
import '../../../../core/utils/media_url.dart';
import '../../domain/message.dart';

/// Nơi ảnh trong tin báo "tải không được" (MS-I24).
///
/// Link media Hộp thư có chữ ký hết hạn sau 12 giờ; màn chat mở lâu hơn thế
/// thì ảnh trả 403. Màn chat bọc danh sách tin bằng scope này và tải lại tin
/// (URL ký mới) khi được báo. Không có scope (xem trước, trình xem toàn màn)
/// thì không làm gì — ảnh vẫn có nút tải lại riêng.
class MediaReloadScope extends InheritedWidget {
  const MediaReloadScope({
    super.key,
    required this.onLoadError,
    this.onUserRetry,
    required super.child,
  });

  /// Ảnh tự lỗi khi tải (thường là link quá hạn) — màn chat có thời gian nghỉ.
  final VoidCallback onLoadError;

  /// Người dùng bấm "Tải lại ảnh": lấy URL ký mới ngay, không chờ thời gian
  /// nghỉ. Không đặt thì dùng [onLoadError].
  final VoidCallback? onUserRetry;

  /// Không đăng ký phụ thuộc: chỉ gọi lúc ảnh lỗi, không cần vẽ lại theo.
  static VoidCallback? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<MediaReloadScope>()?.onLoadError;

  static VoidCallback? userRetryOf(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<MediaReloadScope>();
    return scope?.onUserRetry ?? scope?.onLoadError;
  }

  @override
  bool updateShouldNotify(MediaReloadScope oldWidget) => false;
}

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
                      style: OmniType.micro.copyWith(
                        color: Colors.white,
                        height: 1,
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

  /// Đã báo lỗi tải cho URL hiện tại chưa — mỗi URL báo một lần, để vẽ lại
  /// (cuộn, gõ phím) không kéo theo một lượt tải lại tin nữa.
  bool _reported = false;

  /// Ảnh vừa gửi mang URL nguyên văn của server (APP-I1); đổi host tại chỗ vẽ
  /// để môi trường dev (host khác APP_URL) vẫn hiện được. URL đã resolve thì
  /// resolve lại không đổi. Query (`expires`/`signature` của link ký, MS-I24)
  /// được giữ nguyên.
  String get _url => resolveMediaUrl(widget.url);

  /// Khoá cache và khoá widget: URL bỏ `expires`/`signature`. Chữ ký đổi theo
  /// giờ — không bỏ thì mỗi lượt làm mới tin là ảnh nháy về spinner, tải lại
  /// từ mạng và thêm một bản vào cache đĩa.
  String get _cacheKey => mediaCacheKey(_url);

  @override
  void didUpdateWidget(covariant _NetworkMediaImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      // Ảnh đã hỏng với URL cũ: khoá cache giữ nguyên nên Image không tự tải
      // lại — đổi lượt để dựng mới với URL ký mới. Ảnh đang hiện tốt thì giữ
      // nguyên, không nháy.
      if (_reported) _attempt++;
      // URL mới được báo lại nếu cũng hỏng.
      _reported = false;
    }
  }

  void _onLoadError(Object _) {
    if (_reported || !mounted) return;
    _reported = true;
    MediaReloadScope.maybeOf(context)?.call();
  }

  Future<void> _retry() async {
    // Link có thể đã quá hạn: thử lại cùng URL chỉ nhận 403 lần nữa. Nhờ màn
    // chat lấy URL ký mới trước (tin về thì didUpdateWidget dựng lại ảnh).
    _reported = true;
    MediaReloadScope.userRetryOf(context)?.call();
    // A failed CDN response must not poison the next attempt in either Flutter's
    // memory cache or the persistent cache manager.
    try {
      await CachedNetworkImage.evictFromCache(_url, cacheKey: _cacheKey);
    } catch (_) {
      // Không xoá được cache thì vẫn thử lại.
    }
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
      key: ValueKey('$_cacheKey#$_attempt'),
      imageUrl: _url,
      cacheKey: _cacheKey,
      fit: widget.fit,
      fadeInDuration: OmniDuration.fast,
      fadeOutDuration: const Duration(milliseconds: 80),
      useOldImageOnUrlChange: true,
      // Link ký hết hạn (403 sau 12 giờ) → báo màn chat tải lại tin để lấy URL
      // ký mới. Nút "tải lại ảnh" bên dưới vẫn còn cho lỗi mạng thường.
      errorListener: _onLoadError,
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
            tooltip: 'Tải lại ảnh',
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
                        style: OmniType.caption.copyWith(color: Colors.white),
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
