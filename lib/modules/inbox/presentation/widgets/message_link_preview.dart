/// Thẻ xem trước một đường link trong tin nhắn.
///
/// Tách khỏi `message_bubble.dart`: file đó từng dài 1594 dòng và chứa 25 lớp
/// — bong bóng, xem trước link, thư viện ảnh, tệp, video, trình xem ảnh toàn
/// màn. Cả năm nhóm đổi vì những lý do khác nhau, và gộp chúng lại nghĩa là
/// mỗi lần sửa một cái là mở cả năm.
library;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../design/tokens/tokens.dart';

class MessageLinkPreview extends StatefulWidget {
  const MessageLinkPreview({super.key, required this.url});

  final String url;

  @override
  State<MessageLinkPreview> createState() => _LinkPreviewCardState();
}

class _LinkPreviewCardState extends State<MessageLinkPreview> {
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
