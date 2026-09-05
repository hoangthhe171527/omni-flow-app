import 'package:flutter/material.dart';

import '../../design/tokens/omni_colors.dart';

/// Whose account a message came through.
///
/// Reps behave very differently depending on this: an official account speaks
/// for the company and is bound by the platform's 24h / customer-care rules; a
/// personal one is a named rep's own inbox. So it must be readable at a glance
/// and never inferred.
enum ChannelKind { official, personal }

/// The platforms the omnichannel inbox ingests. Mirrors `Channel` in the web
/// client (`src/core/domain/channel.ts`) — the two must not drift.
enum Channel {
  facebook,
  zalo,
  zaloPersonal,
  facebookPersonal,
  tiktok,
  web,
  instagram,
  whatsapp,
  unknown;

  static Channel parse(String? slug) => switch (slug) {
    'facebook' => Channel.facebook,
    'zalo' => Channel.zalo,
    'zalo_personal' => Channel.zaloPersonal,
    'facebook_personal' => Channel.facebookPersonal,
    'tiktok' => Channel.tiktok,
    'web' => Channel.web,
    'instagram' => Channel.instagram,
    'whatsapp' => Channel.whatsapp,
    _ => Channel.unknown,
  };

  String get slug => switch (this) {
    Channel.facebook => 'facebook',
    Channel.zalo => 'zalo',
    Channel.zaloPersonal => 'zalo_personal',
    Channel.facebookPersonal => 'facebook_personal',
    Channel.tiktok => 'tiktok',
    Channel.web => 'web',
    Channel.instagram => 'instagram',
    Channel.whatsapp => 'whatsapp',
    Channel.unknown => 'unknown',
  };

  ChannelMeta get meta => ChannelMeta.of(this);
}

class ChannelMeta {
  const ChannelMeta({
    required this.name,
    required this.short,
    required this.kind,
    required this.color,
    required this.tint,
    required this.icon,
  });

  /// Full label — filters, settings, empty states.
  final String name;

  /// Compact label for the source pill, where an account name follows it.
  final String short;

  final ChannelKind kind;

  /// The platform hue. Always used *alongside* the platform's name in text —
  /// colour reinforces, it is never the only signal.
  final Color color;

  /// Soft background behind the pill.
  final Color tint;

  final IconData icon;

  static ChannelMeta of(Channel channel) => switch (channel) {
    // "Facebook" alone read as "some Facebook thing" next to "Facebook cá
    // nhân"; name the asset so a Page and a personal inbox can't be confused.
    Channel.facebook => const ChannelMeta(
      name: 'Facebook Page',
      short: 'FB Page',
      kind: ChannelKind.official,
      color: Color(0xFF1877F2),
      tint: Color(0xFFE7F0FE),
      icon: Icons.facebook_rounded,
    ),
    Channel.facebookPersonal => const ChannelMeta(
      name: 'Facebook cá nhân',
      short: 'FB cá nhân',
      kind: ChannelKind.personal,
      color: Color(0xFF1D4ED8),
      tint: Color(0xFFE7F0FE),
      icon: Icons.facebook_rounded,
    ),
    Channel.zalo => const ChannelMeta(
      name: 'Zalo OA',
      short: 'Zalo OA',
      kind: ChannelKind.official,
      color: Color(0xFF0EA5E9),
      tint: Color(0xFFE0F2FE),
      icon: Icons.chat_bubble_rounded,
    ),
    Channel.zaloPersonal => const ChannelMeta(
      name: 'Zalo cá nhân',
      short: 'Zalo cá nhân',
      kind: ChannelKind.personal,
      color: Color(0xFF0369A1),
      tint: Color(0xFFE0F2FE),
      icon: Icons.chat_bubble_rounded,
    ),
    Channel.tiktok => const ChannelMeta(
      name: 'TikTok',
      short: 'TikTok',
      kind: ChannelKind.official,
      color: Color(0xFF0F172A),
      tint: Color(0xFFF1F5F9),
      icon: Icons.music_note_rounded,
    ),
    Channel.web => const ChannelMeta(
      name: 'Website Chat',
      short: 'Web',
      kind: ChannelKind.official,
      color: OmniColors.success,
      tint: Color(0xFFD1FAE5),
      icon: Icons.language_rounded,
    ),
    Channel.instagram => const ChannelMeta(
      name: 'Instagram',
      short: 'Instagram',
      kind: ChannelKind.official,
      color: Color(0xFFEC4899),
      tint: Color(0xFFFCE7F3),
      icon: Icons.camera_alt_rounded,
    ),
    Channel.whatsapp => const ChannelMeta(
      name: 'WhatsApp',
      short: 'WhatsApp',
      kind: ChannelKind.personal,
      color: Color(0xFF22C55E),
      tint: Color(0xFFDCFCE7),
      icon: Icons.chat_rounded,
    ),
    Channel.unknown => const ChannelMeta(
      name: 'Khác',
      short: 'Khác',
      kind: ChannelKind.official,
      color: OmniColors.mutedForeground,
      tint: OmniColors.muted,
      icon: Icons.forum_rounded,
    ),
  };
}
