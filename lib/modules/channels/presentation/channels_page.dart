import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/domain/channel.dart';
import '../../../core/error/app_exception.dart';
import '../../../design/components/components.dart';
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

class _ChannelsPageState extends ConsumerState<ChannelsPage>
    with WidgetsBindingObserver {
  Timer? _oauthWatch;
  bool _connecting = false;

  // Trạng thái chờ OAuth. Đồng hồ hạn chỉ chạy lúc app ở tiền cảnh: người dùng
  // đang ở trình duyệt thì app không poll, và quay lại sau 5 phút vẫn còn đủ
  // hạn để kiểm tra.
  Set<String>? _watchBefore;
  Duration _watchForeground = Duration.zero;
  DateTime? _foregroundSince;
  int _watchAttempt = 0;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _oauthWatch?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_watchBefore == null) return;
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        final since = _foregroundSince;
        if (since == null) return;
        _watchForeground += DateTime.now().difference(since);
        _foregroundSince = null;
        _oauthWatch?.cancel();
        _oauthWatch = null;
      case AppLifecycleState.resumed:
        if (_foregroundSince != null) return;
        _foregroundSince = DateTime.now();
        // Người dùng vừa từ trình duyệt về: kiểm đúng 1 lần ngay, rồi 3→5→8s.
        _watchAttempt = 0;
        unawaited(_checkConnection());
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
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
    _watchBefore = before;
    _watchForeground = Duration.zero;
    _foregroundSince = DateTime.now();
    _watchAttempt = 0;
    _scheduleCheck();
  }

  void _stopWatching() {
    _oauthWatch?.cancel();
    _oauthWatch = null;
    _watchBefore = null;
    _foregroundSince = null;
  }

  Duration get _watchElapsed {
    final since = _foregroundSince;
    return since == null
        ? _watchForeground
        : _watchForeground + DateTime.now().difference(since);
  }

  void _scheduleCheck() {
    _oauthWatch?.cancel();
    _oauthWatch = null;
    // Ở nền thì không hẹn: `resumed` sẽ kiểm một lượt.
    if (_watchBefore == null || _foregroundSince == null) return;
    _oauthWatch = Timer(oauthWatchDelay(_watchAttempt), _checkConnection);
  }

  Future<void> _checkConnection() async {
    _oauthWatch = null;
    final before = _watchBefore;
    if (before == null || _checking || !mounted) return;
    if (_watchElapsed > oauthWatchTimeout) {
      _stopWatching();
      return;
    }
    _checking = true;
    try {
      final fresh = await ref.read(channelsApiProvider).list();
      if (!mounted || _watchBefore == null) return;
      if (firstNewId(before, fresh) != null) {
        _stopWatching();
        ref.invalidate(channelsProvider);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Đã nối kênh mới.')));
        return;
      }
    } catch (_) {
      // Do not terminate a successful OAuth wait due to one failed request.
    } finally {
      _checking = false;
    }
    if (!mounted) return;
    _watchAttempt++;
    _scheduleCheck();
  }

  @override
  Widget build(BuildContext context) {
    final channels = ref.watch(channelsProvider);
    final access = ref.watch(accessProvider);
    final canWrite = access.can(ChannelPermissions.write);
    // Page/OA chỉ admin kết nối (quyết định 2026-10-04 #3).
    final canConnectCompany = ChannelPermissions.canConnectCompany(access);
    final canPick =
        canConnectCompany || (canWrite && ConnectableChannels.pair.isNotEmpty);
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: const OmniAppBar(title: 'Kết nối kênh'),
      // Nút + kính góc phải dưới (rà soát 12/11). `OmniFabLayer` đặt nút trên
      // thanh kính VÀ vùng an toàn — bản cũ chỉ cộng thanh (78) nên trên
      // iPhone (đáy 34) thanh kính đè lên nút.
      body: OmniFabLayer(
        fab: canPick
            ? OmniLiquidFab(
                key: const Key('channels-connect'),
                tooltip: 'Kết nối kênh',
                icon: Icons.add_link_rounded,
                onPressed: (anchor) {
                  if (_connecting) return;
                  _pickChannel(anchor);
                },
              )
            : null,
        body: OmniTopBarOverlap.wrap(
          child: Builder(
            builder: (context) {
              final topInset = OmniTopBarOverlap.of(context);
              return RefreshIndicator.adaptive(
                edgeOffset: topInset,
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
                      // Chừa thanh tab kính + vùng an toàn + nút nổi phía trên nó.
                      padding: EdgeInsets.fromLTRB(
                        16,
                        topInset,
                        16,
                        OmniFabLayer.listBottom(context, hasFab: canPick),
                      ),
                      children: [
                        if (official.isNotEmpty)
                          OmniGroupSection(
                            title: 'Kênh chính thức',
                            children: [
                              for (final connection in official)
                                ChannelTile(
                                  connection: connection,
                                  canWrite: canWrite,
                                  canReconnect: canConnectCompany,
                                  onReconnect: () =>
                                      _startOauth(connection.channel),
                                  onDisconnect: () => _disconnect(connection),
                                ),
                            ],
                          ),
                        if (official.isNotEmpty && personal.isNotEmpty)
                          const SizedBox(height: OmniGroupSection.gap),
                        if (personal.isNotEmpty)
                          OmniGroupSection(
                            title: 'Tài khoản cá nhân',
                            children: [
                              for (final connection in personal)
                                ChannelTile(
                                  connection: connection,
                                  canWrite: canWrite,
                                  onReconnect: () =>
                                      _openPair(connection.channel),
                                  onDisconnect: () => _disconnect(connection),
                                ),
                            ],
                          ),
                      ],
                    );
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
