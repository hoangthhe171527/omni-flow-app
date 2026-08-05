import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/channel.dart';
import '../../../design/tokens/tokens.dart';
import '../application/channels_providers.dart';
import '../application/pairing_controller.dart';
import '../data/channels_api.dart';
import '../domain/pairing.dart';
import 'widgets/qr_saver.dart';

class PairPage extends ConsumerStatefulWidget {
  const PairPage({super.key, required this.channel});

  final Channel channel;

  @override
  ConsumerState<PairPage> createState() => _PairPageState();
}

class _PairPageState extends ConsumerState<PairPage> with WidgetsBindingObserver {
  List<AgentDevice> _devices = const [];
  AgentDevice? _device;
  bool _loadingDevices = true;
  bool _started = false;
  String? _deviceError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadDevices());
  }

  Future<void> _loadDevices() async {
    setState(() { _loadingDevices = true; _deviceError = null; _started = false; });
    try {
      final devices = await ref.read(channelsApiProvider).devices();
      if (!mounted) return;
      setState(() { _devices = devices; _device = devices.isNotEmpty ? devices.first : null; });
    } catch (error) {
      if (!mounted) return;
      setState(() => _deviceError = '$error');
    } finally {
      if (mounted) setState(() => _loadingDevices = false);
    }
  }

  void _start({bool forceRelogin = false}) {
    final device = _device;
    if (device == null) return;
    setState(() => _started = true);
    ref.read(pairingControllerProvider(widget.channel).notifier).start(
      forceRelogin: forceRelogin,
      deviceId: device.id,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState appState) {
    final controller = ref.read(pairingControllerProvider(widget.channel).notifier);
    switch (appState) {
      case AppLifecycleState.resumed:
        controller.resume();
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        controller.pause();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(pairingControllerProvider(widget.channel));
    final controller = ref.read(pairingControllerProvider(widget.channel).notifier);
    final meta = widget.channel.meta;
    final navigator = Navigator.of(context);

    ref.listen(pairingControllerProvider(widget.channel), (previous, next) {
      if (previous?.snapshot.view == PairingView.connected ||
          next.snapshot.view != PairingView.connected) {
        return;
      }
      ref.invalidate(channelsProvider);
      Future.delayed(const Duration(seconds: 4), () {
        if (mounted) navigator.maybePop();
      });
    });

    if (_loadingDevices) {
      return Scaffold(appBar: AppBar(title: Text('Ghép nối ${meta.name}')), body: const Center(child: CircularProgressIndicator()));
    }
    if (_device == null) {
      return Scaffold(
        appBar: AppBar(title: Text('Ghép nối ${meta.name}')),
        body: Padding(
          padding: const EdgeInsets.all(OmniSpacing.lg),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.laptop_windows_outlined, size: 48),
            const SizedBox(height: OmniSpacing.md),
            Text(_deviceError ?? 'Chưa có máy nào chạy Omni Agent.', textAlign: TextAlign.center, style: OmniType.bodyStrong),
            const SizedBox(height: OmniSpacing.sm),
            const Text('Mở Omni Agent trên máy tính trực 24/7, đăng ký thiết bị rồi quay lại đây.', textAlign: TextAlign.center),
            const SizedBox(height: OmniSpacing.lg),
            FilledButton(onPressed: _loadDevices, child: const Text('Kiểm tra lại')),
          ]),
        ),
      );
    }
    if (!_started) {
      return Scaffold(
        appBar: AppBar(title: Text('Ghép nối ${meta.name}')),
        body: Padding(
          padding: const EdgeInsets.all(OmniSpacing.lg),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Chọn máy đang chạy Omni Agent', style: OmniType.bodyStrong),
            const SizedBox(height: OmniSpacing.sm),
            Text('Mã đăng nhập sẽ xuất hiện trên đúng máy này.', style: OmniType.micro),
            const SizedBox(height: OmniSpacing.lg),
            DropdownButtonFormField<AgentDevice>(
              initialValue: _device,
              items: _devices.map((device) => DropdownMenuItem(value: device, child: Text(device.name))).toList(),
              onChanged: (device) => setState(() => _device = device),
              decoration: const InputDecoration(labelText: 'Máy Omni Agent'),
            ),
            const SizedBox(height: OmniSpacing.lg),
            FilledButton(onPressed: _start, child: const Text('Tiếp tục')),
          ]),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text('Ghép nối ${meta.name}')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(OmniSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _body(context, state, controller),
              const SizedBox(height: OmniSpacing.xl),
              if (_canSwitchAccount(state.snapshot.view))
                TextButton(
                  onPressed: () => _start(forceRelogin: true),
                  child: const Text('Đăng nhập tài khoản khác'),
                ),
            ],
          ),
        ),
      ),
    );
  }

  bool _canSwitchAccount(PairingView view) => switch (view) {
    PairingView.waiting || PairingView.qr || PairingView.connected => true,
    _ => false,
  };

  Widget _body(BuildContext context, PairingState state, PairingController controller) {
    final scheme = Theme.of(context).colorScheme;
    switch (state.snapshot.view) {
      case PairingView.preparing:
      case PairingView.waiting:
        return Column(children: [
          const SizedBox(height: OmniSpacing.xl),
          const CircularProgressIndicator(),
          const SizedBox(height: OmniSpacing.lg),
          Text(_waitingMessage(state.snapshot.stage), style: OmniType.body),
          if (state.showAgentHint) ...[
            const SizedBox(height: OmniSpacing.md),
            Text(
              'Hình như chưa có máy tính nào đang chạy omni-agent. Mở agent trên máy trực 24/7 rồi thử lại.',
              textAlign: TextAlign.center,
              style: OmniType.micro.copyWith(color: OmniColors.warning),
            ),
          ],
        ]);
      case PairingView.qr:
        return Column(children: [
          Container(
            padding: const EdgeInsets.all(OmniSpacing.md),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: OmniRadius.mdAll,
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Image.memory(_decodeQr(state.snapshot.qr!), width: 280, height: 280, gaplessPlayback: true),
          ),
          const SizedBox(height: OmniSpacing.lg),
          FilledButton.icon(
            onPressed: () => _saveQr(state.snapshot.qr!),
            icon: const Icon(Icons.download_rounded),
            label: const Text('Lưu ảnh QR'),
          ),
          const SizedBox(height: OmniSpacing.md),
          Text(
            'Lưu ảnh → mở ${widget.channel.meta.short} → Quét mã QR → chọn ảnh vừa lưu trong thư viện.',
            textAlign: TextAlign.center,
            style: OmniType.micro.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: OmniSpacing.sm),
          Text(
            'Mã đổi sau khoảng 100 giây — lưu xong quét luôn.',
            textAlign: TextAlign.center,
            style: OmniType.micro.copyWith(color: OmniColors.warning),
          ),
        ]);
      case PairingView.scanned:
        return Column(children: [
          const SizedBox(height: OmniSpacing.xl),
          const CircularProgressIndicator(),
          const SizedBox(height: OmniSpacing.lg),
          Text('Đã quét. Mở app và bấm Đồng ý.', style: OmniType.bodyStrong),
        ]);
      case PairingView.connected:
        return Column(children: [
          const SizedBox(height: OmniSpacing.xl),
          const Icon(Icons.check_circle_rounded, size: 48, color: OmniColors.success),
          const SizedBox(height: OmniSpacing.md),
          Text('Đã kết nối!', style: OmniType.bodyStrong),
        ]);
      case PairingView.expired:
        return _problem(context, 'Mã ghép nối đã hết hạn.', controller);
      case PairingView.failed:
        return _problem(context, state.snapshot.note ?? state.errorMessage ?? 'Không kết nối được.', controller);
    }
  }

  Widget _problem(BuildContext context, String message, PairingController controller) => Column(children: [
    const SizedBox(height: OmniSpacing.xl),
    const Icon(Icons.error_outline_rounded, size: 40, color: OmniColors.destructive),
    const SizedBox(height: OmniSpacing.md),
    Text(message, textAlign: TextAlign.center, style: OmniType.body),
    const SizedBox(height: OmniSpacing.lg),
    FilledButton(onPressed: _start, child: const Text('Thử lại')),
  ]);

  String _waitingMessage(String? stage) => switch (stage) {
    'logging_in' => 'Đang đăng nhập trên máy chạy agent…',
    'tunnel_pending' => 'Đang mở đường kết nối ra ngoài…',
    _ => 'Đang chuẩn bị mã QR…',
  };

  Uint8List _decodeQr(String dataUrl) {
    final payload = dataUrl.contains(',') ? dataUrl.split(',').last : dataUrl;
    return base64Decode(payload);
  }

  Future<void> _saveQr(String dataUrl) async {
    try {
      await saveQrToGallery(dataUrl);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Đã lưu vào thư viện. Quét ngay — mã đổi sau khoảng 100 giây.'),
        duration: Duration(seconds: 6),
      ));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
    }
  }
}
