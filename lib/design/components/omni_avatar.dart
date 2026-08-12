import 'package:flutter/material.dart';

import '../../core/utils/avatar_url.dart';
import '../../core/utils/formatters.dart';
import '../tokens/tokens.dart';

/// Circular avatar with a deterministic coloured initials fallback.
///
/// Fallback is the norm, not the exception: most Zalo/Facebook contacts reach us
/// without a usable avatar URL, so initials must look intentional rather than
/// broken.
class OmniAvatar extends StatelessWidget {
  const OmniAvatar({
    super.key,
    required this.name,
    this.imageUrl,
    this.size = 44,
    this.online = false,
    this.badge,
  });

  final String name;
  final String? imageUrl;
  final double size;
  final bool online;

  /// Small overlay at the bottom-right — the channel dot on inbox rows.
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    final color = OmniColors.avatarFor(name);
    final resolvedImageUrl = resolveAvatarUrl(imageUrl);
    final fallback = Text(
      Formatters.initials(name),
      style: OmniType.micro.copyWith(
        color: color,
        fontSize: size * 0.34,
        fontWeight: FontWeight.w700,
      ),
    );
    final avatar = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.14),
      ),
      alignment: Alignment.center,
      child: resolvedImageUrl != null
          ? ClipOval(
              child: Image.network(
                resolvedImageUrl,
                width: size,
                height: size,
                fit: BoxFit.cover,
                // Android can reject an expired platform URL or an unavailable
                // mirror. Never leave a blank circle when that happens.
                errorBuilder: (_, _, _) => fallback,
              ),
            )
          : fallback,
    );

    if (!online && badge == null) return avatar;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          avatar,
          if (online)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: size * 0.26,
                height: size * 0.26,
                decoration: BoxDecoration(
                  color: OmniColors.success,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).colorScheme.surface,
                    width: 2,
                  ),
                ),
              ),
            ),
          if (badge != null) Positioned(right: -2, bottom: -2, child: badge!),
        ],
      ),
    );
  }
}

/// Two overlapping avatars — how a group thread reads at a glance in the list.
class OmniGroupAvatar extends StatelessWidget {
  const OmniGroupAvatar({super.key, required this.names, this.size = 44});

  final List<String> names;
  final double size;

  @override
  Widget build(BuildContext context) {
    final visible = names.take(2).toList();
    if (visible.isEmpty) {
      return OmniAvatar(name: 'Nhóm', size: size);
    }
    final small = size * 0.66;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            child: OmniAvatar(name: visible.first, size: small),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).colorScheme.surface,
                  width: 2,
                ),
              ),
              child: OmniAvatar(
                name: visible.length > 1 ? visible[1] : 'Nhóm',
                size: small,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
