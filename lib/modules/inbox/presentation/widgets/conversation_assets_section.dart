import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/utils/web_url.dart';
import '../../../../design/components/components.dart';
import '../../../../design/platform/omni_motion_scope.dart';
import '../../../../design/tokens/tokens.dart';
import '../../data/inbox_api.dart';
import '../../domain/message.dart';

/// Nội dung thẻ "Ảnh, tệp, liên kết" của trang Thông tin (`ThreadInfo.dc.html`):
/// tab chia đoạn `Ảnh · N` / `Tệp · N` / `Link · N` với vệt trắng trượt, lưới
/// ảnh 4 cột khe 4 bo 4, danh sách tệp / liên kết.
class ConversationAssetsSection extends StatefulWidget {
  const ConversationAssetsSection({super.key, required this.assets});

  final AsyncValue<ConversationAssets> assets;

  @override
  State<ConversationAssetsSection> createState() =>
      _ConversationAssetsSectionState();
}

class _ConversationAssetsSectionState extends State<ConversationAssetsSection> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return widget.assets.when(
      loading: () => const OmniSkeletonBox(height: 160),
      error: (_, _) => Padding(
        padding: const EdgeInsets.all(OmniSpacing.md),
        child: Text(
          'Không tải được nội dung đã chia sẻ.',
          style: OmniType.caption.copyWith(color: scheme.onSurfaceVariant),
        ),
      ),
      data: (assets) {
        final links = assets.links.toSet().toList();
        return Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
          child: Column(
            children: [
              OmniSegmented(
                labels: [
                  'Ảnh · ${assets.media.length}',
                  'Tệp · ${assets.files.length}',
                  'Link · ${links.length}',
                ],
                index: _tab,
                onChanged: (value) {
                  HapticFeedback.selectionClick();
                  setState(() => _tab = value);
                },
              ),
              const SizedBox(height: 8),
              if (OmniMotion.enabled(context))
                AnimatedSize(
                  duration: OmniMotion.of(context).fast,
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: _tab == 0
                      ? _MediaGrid(items: assets.media)
                      : _tab == 1
                      ? _FileList(files: assets.files)
                      : _LinkList(links: links),
                )
              else
                _tab == 0
                    ? _MediaGrid(items: assets.media)
                    : _tab == 1
                    ? _FileList(files: assets.files)
                    : _LinkList(links: links),
            ],
          ),
        );
      },
    );
  }
}

class _MediaGrid extends StatelessWidget {
  const _MediaGrid({required this.items});

  final List<MessageAttachment> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const _AssetEmpty(label: 'Chưa có ảnh hoặc video');
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: items.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          crossAxisSpacing: 4,
          mainAxisSpacing: 4,
        ),
        itemBuilder: (_, index) => ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: GestureDetector(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) =>
                    _MediaViewerPage(items: items, initialIndex: index),
              ),
            ),
            child: _AssetTile(item: items[index]),
          ),
        ),
      ),
    );
  }
}

class _LinkList extends StatelessWidget {
  const _LinkList({required this.links});

  final List<String> links;

  @override
  Widget build(BuildContext context) {
    if (links.isEmpty) return const _AssetEmpty(label: 'Chưa có liên kết');
    return _AssetRows(
      rows: [
        for (final link in links)
          OmniGroupRow(
            icon: Icons.link_rounded,
            title: link,
            maxTitleLines: 1,
            chevron: false,
            onTap: () => _openUrl(link),
          ),
      ],
    );
  }
}

/// Danh sách dòng trong thẻ của nhóm: vạch thụt sau ô icon, không viền.
class _AssetRows extends StatelessWidget {
  const _AssetRows({required this.rows});

  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    final line = Theme.of(
      context,
    ).colorScheme.outlineVariant.withValues(alpha: .7);
    return Column(
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) Divider(height: 1, thickness: 1, indent: 54, color: line),
          rows[i],
        ],
      ],
    );
  }
}

class _MediaViewerPage extends StatefulWidget {
  const _MediaViewerPage({required this.items, required this.initialIndex});

  final List<MessageAttachment> items;
  final int initialIndex;

  @override
  State<_MediaViewerPage> createState() => _MediaViewerPageState();
}

