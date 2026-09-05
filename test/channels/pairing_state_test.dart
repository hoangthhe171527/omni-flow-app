import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/modules/channels/domain/pairing.dart';

/// Thứ tự ưu tiên của máy trạng thái ghép nối.
///
/// Server trả về ba tín hiệu độc lập — `status`, `stage`, `qr` — và chúng có
/// thể mâu thuẫn nhau trong cùng một phản hồi. Đọc sai thứ tự thì màn hình
/// hiện một mã QR đã tiêu, hoặc quay spinner trên một phiên server đã bỏ.
void main() {
  group('resolvePairing', () {
    test('connected thắng tất cả', () {
      final s = resolvePairing(
        const PairingStatus(
          status: 'connected',
          stage: 'qr',
          qr: 'data:image/png;base64,AAAA',
        ),
      );

      expect(s.view, PairingView.connected);
    });

    test('expired thắng mọi stage — server đã bỏ mã, chờ thêm là vô ích', () {
      final s = resolvePairing(
        const PairingStatus(
          status: 'expired',
          stage: 'qr',
          qr: 'data:image/png;base64,AAAA',
        ),
      );

      expect(s.view, PairingView.expired);
    });

    test('stage error dừng lại và mang theo lời của agent', () {
      final s = resolvePairing(
        const PairingStatus(
          status: 'pending',
          stage: 'error',
          note: 'Facebook chặn đăng nhập từ máy này',
        ),
      );

      expect(s.view, PairingView.failed);
      expect(s.note, 'Facebook chặn đăng nhập từ máy này');
    });

    test('scanned ẩn QR dù server vẫn trả về ảnh', () {
      final s = resolvePairing(
        const PairingStatus(
          status: 'pending',
          stage: 'scanned',
          qr: 'data:image/png;base64,AAAA',
        ),
      );

      expect(s.view, PairingView.scanned);
      expect(s.qr, isNull);
    });

    test('có QR và chưa quét thì hiện QR', () {
      final s = resolvePairing(
        const PairingStatus(
          status: 'pending',
          stage: 'qr',
          qr: 'data:image/png;base64,AAAA',
        ),
      );

      expect(s.view, PairingView.qr);
      expect(s.qr, 'data:image/png;base64,AAAA');
    });

    test('chưa có gì thì là đang chờ, giữ stage để hiện đúng câu mô tả', () {
      final s = resolvePairing(
        const PairingStatus(status: 'pending', stage: 'tunnel_pending'),
      );

      expect(s.view, PairingView.waiting);
      expect(s.stage, 'tunnel_pending');
    });

    test('stage null coi như queued', () {
      final s = resolvePairing(const PairingStatus(status: 'pending'));

      expect(s.view, PairingView.waiting);
      expect(s.stage, 'queued');
    });

    test('QR rỗng không tính là có QR', () {
      final s = resolvePairing(const PairingStatus(status: 'pending', qr: ''));

      expect(s.view, PairingView.waiting);
    });
  });

  group('shouldShowAgentHint', () {
    test('đủ 16 nhịp mà vẫn queued và chưa từng thấy QR thì cảnh báo', () {
      expect(
        shouldShowAgentHint(ticks: 16, stage: 'queued', sawQr: false),
        isTrue,
      );
    });

    test('chưa đủ 16 nhịp thì im — 40 giây đầu là chờ bình thường', () {
      expect(
        shouldShowAgentHint(ticks: 15, stage: 'queued', sawQr: false),
        isFalse,
      );
    });

    test('stage khác queued nghĩa là agent đã nhận việc, cảnh báo đó sai', () {
      expect(
        shouldShowAgentHint(ticks: 40, stage: 'logging_in', sawQr: false),
        isFalse,
      );
    });

    test('đã từng thấy QR thì agent chắc chắn đang chạy', () {
      expect(
        shouldShowAgentHint(ticks: 40, stage: 'queued', sawQr: true),
        isFalse,
      );
    });

    test('stage null coi như queued', () {
      expect(shouldShowAgentHint(ticks: 20, stage: null, sawQr: false), isTrue);
    });
  });

  group('PairingStatus.fromJson', () {
    test('đọc đúng bốn trường server trả về', () {
      final s = PairingStatus.fromJson({
        'status': 'pending',
        'qr': 'data:image/png;base64,AAAA',
        'stage': 'qr',
        'note': null,
      });

      expect(s.status, 'pending');
      expect(s.qr, 'data:image/png;base64,AAAA');
      expect(s.stage, 'qr');
      expect(s.note, isNull);
    });
  });

  group('PairingStart.fromJson', () {
    test('đọc connection_id và pairing_code', () {
      final s = PairingStart.fromJson({
        'connection_id': 'abc123',
        'channel_id': 'zalo_personal',
        'pairing_code': 'K7M2X9QP',
        'expires_at': '2026-08-04T12:30:00Z',
      });

      expect(s.connectionId, 'abc123');
      expect(s.pairingCode, 'K7M2X9QP');
      expect(s.expiresAt, '2026-08-04T12:30:00Z');
    });
  });
}
