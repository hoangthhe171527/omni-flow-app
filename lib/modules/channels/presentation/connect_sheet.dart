import 'package:flutter/material.dart';

import '../../../core/domain/channel.dart';
import '../../../design/components/components.dart';
import '../../../design/tokens/tokens.dart';
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
    builder: (_) => SafeArea(child: _ConnectContent(access: access)),
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
    return Padding(
      padding: EdgeInsets.fromLTRB(
        OmniSpacing.lg,
        compact ? OmniSpacing.md : 0,
        OmniSpacing.lg,
        OmniSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Page/OA là kênh công ty: chỉ admin kết nối (quyết định
          // 2026-10-04 #3). Sale không thấy mục này, API cũng trả 403.
          if (oauth.isNotEmpty) ...[
            Text('Kênh chính thức', style: OmniType.bodyStrong),
            Text(
              'Nói danh nghĩa công ty',
              style: OmniType.micro.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: OmniSpacing.sm),
            for (final channel in oauth) _ChannelOption(channel: channel),
          ],
          if (ConnectableChannels.pair.isNotEmpty) ...[
            if (oauth.isNotEmpty) const SizedBox(height: OmniSpacing.md),
            Text('Tài khoản cá nhân', style: OmniType.bodyStrong),
            Text(
              'Ghép nối bằng mã QR',
              style: OmniType.micro.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: OmniSpacing.sm),
            for (final channel in ConnectableChannels.pair)
              _ChannelOption(channel: channel),
          ],
        ],
      ),
    );
  }
}

class _ChannelOption extends StatelessWidget {
  const _ChannelOption({required this.channel});

  final Channel channel;

  @override
  Widget build(BuildContext context) {
    final meta = channel.meta;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: meta.tint,
          borderRadius: OmniRadius.smAll,
        ),
        child: Icon(meta.icon, size: OmniIconSize.lg, color: meta.color),
      ),
      title: Text(meta.name),
      onTap: () => Navigator.of(context).pop(channel),
    );
  }
}
