import 'package:flutter/material.dart';

import '../../core/domain/channel.dart';
import '../../core/module/module_route.dart';
import '../../core/module/nav_destination.dart';
import '../../core/module/omni_module.dart';
import '../../security/guard/access_requirement.dart';
import 'application/channels_providers.dart';
import 'domain/channel_permissions.dart';
import 'domain/connectable_channel.dart';
import 'presentation/channels_page.dart';
import 'presentation/pair_page.dart';
import 'presentation/unsupported_pair_page.dart';

/// Nối tài khoản nhắn tin vào hộp thư.
///
/// Không nhận tab: đây là màn thao tác một lần rồi thôi, không phải màn làm
/// việc hàng ngày. Nó sống trong "Thêm", nhóm Quản trị, cạnh "Nhân viên".
class ChannelsModule extends OmniModule {
  const ChannelsModule();

  static const list = 'channels.list';
  static const pair = 'channels.pair';

  @override
  String get id => 'channels';

  @override
  String get title => 'Kênh';

  @override
  List<String> get permissions => ChannelPermissions.all;

  @override
  List<ModuleRoute> routes() => [
    ModuleRoute(
      path: '/channels',
      name: list,
      rootNavigator: true,
      access: const AccessRequirement.any(ChannelPermissions.anyRead),
      builder: (_, _) => const ChannelsPage(),
    ),
    ModuleRoute(
      path: '/channels/pair/:channelId',
      name: pair,
      rootNavigator: true,
      access: const AccessRequirement.any([ChannelPermissions.write]),
      builder: (_, state) =>
          pairScreenFor(Channel.parse(state.pathParameters['channelId'])),
    ),
  ];

  /// Chỉ kênh ghép nối được trên máy này mới tới [PairPage]. Facebook cá nhân
  /// không bao giờ: app không còn đăng nhập Facebook hộ agent.
  static Widget pairScreenFor(Channel channel) =>
      ConnectableChannels.pair.contains(channel)
      ? PairPage(channel: channel)
      : UnsupportedPairPage(channel: channel);

  @override
  List<ModuleNavEntry> navEntries() => [
    ModuleNavEntry(
      moduleId: 'channels',
      label: 'Kênh kết nối',
      subtitle: 'Nối Zalo, Facebook, TikTok vào hộp thư',
      icon: Icons.hub_outlined,
      selectedIcon: Icons.hub_rounded,
      routeName: list,
      area: NavArea.communication,
      // Cài một lần rồi cả năm không mở. Nó không tranh tab với "Khách hàng" —
      // đây chính là ca làm lộ ra nhu cầu phải có NavWeight.
      weight: NavWeight.secondary,
      order: 30,
      access: AccessRequirement.any(ChannelPermissions.anyRead),
      feature: 'channels',
      badge: channelErrorCountProvider,
      badgeTone: NavBadgeTone.alert,
    ),
  ];
}
