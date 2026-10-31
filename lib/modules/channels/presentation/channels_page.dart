import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/domain/channel.dart';
import '../../../core/error/app_exception.dart';
import '../../../design/components/components.dart';
import '../../../design/tokens/tokens.dart';
import '../../../security/session/session_controller.dart';
import '../application/channels_providers.dart';
import '../application/oauth_watch.dart';
import '../channels_module.dart';
import '../data/channels_api.dart';
import '../domain/channel_connection.dart';
import '../domain/channel_permissions.dart';
import '../domain/connectable_channel.dart';
import 'connect_sheet.dart';
import 'widgets/channel_tile.dart';

class ChannelsPage extends ConsumerStatefulWidget {
  const ChannelsPage({super.key});

  @override
  ConsumerState<ChannelsPage> createState() => _ChannelsPageState();
}

class _ChannelsPageState extends ConsumerState<ChannelsPage> {
  Timer? _oauthWatch;
  bool _connecting = false;

  @override
  void dispose() {
    _oauthWatch?.cancel();
    super.dispose();
  }

  Future<void> _disconnect(ChannelConnection connection) async {
    final confirmed = await showOmniConfirm(
      context: context,
      title: 'Ngắt kết nối?',
      message:
          '${connection.label} sẽ ngừng nhận tin về hộp thư. '
          'Nối lại được bất cứ lúc nào.',
      confirmLabel: 'Ngắt kết nối',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    try {
      await ref.read(channelsApiProvider).disconnect(connection.id);
      ref.invalidate(channelsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Đã ngắt ${connection.label}')));
    } on AppException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _pickChannel(Rect anchor) async {
    final channel = await showConnectMenu(
      context,
      anchor: anchor,
      access: ref.read(accessProvider),
    );
    if (channel == null || !mounted) return;
    switch (ConnectableChannels.methodFor(channel)) {
      case ConnectMethod.oauth:
        await _startOauth(channel);
      case ConnectMethod.pair:
        await _openPair(channel);
      case ConnectMethod.none:
        break;
    }
  }

  Future<void> _openPair(Channel channel) async {
    await context.pushNamed(
      ChannelsModule.pair,
      pathParameters: {'channelId': channel.slug},
    );
    ref.invalidate(channelsProvider);
  }

  Future<void> _startOauth(Channel channel) async {
    setState(() => _connecting = true);
    try {
      final url = await ref.read(channelsApiProvider).oauthUrl(channel);
      if (url.isEmpty) {
        _snack('Nền tảng chưa cấu hình OAuth.');
        return;
      }
      final before = {
        for (final connection
            in ref.read(channelsProvider).valueOrNull ??
                const <ChannelConnection>[])
          connection.id,
      };
      final opened = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!opened) {
        _snack('Không mở được trình duyệt.');
        return;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đăng nhập xong thì quay lại đây, app tự nhận.'),
          duration: Duration(seconds: 6),
        ),
      );
      _watchForConnection(before);
    } catch (error) {
      _snack(humanError(error));
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _watchForConnection(Set<String> before) {
    _oauthWatch?.cancel();
    final startedAt = DateTime.now();
    _oauthWatch = Timer.periodic(oauthWatchInterval, (timer) async {
      if (DateTime.now().difference(startedAt) > oauthWatchTimeout) {
        timer.cancel();
        return;
      }
      try {
        final fresh = await ref.read(channelsApiProvider).list();
        if (firstNewId(before, fresh) == null) return;
        timer.cancel();
        ref.invalidate(channelsProvider);
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Đã nối kênh mới.')));
      } catch (_) {
        // Do not terminate a successful OAuth wait due to one failed request.
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final channels = ref.watch(channelsProvider);
    final access = ref.watch(accessProvider);
    final canWrite = access.can(ChannelPermissions.write);
    // Page/OA chỉ admin kết nối (quyết định 2026-10-04 #3).
    final canConnectCompany = ChannelPermissions.canConnectCompany(access);
    final canPick =
        canConnectCompany || (canWrite && ConnectableChannels.pair.isNotEmpty);
    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: const OmniAppBar(title: 'Kết nối kênh'),
      floatingActionButton: Builder(
        builder: (buttonContext) => FloatingActionButton.extended(
          onPressed: _connecting || !canPick
              ? null
              : () {
                  final box = buttonContext.findRenderObject() as RenderBox?;
                  if (box == null || !box.hasSize) return;
                  _pickChannel(box.localToGlobal(Offset.zero) & box.size);
                },
          icon: const Icon(Icons.add_link_rounded),
          label: const Text('Kết nối kênh'),
        ),
      ),
      body: RefreshIndicator.adaptive(
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
            final official = list
                .where((connection) => !connection.isPersonal)
                .toList();
            final personal = list
                .where((connection) => connection.isPersonal)
                .toList();
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
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
                    padding: EdgeInsets.only(bottom: OmniSpacing.sm),
                  ),
                  const SizedBox(height: OmniSpacing.sm),
                  for (var i = 0; i < official.length; i++) ...[
                    ChannelTile(
                      connection: official[i],
                      canWrite: canWrite,
                      canReconnect: canConnectCompany,
                      onReconnect: () => _startOauth(official[i].channel),
                      onDisconnect: () => _disconnect(official[i]),
                    ),
                    if (i < official.length - 1)
                      Divider(height: 1, color: scheme.outlineVariant),
                  ],
                ],
                if (personal.isNotEmpty) ...[
                  const SizedBox(height: OmniSpacing.md),
                  const OmniSectionHeader(
                    title: 'Tài khoản cá nhân',
                    padding: EdgeInsets.only(bottom: OmniSpacing.sm),
                  ),
                  const SizedBox(height: OmniSpacing.sm),
                  for (var i = 0; i < personal.length; i++) ...[
                    ChannelTile(
                      connection: personal[i],
                      canWrite: canWrite,
                      onReconnect: () => _openPair(personal[i].channel),
                      onDisconnect: () => _disconnect(personal[i]),
                    ),
                    if (i < personal.length - 1)
                      Divider(height: 1, color: scheme.outlineVariant),
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
