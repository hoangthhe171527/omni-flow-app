import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/domain/channel.dart';
import '../../../core/error/app_exception.dart';
import '../../../design/components/components.dart';
import '../../../design/tokens/tokens.dart';
import '../application/channels_providers.dart';
import '../application/pairing_controller.dart';
import '../domain/pairing.dart';
import 'widgets/qr_saver.dart';

class PairPage extends ConsumerStatefulWidget {
  const PairPage({super.key, required this.channel});

  final Channel channel;

  @override
  ConsumerState<PairPage> createState() => _PairPageState();
}

class _PairPageState extends ConsumerState<PairPage>
    with WidgetsBindingObserver {
  String? _cachedQrSource;
  Uint8List? _cachedQrBytes;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startPairing();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState appState) {
    final controller = ref.read(
      pairingControllerProvider(widget.channel).notifier,
    );
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
    final controller = ref.read(
      pairingControllerProvider(widget.channel).notifier,
    );
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

    return Scaffold(
      appBar: OmniAppBar(
        title: 'Ghép nối ${meta.name}',
        fallbackBack: () => context.go('/channels'),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          16,
          12,
          16,
          OmniFabLayer.listBottom(context, hasFab: false),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _body(context, state, controller),
            if (_canSwitchAccount(state.snapshot.view)) ...[
              const SizedBox(height: OmniGroupSection.gap),
              OutlinedButton(
                onPressed: () => _startPairing(forceRelogin: true),
                child: const Text('Đăng nhập tài khoản khác'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  bool _canSwitchAccount(PairingView view) => switch (view) {
    PairingView.waiting || PairingView.qr || PairingView.connected => true,
    _ => false,
  };

  Widget _body(
    BuildContext context,
    PairingState state,
    PairingController controller,
  ) {
    final scheme = Theme.of(context).colorScheme;
    switch (state.snapshot.view) {
      case PairingView.preparing:
      case PairingView.waiting:
        return OmniGroupSection(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
              child: Column(
                children: [
                  const CircularProgressIndicator.adaptive(),
                  const SizedBox(height: OmniSpacing.lg),
                  Text(
                    _waitingMessage(state.snapshot.stage),
                    textAlign: TextAlign.center,
                    style: OmniType.body.copyWith(color: scheme.onSurface),
                  ),
                  if (state.showAgentHint) ...[
                    const SizedBox(height: OmniSpacing.md),
                    Text(
                      'Hình như chưa có máy tính nào đang chạy omni-agent. Mở agent trên máy trực 24/7 rồi thử lại.',
                      textAlign: TextAlign.center,
                      style: OmniType.micro.copyWith(
                        color: OmniColors.warningTextOf(context),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      case PairingView.qr:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OmniGroupSection(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
                  child: Column(
                    children: [
                      // Mã QR trong ô trắng bo 18 — trắng cả ở chế độ tối vì
                      // máy quét cần vùng sáng quanh mã.
                      Container(
                        width: 220,
                        height: 220,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: OmniRadius.lgAll,
                          border: Border.all(color: scheme.outlineVariant),
                        ),
                        child: Image.memory(
                          _decodeQr(state.snapshot.qr!),
                          width: 180,
                          height: 180,
                          gaplessPlayback: true,
                        ),
                      ),
                      const SizedBox(height: 14),
                      const _Hint(
                        text:
                            'Mã đổi sau khoảng 100 giây — lưu xong quét luôn.',
                      ),
                      const SizedBox(height: 14),
                      OutlinedButton.icon(
                        onPressed: () => _saveQr(state.snapshot.qr!),
                        icon: const Icon(
                          Icons.download_rounded,
                          size: OmniIconSize.md,
                        ),
                        label: const Text('Lưu ảnh QR'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: OmniGroupSection.gap),
            OmniGroupSection(
              title: 'Cách quét trên cùng một điện thoại',
              dividerIndent: 54,
              children: [
                const _PairStepRow(
                  step: 1,
                  text: 'Lưu ảnh mã QR vào thư viện máy',
                ),
                _PairStepRow(
                  step: 2,
                  text:
                      'Mở ứng dụng ${widget.channel.meta.short} › bấm biểu tượng Quét mã QR',
                ),
                const _PairStepRow(
                  step: 3,
                  text: 'Chọn Ảnh có sẵn từ thư viện vừa lưu',
                ),
              ],
            ),
          ],
        );
      case PairingView.scanned:
        return OmniGroupSection(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
              child: Column(
                children: [
                  const CircularProgressIndicator.adaptive(),
                  const SizedBox(height: OmniSpacing.lg),
                  Text(
                    'Đã quét. Mở app và bấm Đồng ý.',
                    textAlign: TextAlign.center,
                    style: OmniType.bodyStrong.copyWith(
                      color: scheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      case PairingView.connected:
        return OmniGroupSection(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
              child: Column(
                children: [
                  // Dấu tick ĐẶC + chữ "Đã kết nối!" — trạng thái đọc được qua hình dạng.
                  Icon(
                    Icons.check_circle_rounded,
                    size: OmniIconSize.hero,
                    color: scheme.primary,
                  ),
                  const SizedBox(height: OmniSpacing.md),
                  Text(
                    'Đã kết nối!',
                    textAlign: TextAlign.center,
                    style: OmniType.bodyStrong.copyWith(
                      color: scheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      case PairingView.expired:
        return _problem(context, 'Mã ghép nối đã hết hạn.', controller);
      case PairingView.failed:
        return _problem(
          context,
          state.snapshot.note ?? state.errorMessage ?? 'Không kết nối được.',
          controller,
        );
    }
  }

  Widget _problem(
    BuildContext context,
    String message,
    PairingController controller,
  ) => OmniGroupSection(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
        child: Column(
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: OmniIconSize.hero,
              color: OmniColors.dangerTextOf(context),
            ),
            const SizedBox(height: OmniSpacing.md),
            Text(message, textAlign: TextAlign.center, style: OmniType.body),
            const SizedBox(height: OmniSpacing.lg),
            FilledButton(
              onPressed: _startPairing,
              child: const Text('Thử lại'),
            ),
          ],
        ),
      ),
    ],
  );

  String _waitingMessage(String? stage) => switch (stage) {
    'logging_in' => 'Đang đăng nhập trên máy chạy agent…',
    'session_ready' => 'Đã đăng nhập. Agent đang kết nối…',
    'tunnel_pending' => 'Đang mở đường kết nối ra ngoài…',
    _ => 'Đang chuẩn bị mã QR…',
  };

  Future<void> _startPairing({bool forceRelogin = false}) async {
    await ref
        .read(pairingControllerProvider(widget.channel).notifier)
        .start(forceRelogin: forceRelogin);
  }

  Uint8List _decodeQr(String dataUrl) {
    if (_cachedQrSource == dataUrl && _cachedQrBytes != null) {
      return _cachedQrBytes!;
    }
    final payload = dataUrl.contains(',') ? dataUrl.split(',').last : dataUrl;
    final bytes = base64Decode(payload);
    _cachedQrSource = dataUrl;
    _cachedQrBytes = bytes;
    return bytes;
  }

  Future<void> _saveQr(String dataUrl) async {
    try {
      await saveQrToGallery(dataUrl);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Đã lưu vào thư viện. Quét ngay — mã đổi sau khoảng 100 giây.',
          ),
          duration: Duration(seconds: 6),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is QrSaveException ? error.message : humanError(error),
          ),
        ),
      );
    }
  }
}

/// Một bước hướng dẫn quét mã QR trên cùng điện thoại.
class _PairStepRow extends StatelessWidget {
  const _PairStepRow({required this.step, required this.text});

  final int step;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: .12),
              borderRadius: const BorderRadius.all(Radius.circular(8)),
            ),
            child: Text(
              '$step',
              style: OmniType.caption.copyWith(
                fontWeight: FontWeight.w600,
                color: scheme.primary,
                fontFeatures: OmniType.tabular,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: OmniType.body.copyWith(color: scheme.onSurface),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dải nhắc nền vàng nhạt có icon đồng hồ.
class _Hint extends StatelessWidget {
  const _Hint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final (foreground, background) = OmniTone.warning.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: background,
        borderRadius: OmniRadius.mdAll,
      ),
      child: Row(
        children: [
          Icon(Icons.timer_outlined, size: OmniIconSize.sm, color: foreground),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: OmniType.caption.copyWith(
                color: foreground,
                fontWeight: FontWeight.w500,
                fontFeatures: OmniType.tabular,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
