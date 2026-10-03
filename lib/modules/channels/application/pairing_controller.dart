import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/channel.dart';
import '../../../core/error/app_exception.dart';
import '../data/channels_api.dart';
import '../domain/pairing.dart';

class PairingState {
  const PairingState({
    required this.snapshot,
    this.connectionId,
    this.showAgentHint = false,
    this.errorMessage,
  });

  final PairingSnapshot snapshot;
  final String? connectionId;
  final bool showAgentHint;
  final String? errorMessage;

  PairingState copyWith({
    PairingSnapshot? snapshot,
    String? connectionId,
    bool? showAgentHint,
    String? errorMessage,
  }) => PairingState(
    snapshot: snapshot ?? this.snapshot,
    connectionId: connectionId ?? this.connectionId,
    showAgentHint: showAgentHint ?? this.showAgentHint,
    errorMessage: errorMessage ?? this.errorMessage,
  );
}

/// Vòng đời một phiên ghép nối QR. Poll dừng khi app xuống nền và được gọi lại
/// ngay khi app trở lại, vì người dùng thường rời app để mở Zalo quét mã.
class PairingController
    extends AutoDisposeFamilyNotifier<PairingState, Channel> {
  Timer? _timer;
  int _ticks = 0;
  bool _sawQr = false;

  @override
  PairingState build(Channel arg) {
    ref.onDispose(_stop);
    return const PairingState(
      snapshot: PairingSnapshot(view: PairingView.preparing),
    );
  }

  Future<PairingStart?> start({bool forceRelogin = false}) async {
    _stop();
    _ticks = 0;
    _sawQr = false;
    state = const PairingState(
      snapshot: PairingSnapshot(view: PairingView.preparing),
    );
    try {
      final started = await ref
          .read(channelsApiProvider)
          .pairStart(arg, forceRelogin: forceRelogin);
      state = PairingState(
        snapshot: const PairingSnapshot(
          view: PairingView.waiting,
          stage: 'queued',
        ),
        connectionId: started.connectionId,
      );
      _startPolling();
      return started;
    } catch (error) {
      state = PairingState(
        snapshot: const PairingSnapshot(view: PairingView.failed),
        errorMessage: '$error',
      );
      return null;
    }
  }

  void pause() => _timer?.cancel();

  void resume() {
    if (_isFinished || state.connectionId == null) return;
    unawaited(_poll());
    _startPolling();
  }

  bool get _isFinished => switch (state.snapshot.view) {
    PairingView.connected || PairingView.expired || PairingView.failed => true,
    _ => false,
  };

  void _startPolling() {
    _timer?.cancel();
    _timer = Timer.periodic(pairingPollInterval, (_) => _poll());
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _poll() async {
    final id = state.connectionId;
    if (id == null) return;
    _ticks++;
    try {
      final status = await ref.read(channelsApiProvider).pairStatus(id);
      final snapshot = resolvePairing(status);
      if (snapshot.view == PairingView.qr) _sawQr = true;
      state = state.copyWith(
        snapshot: snapshot,
        showAgentHint: shouldShowAgentHint(
          ticks: _ticks,
          stage: snapshot.stage,
          sawQr: _sawQr,
        ),
      );
      if (_isFinished) {
        _stop();
      } else if (_ticks >= pairingMaxPolls) {
        _expire();
      }
    } on NotFoundException {
      // Phiên không còn ở server: đã hết hạn và bị dọn, hoặc (API cũ) đã gộp
      // vào kết nối có sẵn. Poll tiếp chỉ quay mãi (INB-I25).
      _expire();
    } catch (_) {
      // Lỗi mạng tạm thời không được cắt ngang phiên ghép nối 30 phút…
      // …nhưng cũng không được quay mãi.
      if (_ticks >= pairingMaxPolls) _expire();
    }
  }

  void _expire() {
    _stop();
    state = state.copyWith(
      snapshot: const PairingSnapshot(view: PairingView.expired),
      showAgentHint: false,
    );
  }
}

final pairingControllerProvider = NotifierProvider.autoDispose
    .family<PairingController, PairingState, Channel>(PairingController.new);