class _MediaViewerPageState extends State<_MediaViewerPage> {
  late final PageController _controller = PageController(
    initialPage: widget.initialIndex,
  );
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${_index + 1} / ${widget.items.length}'),
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: widget.items.length,
        onPageChanged: (index) => setState(() => _index = index),
        itemBuilder: (_, index) => Center(
          child: InteractiveViewer(
            minScale: 1,
            maxScale: 4,
            child: widget.items[index].isVideo
                ? _PlayableVideo(url: widget.items[index].url)
                : CachedNetworkImage(
                    imageUrl: widget.items[index].url,
                    fit: BoxFit.contain,
                    width: double.infinity,
                    memCacheWidth: 1440,
                    errorWidget: (_, _, _) => const Icon(
                      Icons.broken_image_outlined,
                      color: Colors.white54,
                      size: OmniIconSize.hero,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _AssetTile extends StatelessWidget {
  const _AssetTile({required this.item});

  final MessageAttachment item;

  @override
  Widget build(BuildContext context) {
    if (!item.isVideo) {
      return CachedNetworkImage(
        imageUrl: item.url,
        fit: BoxFit.cover,
        memCacheWidth: 420,
        errorWidget: (_, _, _) => const ColoredBox(
          color: Colors.black12,
          child: Icon(Icons.broken_image_outlined),
        ),
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Colors.black87),
        const Center(
          child: Icon(
            Icons.play_circle_fill_rounded,
            color: Colors.white,
            size: OmniIconSize.lg,
          ),
        ),
        Positioned(
          left: 4,
          right: 4,
          bottom: 3,
          child: Text(
            item.name ?? 'Video',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: OmniType.micro.copyWith(color: Colors.white),
          ),
        ),
      ],
    );
  }
}

class _PlayableVideo extends StatefulWidget {
  const _PlayableVideo({required this.url});
  final String url;

  @override
  State<_PlayableVideo> createState() => _PlayableVideoState();
}

class _PlayableVideoState extends State<_PlayableVideo>
    with WidgetsBindingObserver {
  /// Chỉ dựng decoder + mở luồng mạng khi người dùng bấm phát: lướt qua một
  /// video trong trình xem không được tốn data và bộ giải mã.
  VideoPlayerController? _controller;
  bool _activated = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  void _activate() {
    if (_activated) return;
    final controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    setState(() {
      _activated = true;
      _controller = controller;
    });
    controller.initialize().then((_) {
      if (!mounted) return;
      setState(() {});
      unawaited(controller.play());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Vào nền thì dừng: không tiếp tục giải mã/tải luồng cho màn không ai nhìn.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      final controller = _controller;
      if (controller != null && controller.value.isPlaying) {
        unawaited(controller.pause());
        if (mounted) setState(() {});
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (!_activated) {
      return Center(
        child: IconButton.filled(
          onPressed: _activate,
          tooltip: 'Phát video',
          iconSize: 40,
          icon: const Icon(Icons.play_arrow_rounded),
        ),
      );
    }
    if (controller == null || !controller.value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator.adaptive(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      );
    }
    return Center(
      child: AspectRatio(
        aspectRatio: controller.value.aspectRatio,
        child: Stack(
          alignment: Alignment.center,
          children: [
            VideoPlayer(controller),
            IconButton.filled(
              onPressed: () => setState(() {
                controller.value.isPlaying
                    ? controller.pause()
                    : controller.play();
              }),
              icon: Icon(
                controller.value.isPlaying
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FileList extends StatelessWidget {
  const _FileList({required this.files});

  final List<MessageAttachment> files;

  @override
  Widget build(BuildContext context) {
    if (files.isEmpty) return const _AssetEmpty(label: 'Chưa có file');
    return _AssetRows(
      rows: [
        for (final file in files)
          OmniGroupRow(
            icon: Icons.insert_drive_file_outlined,
            title: file.name ?? 'Tệp đính kèm',
            maxTitleLines: 1,
            trailing: const Icon(Icons.download_rounded, size: 20),
            onTap: () => _openUrl(file.url),
          ),
      ],
    );
  }
}

class _AssetEmpty extends StatelessWidget {
  const _AssetEmpty({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: OmniSpacing.lg),
    child: Center(
      child: Text(
        label,
        style: OmniType.caption.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    ),
  );
}

Future<void> _openUrl(String raw) async {
  final value = raw.toLowerCase().startsWith('http') ? raw : 'https://$raw';
  // Tệp/link trong hội thoại là dữ liệu của khách: chỉ mở http/https.
  final uri = webUriOrNull(value);
  if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
}
