import 'package:flutter/material.dart';

import '../../core/module/module_route.dart';
import '../../core/module/nav_destination.dart';
import '../../core/module/omni_module.dart';
import '../../security/guard/access_requirement.dart';
import 'domain/channel_permissions.dart';
import 'presentation/channels_page.dart';

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
      ];

  @override
  List<ModuleMenuEntry> menuEntries() => const [
        ModuleMenuEntry(
          moduleId: 'channels',
          label: 'Kết nối kênh',
          subtitle: 'Nối Zalo, Facebook, TikTok vào hộp thư',
          icon: Icons.hub_outlined,
          routeName: list,
          group: 'Quản trị',
          order: 20,
          access: AccessRequirement.any(ChannelPermissions.anyRead),
        ),
      ];
}
