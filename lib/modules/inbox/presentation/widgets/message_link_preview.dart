/// Thẻ xem trước một đường link trong tin nhắn.
///
/// Tách khỏi `message_bubble.dart`: file đó từng dài 1594 dòng và chứa 25 lớp
/// — bong bóng, xem trước link, thư viện ảnh, tệp, video, trình xem ảnh toàn
/// màn. Cả năm nhóm đổi vì những lý do khác nhau, và gộp chúng lại nghĩa là
/// mỗi lần sửa một cái là mở cả năm.
library;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/net/host_lookup.dart';
import '../../../../core/net/public_address.dart';
import '../../../../design/tokens/tokens.dart';

class MessageLinkPreview extends StatefulWidget {
  const MessageLinkPreview({
    super.key,
    required this.url,
    this.onPrimary = false,
  });

  final String url;

  /// Nằm trong bong bóng gửi đi nền primary: đảo nền và chữ sang trắng bán trong
  /// suốt để không bị chìm bởi hộp xám đặc.
  final bool onPrimary;

  @override
  State<MessageLinkPreview> createState() => _LinkPreviewCardState();
}

class _LinkPreviewCardState extends State<MessageLinkPreview> {
  static final Map<String, Future<LinkPreviewData>> _metadataCache = {};
  static final Dio _previewClient = Dio(
    BaseOptions(
      connectTimeout: Duration(seconds: 4),
      receiveTimeout: Duration(seconds: 4),
      sendTimeout: Duration(seconds: 4),
      responseType: ResponseType.plain,
      headers: {'User-Agent': 'Viomni Link Preview'},
      followRedirects: false,
    ),
  );
  late final Future<LinkPreviewData> _metadata = _cachedMetadata(widget.url);

