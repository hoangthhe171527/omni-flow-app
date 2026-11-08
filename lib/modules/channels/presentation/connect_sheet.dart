import 'package:flutter/material.dart';

import '../../../core/domain/channel.dart';
import '../../../design/components/components.dart';
import '../../../security/permissions/access_policy.dart';
import '../domain/channel_permissions.dart';
import '../domain/connectable_channel.dart';

/// Chọn kênh muốn nối, hoặc null nếu người dùng đóng sheet.
Future<Channel?> showConnectSheet(
  BuildContext context, {
  required AccessPolicy access,
}) {
  return showOmniSheet<Channel>(
    context: context,
    builder: (_) => _ConnectContent(access: access),
  );
}

/// Menu nối kênh neo vào nút + của màn Kết nối kênh.
Future<Channel?> showConnectMenu(
  BuildContext context, {
  required Rect anchor,
  required AccessPolicy access,
}) => showOmniAnchoredMenu<Channel>(
  context: context,
  anchor: anchor,
  width: 344,
  menuKey: const Key('connect-channel-menu'),
  semanticsLabel: 'Chọn kênh kết nối',
  builder: (_) => _ConnectContent(access: access, compact: true),
);

class _ConnectContent extends StatelessWidget {
  const _ConnectContent({required this.access, this.compact = false});

  final AccessPolicy access;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final oauth = ChannelPermissions.canConnectCompany(access)
        ? ConnectableChannels.oauth
        : const <Channel>[];
    // Page/OA là kênh công ty: chỉ admin kết nối (quyết định 2026-10-04 #3).
    // Sale không thấy nhóm này, API cũng trả 403.
    final groups = <Widget>[
      if (oauth.isNotEmpty)
        OmniGroupSection(
          title: 'Kênh chính thức',
          children: [for (final channel in oauth) _ChannelOption(channel)],
        ),
      if (ConnectableChannels.pair.isNotEmpty)
        OmniGroupSection(
          title: 'Tài khoản cá nhân',
          children: [
            for (final channel in ConnectableChannels.pair)
              _ChannelOption(channel),
          ],
        ),
    ];
    if (!compact) return OmniSheetBody(children: groups);
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < groups.length; i++) ...[
            if (i > 0) const SizedBox(height: OmniGroupSection.sheetGap),
            groups[i],
          ],
        ],
      ),
    );
  }
}

class _ChannelOption extends StatelessWidget {
  const _ChannelOption(this.channel);

  final Channel channel;

  @override
  Widget build(BuildContext context) {
    final meta = channel.meta;
    return OmniGroupRow(
      icon: meta.icon,
      title: meta.name,
      chevron: false,
      onTap: () => Navigator.of(context).pop(channel),
    );
  }
}
