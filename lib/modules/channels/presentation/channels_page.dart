import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design/components/components.dart';
import '../../../design/tokens/tokens.dart';
import '../../../security/session/session_controller.dart';
import '../application/channels_providers.dart';
import '../data/channels_api.dart';
import '../domain/channel_connection.dart';
import '../domain/channel_permissions.dart';
import 'widgets/channel_tile.dart';

class ChannelsPage extends ConsumerWidget {
  const ChannelsPage({super.key});

  Future<void> _disconnect(
    BuildContext context,
    WidgetRef ref,
    ChannelConnection connection,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Ngắt kết nối?'),
        content: Text(
          '${connection.label} sẽ ngừng nhận tin về hộp thư. '
          'Nối lại được bất cứ lúc nào.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Huỷ'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Ngắt kết nối'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await ref.read(channelsApiProvider).disconnect(connection.id);
      ref.invalidate(channelsProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã ngắt ${connection.label}')),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final channels = ref.watch(channelsProvider);
    final canWrite = ref.watch(accessProvider).can(ChannelPermissions.write);

    return Scaffold(
      appBar: AppBar(title: const Text('Kết nối kênh')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: canWrite
            ? () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Chọn kênh — sắp có')),
                )
            : null,
        icon: const Icon(Icons.add_link_rounded),
        label: const Text('Kết nối kênh'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(channelsProvider),
        child: OmniAsyncView(
          value: channels,
          onRetry: () => ref.invalidate(channelsProvider),
          isEmpty: (list) => list.isEmpty,
          empty: const OmniEmptyState(
            icon: Icons.hub_outlined,
            title: 'Chưa nối kênh nào',
            message:
                'Nối Zalo, Facebook hoặc TikTok để tin nhắn khách đổ về hộp thư.',
          ),
          data: (list) {
            final official = list.where((c) => !c.isPersonal).toList();
            final personal = list.where((c) => c.isPersonal).toList();

            return ListView(
              padding: const EdgeInsets.fromLTRB(
                OmniSpacing.lg,
                OmniSpacing.lg,
                OmniSpacing.lg,
                OmniSpacing.xxl,
              ),
              children: [
                if (official.isNotEmpty) ...[
                  const OmniSectionHeader(
                    title: 'Kênh chính thức',
                    // ListView đã có gutter lg; padding mặc định của header là
                    // lg hai bên + xxl trên, cộng vào là thụt hai lần.
                    padding: EdgeInsets.only(bottom: OmniSpacing.sm),
                  ),
                  const SizedBox(height: OmniSpacing.sm),
                  for (final connection in official) ...[
                    ChannelTile(
                      connection: connection,
                      canWrite: canWrite,
                      onReconnect: () {},
                      onDisconnect: () => _disconnect(context, ref, connection),
                    ),
                    const SizedBox(height: OmniSpacing.sm),
                  ],
                ],
                if (personal.isNotEmpty) ...[
                  const SizedBox(height: OmniSpacing.md),
                  const OmniSectionHeader(
                    title: 'Tài khoản cá nhân',
                    padding: EdgeInsets.only(bottom: OmniSpacing.sm),
                  ),
                  const SizedBox(height: OmniSpacing.sm),
                  for (final connection in personal) ...[
                    ChannelTile(
                      connection: connection,
                      canWrite: canWrite,
                      onReconnect: () {},
                      onDisconnect: () => _disconnect(context, ref, connection),
                    ),
                    const SizedBox(height: OmniSpacing.sm),
                  ],
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