  Future<LinkPreviewData> _cachedMetadata(String url) {
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

  Future<LinkPreviewData> _fetchMetadata(String rawUrl) =>
      fetchLinkMetadata(rawUrl, client: _previewClient);

  Future<void> _open() async {
    final raw = widget.url.toLowerCase().startsWith('http')
        ? widget.url
        : 'https://${widget.url}';
    await launchUrl(Uri.parse(raw), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final onPrimary = widget.onPrimary;
    final cardColor = onPrimary
        ? Colors.white.withValues(alpha: 0.16)
        : scheme.onSurface.withValues(alpha: 0.06);
    final borderColor = onPrimary
        ? Colors.white.withValues(alpha: 0.24)
        : OmniColors.byBrightness(
            context,
            OmniColors.border,
            OmniColors.darkBorder,
          );
    final titleColor = onPrimary ? Colors.white : scheme.onSurface;
    final subColor = onPrimary
        ? Colors.white.withValues(alpha: 0.82)
        : scheme.onSurfaceVariant;

    return FutureBuilder<LinkPreviewData>(
      future: _metadata,
      builder: (context, snapshot) {
        final meta = snapshot.data ?? LinkPreviewData(domain: widget.url);
        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Material(
            color: cardColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: borderColor, width: 0.5),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: _open,
              borderRadius: BorderRadius.circular(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (meta.imageUrl != null && meta.imageUrl!.isNotEmpty)
                    AspectRatio(
                      aspectRatio: 1.9,
                      child: CachedNetworkImage(
                        imageUrl: meta.imageUrl!,
                        fit: BoxFit.cover,
                        memCacheWidth:
                            (320 * MediaQuery.devicePixelRatioOf(context))
                                .round()
                                .clamp(320, 960),
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
                          style: OmniType.bodyStrong.copyWith(
                            color: titleColor,
                          ),
                        ),
                        if (meta.description != null &&
                            meta.description!.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            meta.description!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: OmniType.caption.copyWith(color: subColor),
                          ),
                        ],
                        const SizedBox(height: 3),
                        Text(
                          meta.domain,
                          style: OmniType.caption.copyWith(color: subColor),
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

class LinkPreviewData {
  const LinkPreviewData({
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

/// Tải metadata (og:title/og:description/og:image) cho một link trong tin.
///
/// Link do KHÁCH gửi, và thẻ tự tải khi bong bóng hiện — không ai bấm. Nên
/// máy nhân viên chỉ tự gửi request tới host công khai:
/// - host chuẩn hoá mọi cách viết IP (`2130706433`, `127.1`, `0x7f…`, IPv6),
///   chặn loopback/private/link-local/metadata/tên nội bộ;
/// - tên miền phải phân giải ra TOÀN địa chỉ công khai ([lookup]);
/// - không để Dio tự theo redirect: theo tay tối đa 3 bước, kiểm lại từng bước;
/// - `og:image` qua cùng bộ lọc trước khi `CachedNetworkImage` tải nó.
///
/// Trên web ([allowNetwork] = false) KHÔNG tự tải: trình duyệt không cho kiểm
/// DNS, nên không phân biệt được tên công khai với tên trỏ vào mạng nội bộ;
/// thẻ chỉ hiện tên miền, bấm vẫn mở link.
@visibleForTesting
Future<LinkPreviewData> fetchLinkMetadata(
  String rawUrl, {
  required Dio client,
  HostLookup lookup = lookupHostAddresses,
  bool allowNetwork = !kIsWeb,
}) async {
  final normalized = rawUrl.toLowerCase().startsWith('http')
      ? rawUrl
      : 'https://$rawUrl';
  final uri = Uri.tryParse(normalized);
  final host = uri?.host;
  final fallback = LinkPreviewData(
    domain: host != null && host.isNotEmpty ? host : rawUrl,
  );
  if (uri == null || !allowNetwork || !await _isSafeTarget(uri, lookup)) {
    return fallback;
  }

  try {
    var current = uri;
    Response<String>? response;
    for (var hop = 0; hop <= _maxRedirects; hop++) {
      response = await client.get<String>(
        current.toString(),
        options: Options(
          followRedirects: false,
          responseType: ResponseType.plain,
          validateStatus: (status) => status != null && status < 400,
        ),
      );
      final status = response.statusCode ?? 0;
      if (status < 300 || status >= 400) break;
      final location = response.headers.value('location');
      final next = location == null ? null : Uri.tryParse(location);
      if (next == null || hop == _maxRedirects) return fallback;
      current = current.resolveUri(next);
      if (!await _isSafeTarget(current, lookup)) return fallback;
    }
    final status = response?.statusCode ?? 0;
    if (status < 200 || status >= 300) return fallback;

    // Metadata is near the head of normal pages. Avoid retaining/parsing a
    // multi-megabyte response when a server returns a large document.
    final rawHtml = response?.data ?? '';
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
    String? imageUrl;
    final imageUri = image.isEmpty ? null : Uri.tryParse(image);
    if (imageUri != null) {
      final resolved = current.resolveUri(imageUri);
      if (await _isSafeTarget(resolved, lookup)) {
        imageUrl = resolved.toString();
      }
    }
    return LinkPreviewData(
      domain: uri.host,
      title: title.isNotEmpty ? title : uri.host,
      description: description,
      imageUrl: imageUrl,
    );
  } catch (_) {
    return LinkPreviewData(domain: uri.host, title: uri.host);
  }
}

const _maxRedirects = 3;

/// Host công khai theo chữ, VÀ (nếu là tên miền) mọi địa chỉ nó phân giải ra
/// đều công khai. Không phân giải được = không an toàn.
Future<bool> _isSafeTarget(Uri uri, HostLookup lookup) async {
  if (!isPublicHttpUrl(uri)) return false;
  if (parseIpLiteral(uri.host) != null) return true;
  final addresses = await lookup(uri.host);
  if (addresses == null || addresses.isEmpty) return false;
  return addresses.every(isPublicAddress);
}
