import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/utils/save_image_to_gallery.dart';
import '../tokens/tokens.dart';
import 'omni_glass.dart';
import 'omni_top_bar.dart';

/// Một ảnh trong khung xem: URL, tên (tên tệp khi lưu), dòng phụ (thuộc việc nào, ai, lúc nào).
class OmniViewerImage {
  const OmniViewerImage({required this.url, this.name, this.caption});
  final String url;
  final String? name;
  final String? caption;
}

/// Mở khung xem ảnh toàn màn ngay trên màn đang đứng (rà soát 23/11/2026): vuốt ngang đổi
/// ảnh, chụm hai ngón phóng to, Lưu ảnh vào thư viện máy. Đóng là về đúng chỗ cũ — không
/// mở trình duyệt. Dựng từ khung xem ảnh của Hộp thư (`message_images.dart`).
Future<void> openOmniImageViewer(
  BuildContext context, {
  required List<OmniViewerImage> images,
  int initialIndex = 0,
}) {
  final usable = images.where((i) => i.url.isNotEmpty).toList();
  if (usable.isEmpty) return Future.value();
  final picked = initialIndex >= 0 && initialIndex < images.length
      ? images[initialIndex]
      : null;
  final start = picked == null
      ? 0
      : usable.indexOf(picked).clamp(0, usable.length - 1);
  return Navigator.of(context).push(
    PageRouteBuilder<void>(
      opaque: true,
      barrierColor: Colors.black,
      transitionDuration: OmniDuration.base,
      reverseTransitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (_, animation, _) => FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: OmniImageViewer(images: usable, initialIndex: start),
      ),
    ),
  );
}

class OmniImageViewer extends StatefulWidget {
  const OmniImageViewer({
    super.key,
    required this.images,
    this.initialIndex = 0,
  });

  final List<OmniViewerImage> images;
  final int initialIndex;

  @override
  State<OmniImageViewer> createState() => _OmniImageViewerState();
}

class _OmniImageViewerState extends State<OmniImageViewer> {
  late final PageController _controller;
  late int _index;
  bool _saving = false;

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

  Future<void> _save() async {
    if (_saving) return;
    final image = widget.images[_index];
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await saveNetworkImageToGallery(image.url, name: image.name);
      messenger.showSnackBar(
        const SnackBar(content: Text('Đã lưu ảnh vào thư viện')),
      );
    } on SaveImageException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final image = widget.images[_index];
    final count = widget.images.length;
    final caption = [
      if ((image.name ?? '').isNotEmpty) image.name!,
      if ((image.caption ?? '').isNotEmpty) image.caption!,
    ];

    return Scaffold(
      key: const ValueKey('omni-image-viewer'),
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: count,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, i) => Center(
              child: InteractiveViewer(
                // PageView giữ thao tác vuốt một ngón để đổi ảnh nhẹ như Messenger/Zalo;
                // chụm hai ngón vẫn phóng to được.
                panEnabled: false,
                minScale: 1,
                maxScale: 4,
                child: SizedBox(
                  width: double.infinity,
                  height: MediaQuery.sizeOf(context).height,
                  child: CachedNetworkImage(
                    imageUrl: widget.images[i].url,
                    fit: BoxFit.contain,
                    placeholder: (_, _) => const Center(
                      child: SizedBox.square(
                        dimension: 28,
                        child: CircularProgressIndicator(strokeWidth: 2.4),
                      ),
                    ),
                    errorWidget: (_, _, _) => Center(
                      child: Text(
                        'Không tải được ảnh này',
                        style: OmniType.body.copyWith(color: Colors.white70),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Thanh trên: Đóng · bộ đếm.
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: SizedBox(
                height: 44,
                child: Row(
                  children: [
                    OmniGlassCircle(
                      child: IconButton(
                        tooltip: 'Đóng',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints.tightFor(
                          width: 44,
                          height: 44,
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(
                          LucideIcons.x,
                          size: OmniIconSize.md,
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (count > 1)
                      OmniGlass(
                        blur: false,
                        radius: 22,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        child: Text(
                          '${_index + 1} / $count',
                          style: OmniType.caption.copyWith(
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurface,
                            fontFeatures: OmniType.tabular,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          // Đáy (vùng ngón cái): chú thích · Lưu ảnh.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (caption.isNotEmpty) ...[
                      Text(
                        caption.first,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: OmniType.body.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (caption.length > 1)
                        Text(
                          caption[1],
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: OmniType.caption.copyWith(
                            color: Colors.white70,
                          ),
                        ),
                      const SizedBox(height: 12),
                    ],
                    Center(
                      child: OmniGlass(
                        blur: false,
                        radius: 22,
                        child: TextButton.icon(
                          onPressed: _saving ? null : _save,
                          style: TextButton.styleFrom(
                            minimumSize: const Size(0, 44),
                            padding: const EdgeInsets.symmetric(horizontal: 18),
                            foregroundColor: scheme.onSurface,
                          ),
                          icon: _saving
                              ? const SizedBox.square(
                                  dimension: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(LucideIcons.download, size: 18),
                          label: const Text('Lưu ảnh'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
