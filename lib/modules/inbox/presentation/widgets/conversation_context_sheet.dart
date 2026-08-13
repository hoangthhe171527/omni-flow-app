import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../design/components/components.dart';
import '../../../../design/tokens/tokens.dart';
import '../../../customers/customers.dart';
import '../../../opportunities/opportunities.dart';
import '../../application/inbox_providers.dart';
import '../../data/inbox_api.dart';
import '../../domain/message.dart';

/// Customer and conversation context, with Messenger-style shared content.
class ConversationContextSheet extends ConsumerWidget {
  const ConversationContextSheet({super.key, required this.conversationId});

  final String conversationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversation = ref.watch(conversationProvider(conversationId));
    final contextData = ref.watch(conversationContextProvider(conversationId));
    final assets = ref.watch(conversationAssetsProvider(conversationId));
    final access = ref.watch(inboxAccessProvider);
    final scheme = Theme.of(context).colorScheme;

    return OmniAsyncView(
      value: conversation,
      data: (threadInfo) => ListView(
        padding: const EdgeInsets.fromLTRB(
          OmniSpacing.lg,
          0,
          OmniSpacing.lg,
          OmniSpacing.xxl,
        ),
        children: [
          Row(
            children: [
              OmniAvatar(
                name: threadInfo.title,
                imageUrl: threadInfo.customerAvatar,
                size: 56,
              ),
              const SizedBox(width: OmniSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      threadInfo.title,
                      style: OmniType.title.copyWith(color: scheme.onSurface),
                    ),
                    const SizedBox(height: OmniSpacing.xs),
                    OmniSourcePill(
                      channel: threadInfo.channel,
                      accountName: threadInfo.accountName,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: OmniSpacing.xl),
          Row(
            children: [
              if (threadInfo.isLinkedToCustomer)
                Expanded(
                  child: _QuickAction(
                    icon: Icons.person_outline_rounded,
                    label: 'Hồ sơ KH',
                    onTap: () {
                      Navigator.pop(context);
                      context.pushNamed(
                        CustomersModule.detail,
                        pathParameters: {'id': threadInfo.customerId!},
                      );
                    },
                  ),
                )
              else if (access.canConvert)
                Expanded(
                  child: _QuickAction(
                    icon: Icons.person_add_alt_rounded,
                    label: 'Chuyển KH',
                    onTap: () => _convert(context, ref),
                  ),
                ),
              const SizedBox(width: OmniSpacing.sm),
              Expanded(
                child: _QuickAction(
                  icon: Icons.trending_up_rounded,
                  label: 'Tạo cơ hội',
                  onTap: () {
                    Navigator.pop(context);
                    context.pushNamed(
                      OpportunitiesModule.create,
                      queryParameters: {
                        if (threadInfo.customerId != null)
                          'customer': threadInfo.customerId!,
                      },
                    );
                  },
                ),
              ),
            ],
          ),
          const OmniSectionHeader(title: 'Nhãn hội thoại'),
          Wrap(
            spacing: OmniSpacing.sm,
            runSpacing: OmniSpacing.sm,
            children: [
              for (final tag in threadInfo.tags) OmniTag(label: tag),
              if (threadInfo.tags.isEmpty)
                Text(
                  'Chưa có nhãn',
                  style: OmniType.caption.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          const OmniSectionHeader(title: 'Cơ hội đang mở'),
          OmniAsyncView(
            value: contextData,
            loading: const OmniSkeletonBox(height: 70),
            isEmpty: (data) => data.opportunities.isEmpty,
            empty: Text(
              'Chưa có cơ hội nào gắn với khách này.',
              style: OmniType.caption.copyWith(color: scheme.onSurfaceVariant),
            ),
            data: (data) => Column(
              children: [
                for (final opportunity in data.opportunities)
                  Padding(
                    padding: const EdgeInsets.only(bottom: OmniSpacing.sm),
                    child: OmniCard(
                      padding: const EdgeInsets.all(OmniSpacing.md),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  opportunity.title,
                                  style: OmniType.caption.copyWith(
                                    color: scheme.onSurface,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (opportunity.stage != null)
                                  Text(
                                    'Giai đoạn: ${opportunity.stage}',
                                    style: OmniType.micro.copyWith(
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Text(
                            Formatters.vnd(opportunity.budget),
                            style: OmniType.caption.copyWith(
                              color: scheme.onSurface,
                              fontWeight: FontWeight.w700,
                              fontFeatures: OmniType.tabular,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const OmniSectionHeader(title: 'Phương tiện, liên kết và file'),
          _ConversationAssets(assets: assets),
        ],
      ),
    );
  }

  Future<void> _convert(BuildContext context, WidgetRef ref) async {
    try {
      final result = await ref.read(inboxApiProvider).convert(conversationId);
      ref.invalidate(conversationProvider(conversationId));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.linkedExisting
                ? 'Đã liên kết với khách hàng có sẵn.'
                : 'Đã tạo khách hàng mới.',
          ),
        ),
      );
    } on AppException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }
}

class _ConversationAssets extends StatefulWidget {
  const _ConversationAssets({required this.assets});

  final AsyncValue<ConversationAssets> assets;

  @override
  State<_ConversationAssets> createState() => _ConversationAssetsState();
}

class _ConversationAssetsState extends State<_ConversationAssets> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return widget.assets.when(
      loading: () => const OmniSkeletonBox(height: 160),
      error: (_, _) => Text(
        'Không tải được nội dung đã chia sẻ.',
        style: OmniType.caption.copyWith(color: scheme.onSurfaceVariant),
      ),
      data: (assets) {
        final media = assets.media;
        final files = assets.files;
        final links = assets.links;
        return Column(
          children: [
            _AssetTabs(
              selected: _tab,
              onChanged: (value) => setState(() => _tab = value),
            ),
            const SizedBox(height: OmniSpacing.md),
            if (_tab == 0)
              _MediaGrid(items: media)
            else if (_tab == 1)
              _FileList(files: files)
            else
              _LinkList(links: links),
          ],
        );
      },
    );
  }
}

class _AssetTabs extends StatelessWidget {
  const _AssetTabs({required this.selected, required this.onChanged});

  final int selected;
  final ValueChanged<int> onChanged;

  static const _tabs = [
    (Icons.perm_media_outlined, 'Phương tiện'),
    (Icons.insert_drive_file_outlined, 'File'),
    (Icons.link_rounded, 'Liên kết'),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: scheme.outline.withValues(alpha: 0.35)),
        ),
      ),
      child: Row(
        children: [
          for (var index = 0; index < _tabs.length; index++)
            Expanded(
              child: InkWell(
                onTap: () => onChanged(index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.only(top: 9, bottom: 8),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: selected == index
                            ? OmniColors.chatPrimary
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _tabs[index].$1,
                        size: 20,
                        color: selected == index
                            ? OmniColors.chatPrimary
                            : scheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _tabs[index].$2,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: OmniType.micro.copyWith(
                          color: selected == index
                              ? OmniColors.chatPrimary
                              : scheme.onSurfaceVariant,
                          fontWeight: selected == index
                              ? FontWeight.w700
                              : FontWeight.w500,
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

class _MediaGrid extends StatelessWidget {
  const _MediaGrid({required this.items});

  final List<MessageAttachment> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const _AssetEmpty(label: 'Chưa có ảnh hoặc video');
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
      ),
      itemBuilder: (_, index) => ClipRRect(
        borderRadius: BorderRadius.circular(10),
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
        for (final link in links.toSet())
          ListTile(
            contentPadding: EdgeInsets.zero,
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
                      size: 48,
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
        ColoredBox(color: Colors.black87),
        const Center(
          child: Icon(
            Icons.play_circle_fill_rounded,
            color: Colors.white,
            size: 42,
          ),
        ),
        Positioned(
          left: 6,
          right: 6,
          bottom: 5,
          child: Text(
            item.name ?? 'Video',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 10),
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
            contentPadding: EdgeInsets.zero,
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

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return OmniCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(vertical: OmniSpacing.md),
      child: Column(
        children: [
          Icon(icon, size: 20, color: scheme.primary),
          const SizedBox(height: 5),
          Text(label, style: OmniType.micro.copyWith(color: scheme.onSurface)),
        ],
      ),
    );
  }
}
