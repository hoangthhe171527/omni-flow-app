import '../../../core/utils/json.dart';

/// Số nhịp poll trước khi kết luận không có máy nào chạy agent.
/// 16 nhịp × 2,5 giây ≈ 40 giây.
const pairingAgentHintTicks = 16;

/// Nhịp poll trạng thái ghép nối. Bằng web: agent đẩy QR lên theo nhịp riêng
/// của nó, poll dày hơn không nhận được sớm hơn, chỉ tốn pin và data.
const pairingPollInterval = Duration(milliseconds: 2500);

/// Kết quả `POST /channels/pair/start`.
class PairingStart {
  const PairingStart({
    required this.connectionId,
    required this.pairingCode,
    required this.expiresAt,
  });

  factory PairingStart.fromJson(Map<String, dynamic> json) => PairingStart(
    connectionId: json.strOr('connection_id', ''),
    pairingCode: json.strOr('pairing_code', ''),
    expiresAt: json.strOr('expires_at', ''),
  );

  final String connectionId;
  final String pairingCode;
  final String expiresAt;
}

/// Kết quả `GET /channels/pair/{id}/status`, nguyên như server trả.
class PairingStatus {
  const PairingStatus({required this.status, this.qr, this.stage, this.note});

  factory PairingStatus.fromJson(Map<String, dynamic> json) => PairingStatus(
    status: json.strOr('status', 'pending'),
    qr: json.str('qr'),
    stage: json.str('stage'),
    note: json.str('note'),
  );

  /// `pending` | `connected` | `expired` | `error` | `disconnected`.
  final String status;

  /// Ảnh QR dạng data URL, do agent đẩy lên. Sống khoảng 100 giây.
  final String? qr;

  /// `queued` | `logging_in` | `session_ready` | `qr` | `scanned` |
  /// `tunnel_pending` | `error`.
  final String? stage;

  /// Lời của chính agent khi nó hỏng. Nó biết chuyện gì xảy ra, app thì không.
  final String? note;
}

/// Cái màn hình ghép nối đang phải hiện.
enum PairingView { preparing, waiting, qr, scanned, connected, expired, failed }

class PairingSnapshot {
  const PairingSnapshot({required this.view, this.qr, this.stage, this.note});

  final PairingView view;

  /// Chỉ khác null khi [view] là [PairingView.qr].
  final String? qr;

  final String? stage;
  final String? note;
}

/// Gộp ba tín hiệu độc lập của server thành một trạng thái màn hình.
///
/// Hàm thuần, cố ý: đây là chỗ duy nhất quyết định người dùng nhìn thấy gì, và
/// nó phải test được mà không cần dựng widget hay giả lập mạng.
///
/// Thứ tự ưu tiên không tuỳ tiện. `connected` và `expired` là kết thúc, chúng
/// thắng mọi stage còn sót lại trong cùng phản hồi. `scanned` phải ẩn QR dù
/// server vẫn trả ảnh — mã đã tiêu rồi, hiện lại chỉ mời người ta quét lần hai.
PairingSnapshot resolvePairing(PairingStatus status) {
  final stage = status.stage ?? 'queued';
  final qr = status.qr;

  if (status.status == 'connected') {
    return const PairingSnapshot(view: PairingView.connected);
  }
  if (status.status == 'expired') {
    return const PairingSnapshot(view: PairingView.expired);
  }
  if (stage == 'error') {
    return PairingSnapshot(
      view: PairingView.failed,
      stage: stage,
      note: status.note,
    );
  }
  if (stage == 'scanned') {
    return PairingSnapshot(view: PairingView.scanned, stage: stage);
  }
  if (qr != null && qr.isNotEmpty) {
    return PairingSnapshot(view: PairingView.qr, qr: qr, stage: stage);
  }
  return PairingSnapshot(view: PairingView.waiting, stage: stage);
}

/// Có nên nói "hình như không máy nào chạy agent" chưa.
///
/// Chỉ đúng khi stage vẫn `queued`: mọi stage khác nghĩa là agent ĐÃ nhận việc,
/// lúc đó câu này sai và đẩy người dùng đi sửa nhầm chỗ.
bool shouldShowAgentHint({
  required int ticks,
  required String? stage,
  required bool sawQr,
}) {
  if (sawQr) return false;
  if (ticks < pairingAgentHintTicks) return false;
  return (stage ?? 'queued') == 'queued';
}
