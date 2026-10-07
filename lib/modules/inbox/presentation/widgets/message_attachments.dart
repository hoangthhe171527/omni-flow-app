/// Tệp đính kèm và video trong một tin nhắn.
///
/// Tách khỏi `message_bubble.dart` — xem ghi chú trong `message_link_preview.dart`.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/utils/media_url.dart';
import '../../../../design/tokens/tokens.dart';
import '../../domain/message.dart';
import 'message_images.dart';

/// Cách dựng `VideoPlayerController` — bài kiểm thay để đếm số lượt dựng.
@visibleForTesting
VideoPlayerController Function(Uri url) videoControllerFactory =
    VideoPlayerController.networkUrl;

@visibleForTesting
void resetVideoControllerFactory() =>
    videoControllerFactory = VideoPlayerController.networkUrl;

class MessageFileAttachments extends StatelessWidget {
  const MessageFileAttachments({super.key, required this.attachments});

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
                        size: OmniIconSize.md,
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
                        size: OmniIconSize.md,
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

class MessageVideoAttachments extends StatelessWidget {
  const MessageVideoAttachments({super.key, required this.attachments});

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
  VideoPlayerController? _controller;

  /// URL đang dùng — có thể là bản ký mới, khác `widget.url`.
  String _url = '';

  /// Đã xin URL ký mới cho tệp này chưa. Đúng MỘT lần: lần hỏng thứ hai là
  /// trạng thái lỗi, không phải một lượt gọi API nữa.
  bool _refreshed = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    // Không setState: build đầu chưa chạy.
    _open(resolveMediaUrl(widget.url));
  }

  @override
  void didUpdateWidget(covariant _InlineVideo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url == widget.url) return;
    // Tin đã được tải lại với URL ký mới: coi như một tệp mới, có quyền xin
    // lại nếu URL này cũng hỏng.
    setState(() {
      _refreshed = false;
      _failed = false;
      _open(resolveMediaUrl(widget.url));
    });
  }

  /// Dựng controller cho [url] và bắt đầu mở. Phần đồng bộ; gọi trong
  /// `setState` ở mọi chỗ trừ `initState`.
  void _open(String url) {
    _url = url;
    final previous = _controller;
    _controller = null;
    _disposeSafely(previous);

    if (url.isEmpty) {
      _failed = true;
      return;
    }
    final uri = Uri.tryParse(url);
    if (uri == null) {
      _failed = true;
      return;
    }
    final controller = videoControllerFactory(uri);
    _controller = controller;
    unawaited(_initialize(controller));
  }

  Future<void> _initialize(VideoPlayerController controller) async {
    try {
      await controller.initialize();
    } catch (_) {
      // Link ký hết hạn (403), tệp đã xoá (404), hay mạng hỏng — cùng một
      // đường: xin URL mới một lần, rồi mới chịu hiện lỗi.
      await _onOpenFailed(controller);
      return;
    }
    if (!mounted || controller != _controller) return;
    setState(() {});
  }

  Future<void> _onOpenFailed(VideoPlayerController controller) async {
    if (!mounted || controller != _controller) return;
    if (_refreshed) {
      setState(() => _failed = true);
      return;
    }
    _refreshed = true;
    final fresh = await MediaReloadScope.resolverOf(context)?.refresh(_url);
    if (!mounted || controller != _controller) return;
    if (fresh == null || fresh.isEmpty) {
      setState(() => _failed = true);
      return;
    }
    setState(() => _open(resolveMediaUrl(fresh)));
  }

  /// Nút "Tải lại video": bỏ qua thời gian nghỉ, một lần bấm là một lượt.
  Future<void> _retry() async {
    final resolver = MediaReloadScope.resolverOf(context);
    final fresh = await resolver?.refresh(_url, force: true);
    if (!mounted) return;
    setState(() {
      _refreshed = true;
      _failed = false;
      _open(resolveMediaUrl(fresh == null || fresh.isEmpty ? _url : fresh));
    });
  }

  void _disposeSafely(VideoPlayerController? controller) {
    if (controller == null) return;
    try {
      unawaited(controller.dispose());
    } catch (_) {
      // Controller chưa mở được thì không có gì để giải phóng.
    }
  }

  @override
  void dispose() {
    _disposeSafely(_controller);
    _controller = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final controller = _controller;
    if (_failed || controller == null) {
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: ColoredBox(
          color: scheme.onSurface.withValues(alpha: 0.08),
          child: Center(
            child: IconButton(
              tooltip: 'Tải lại video',
              onPressed: _retry,
              icon: Icon(Icons.refresh_rounded, color: scheme.onSurfaceVariant),
            ),
          ),
        ),
      );
    }
    if (!controller.value.isInitialized) {
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
            aspectRatio: controller.value.aspectRatio,
            child: VideoPlayer(controller),
          ),
          VideoProgressIndicator(
            controller,
            allowScrubbing: true,
            colors: VideoProgressColors(
              playedColor: OmniColors.chatPrimary,
              bufferedColor: Colors.white54,
              backgroundColor: Colors.black38,
            ),
          ),
          Center(
            child: IconButton.filled(
              tooltip: controller.value.isPlaying ? 'Tạm dừng' : 'Phát video',
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
          ),
        ],
      ),
    );
  }
}
