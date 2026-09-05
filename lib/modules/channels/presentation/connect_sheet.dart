import 'package:flutter/material.dart';

import '../../../core/domain/channel.dart';
import '../../../design/tokens/tokens.dart';
import '../domain/connectable_channel.dart';

/// Chọn kênh muốn nối, hoặc null nếu người dùng đóng sheet.
Future<Channel?> showConnectSheet(BuildContext context) {
  return showModalBottomSheet<Channel>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          OmniSpacing.lg,
          0,
          OmniSpacing.lg,
          OmniSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Kênh chính thức', style: OmniType.bodyStrong),
            Text(
              'Nói danh nghĩa công ty. Nối bằng cách đăng nhập trên trình duyệt.',
              style: OmniType.micro.copyWith(
                color: Theme.of(sheetContext).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: OmniSpacing.sm),
            for (final channel in ConnectableChannels.oauth)
              _ChannelOption(channel: channel),
            if (ConnectableChannels.pair.isNotEmpty) ...[
              const SizedBox(height: OmniSpacing.lg),
              Text('Tài khoản cá nhân', style: OmniType.bodyStrong),
              Text(
                'Tài khoản riêng của nhân viên. Ghép nối bằng mã QR với máy đang chạy agent.',
                style: OmniType.micro.copyWith(
                  color: Theme.of(sheetContext).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: OmniSpacing.sm),
              for (final channel in ConnectableChannels.pair)
                _ChannelOption(channel: channel),
            ],
          ],
        ),
      ),
    ),
  );
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
