import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

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
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
          child: Column(
            children: [
              _AssetSegments(
                labels: [
                  'Ảnh · ${assets.media.length}',
                  'Tệp · ${assets.files.length}',
                  'Link · ${links.length}',
                ],
                selected: _tab,
                onChanged: (value) => setState(() => _tab = value),
              ),
              const SizedBox(height: 8),
              if (_tab == 0)
                _MediaGrid(items: assets.media)
              else if (_tab == 1)
                _FileList(files: assets.files)
              else
                _LinkList(links: links),
            ],
          ),
        );
      },
    );
  }
}

/// Ba đoạn nền xám, vệt trắng trượt theo đoạn đang chọn (như `_Segments` của
/// bộ lọc hộp thư). Cao 44 để đạt vùng chạm; giảm chuyển động thì nhảy ngay.
class _AssetSegments extends StatelessWidget {
  const _AssetSegments({
    required this.labels,
    required this.selected,
    required this.onChanged,
  });

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final motion = OmniMotion.of(context);
    final track = OmniColors.byBrightness(
      context,
      OmniColors.muted,
      OmniColors.darkMuted,
    );
    final thumb = OmniColors.byBrightness(
      context,
      Colors.white,
      OmniColors.darkCard,
    );
    final muted = OmniColors.byBrightness(
      context,
      OmniColors.mutedForeground,
      OmniColors.darkMutedForeground,
    );
    final ink = Theme.of(context).colorScheme.onSurface;
    final x = labels.length == 1
        ? 0.0
        : -1 + 2 * selected / (labels.length - 1);

    return Container(
      height: 44,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: track,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            alignment: Alignment(x, 0),
            duration: motion.enabled
                ? const Duration(milliseconds: 350)
                : Duration.zero,
            curve: OmniCurves.standard,
            child: FractionallySizedBox(
              widthFactor: 1 / labels.length,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: thumb,
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1F0B1A33),
                      blurRadius: 3,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                child: const SizedBox.expand(),
              ),
            ),
          ),
          Row(
            children: [
              for (var i = 0; i < labels.length; i++)
                Expanded(
                  child: Semantics(
                    button: true,
                    selected: i == selected,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(4),
                      onTap: () => onChanged(i),
                      child: Center(
                        child: Text(
                          labels[i],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: OmniType.caption.copyWith(
                            fontWeight: FontWeight.w600,
                            color: i == selected ? ink : muted,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
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
          borderRadius: BorderRadius.circular(4),
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
    return Column(
      children: [
        for (final link in links)
          ListTile(
            minTileHeight: 44,
            leading: const Icon(Icons.link_rounded),
            title: Text(link, maxLines: 1, overflow: TextOverflow.ellipsis),
            onTap: () => _openUrl(link),
          ),
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

class _PlayableVideoState extends State<_PlayableVideo> {
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
    if (!_controller.value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }
    return Center(
      child: AspectRatio(
        aspectRatio: _controller.value.aspectRatio,
        child: Stack(
          alignment: Alignment.center,
          children: [
            VideoPlayer(_controller),
            IconButton.filled(
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
    return Column(
      children: [
        for (final file in files)
          ListTile(
            minTileHeight: 44,
            leading: const Icon(Icons.insert_drive_file_outlined),
            title: Text(
              file.name ?? 'Tệp đính kèm',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
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
  final uri = Uri.tryParse(value);
  if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
}
