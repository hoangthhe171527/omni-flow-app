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

  /// Tăng mỗi lần mở phiên mới (và khi huỷ). Phản hồi của phiên cũ về muộn
  /// thì bỏ.
  int _session = 0;

  /// Đang có một lượt hỏi trạng thái chưa về. Mạng chậm (Dio chờ tới ~30 s)
  /// mà timer 2,5 s cứ bắn thì các lượt chồng nhau, và một `pending` cũ về
  /// sau có thể đè lên `expired`/`connected` — màn quay mãi (INB-I25).
  bool _inFlight = false;

  @override
  PairingState build(Channel arg) {
    ref.onDispose(() {
      _session++;
      _stop();
    });
    return const PairingState(
      snapshot: PairingSnapshot(view: PairingView.preparing),
    );
  }

  Future<PairingStart?> start({bool forceRelogin = false}) async {
    _stop();
    final session = ++_session;
    _inFlight = false;
    _ticks = 0;
    _sawQr = false;
    state = const PairingState(
      snapshot: PairingSnapshot(view: PairingView.preparing),
    );
    try {
      final started = await ref
          .read(channelsApiProvider)
          .pairStart(arg, forceRelogin: forceRelogin);
      if (session != _session) return null;
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
      if (session != _session) return null;
      state = PairingState(
        snapshot: const PairingSnapshot(view: PairingView.failed),
        errorMessage: humanError(
          error,
          fallback: 'Không bắt đầu ghép nối được.',
        ),
      );
      return null;
    }
  }

  void pause() => _timer?.cancel();

  void resume() {
    if (_isFinished || state.connectionId == null) return;
    if (!_inFlight) unawaited(_poll());
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

  /// Phản hồi này không còn thuộc về màn đang hiện: phiên đã đổi, đã kết
  /// thúc, hoặc provider đã huỷ.
  bool _stale(int session, String id) =>
      session != _session || _isFinished || state.connectionId != id;

  Future<void> _poll() async {
    final id = state.connectionId;
    if (id == null || _inFlight || _isFinished) return;
    final session = _session;
    _inFlight = true;
    _ticks++;
    try {
      final status = await ref.read(channelsApiProvider).pairStatus(id);
      if (_stale(session, id)) return;
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
      if (_stale(session, id)) return;
      // Phiên không còn ở server: đã hết hạn và bị dọn, hoặc (API cũ) đã gộp
      // vào kết nối có sẵn. Poll tiếp chỉ quay mãi (INB-I25).
      _expire();
    } catch (_) {
      if (_stale(session, id)) return;
      // Lỗi mạng tạm thời không được cắt ngang phiên ghép nối 30 phút…
      // …nhưng cũng không được quay mãi.
      if (_ticks >= pairingMaxPolls) _expire();
    } finally {
      if (session == _session) _inFlight = false;
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
