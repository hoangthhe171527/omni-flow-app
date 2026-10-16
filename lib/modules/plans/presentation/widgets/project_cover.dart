import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/utils/media_url.dart';
import '../../../../design/tokens/tokens.dart';

/// API dùng cùng trường `cover` cho token gradient cũ và URL ảnh nền mới.
bool isProjectCoverImage(String? cover) {
  final value = cover?.trim() ?? '';
  if (value.isEmpty || OmniCovers.names.contains(value)) return false;
  final uri = Uri.tryParse(value);

  return value.startsWith('/') ||
      (uri != null && (uri.scheme == 'http' || uri.scheme == 'https'));
}

/// Cùng bảng màu hệ thống với web (`PROJECT_COLORS`). Cover token cũ vẫn ưu
/// tiên gradient; khi không có cover thì `project.color` mới là dấu nhận diện.
Color projectSystemColor(String? value) => switch (value) {
  'blue' => const Color(0xFF3B82F6),
  'cyan' => const Color(0xFF06B6D4),
  'emerald' => const Color(0xFF10B981),
  'amber' => const Color(0xFFF59E0B),
  'rose' => const Color(0xFFF43F5E),
  'violet' => const Color(0xFF8B5CF6),
  'slate' => const Color(0xFF64748B),
  _ => const Color(0xFF6366F1),
};

/// Nền toàn màn của một kế hoạch. Ảnh lỗi tự rơi về gradient hệ thống để bảng
/// không bao giờ thành một mặt trắng hoặc mất chữ.
class ProjectCoverSurface extends StatelessWidget {
  const ProjectCoverSurface({
    super.key,
    required this.cover,
    this.color,
    required this.child,
  });

  final String? cover;
  final String? color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final token = OmniCovers.names.contains(cover);
    final system = projectSystemColor(color);
    final fallback = DecoratedBox(
      decoration: BoxDecoration(
        gradient: token
            ? OmniCovers.gradientOf(cover)
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [system, Color.lerp(system, Colors.black, .34)!],
              ),
      ),
    );

    return ColoredBox(
      color: token ? OmniCovers.colorOf(cover) : system,
      child: Stack(
        fit: StackFit.expand,
        children: [
          fallback,
          if (isProjectCoverImage(cover))
            CachedNetworkImage(
              imageUrl: resolveMediaUrl(cover!),
              fit: BoxFit.cover,
              fadeInDuration: const Duration(milliseconds: 180),
              errorWidget: (_, _, _) => const SizedBox.shrink(),
            ),
          child,
        ],
      ),
    );
  }
}

/// Dấu nhận diện kế hoạch trong cây Team → Kế hoạch.
///
/// Không dùng chữ cái/avatar: kế hoạch không phải một con người. Token cũ là
/// ô màu; URL mới là thumbnail ảnh, cùng kích thước nhỏ để giữ phân cấp rõ.
class ProjectCoverMarker extends StatelessWidget {
  const ProjectCoverMarker({
    super.key,
    this.markerKey,
    required this.cover,
    this.color,
    this.size = 12,
  });

  final Key? markerKey;
  final String? cover;
  final String? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final image = isProjectCoverImage(cover);
    return ClipRRect(
      key: markerKey,
      borderRadius: BorderRadius.circular(size >= 24 ? 8 : 3),
      child: SizedBox.square(
        dimension: size,
        child: image
            ? CachedNetworkImage(
                imageUrl: resolveMediaUrl(cover!),
                fit: BoxFit.cover,
                errorWidget: (_, _, _) => _fallback(),
              )
            : _fallback(),
      ),
    );
  }

  Widget _fallback() => OmniCovers.names.contains(cover)
      ? DecoratedBox(
          decoration: BoxDecoration(gradient: OmniCovers.gradientOf(cover)),
        )
      : ColoredBox(color: projectSystemColor(color));
}
