import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/core/realtime/realtime_client.dart';
import 'package:omni_app/modules/inbox/application/inbox_realtime.dart';

/// Nhịp poll dự phòng phải tính từ trạng thái socket THẬT (MS-I38, phần app).
///
/// Trước đợt này nhịp chỉ có hai giá trị cố định (2 phút / 5 giây) và một
/// socket rớt là mọi máy trong tenant quay lại 5 giây một lượt, cùng lúc —
/// đúng lúc server vừa khởi động lại là chỗ dễ sập nhất. Nên: không poll khi
/// kênh còn sống, và khi rớt thì giãn dần 1 → 2 → 4 kèm nhiễu ±20% để các máy
/// không gõ cửa cùng một nhịp.
void main() {
  group('InboxRealtime.pollInterval', () {
    test('kênh còn sống thì không poll', () {
      final realtime = InboxRealtime.forTest(state: RealtimeStatus.connected);

      expect(realtime.pollInterval, isNull);
    });

    test(
      'vừa rớt thì poll lại ở 4–6 giây; hai nhịp giãn sau là 16–24 giây',
      () {
        final realtime = InboxRealtime.forTest(state: RealtimeStatus.connected);
        expect(realtime.pollInterval, isNull);

        realtime.setState(RealtimeStatus.disconnected);
        expect(
          realtime.pollInterval!.inMilliseconds,
          inInclusiveRange(4000, 6000),
        );

        realtime.tickBackoff();
        realtime.tickBackoff();
        expect(
          realtime.pollInterval!.inMilliseconds,
          inInclusiveRange(16000, 24000),
        );
      },
    );

    test('nhiễu ±20% nên hai máy không gõ cửa cùng một nhịp', () {
      final values = <int>{};
      for (var seed = 0; seed < 40; seed++) {
        final realtime = InboxRealtime.forTest(
          state: RealtimeStatus.disconnected,
          random: Random(seed),
        );
        values.add(realtime.pollInterval!.inMilliseconds);
      }

      expect(
        values.length,
        greaterThan(1),
        reason: 'Nhịp cố định là cả tenant quay lại cùng một giây.',
      );
      expect(values.every((ms) => ms >= 4000 && ms <= 6000), isTrue);
    });

    test('nối lại được thì xoá nhịp giãn, rớt lần sau bắt đầu lại từ đầu', () {
      final realtime = InboxRealtime.forTest(
        state: RealtimeStatus.disconnected,
      );
      realtime.tickBackoff();
      realtime.tickBackoff();
      expect(realtime.backoffStep, 2);

      realtime.setState(RealtimeStatus.connected);
      expect(realtime.pollInterval, isNull);
      expect(realtime.backoffStep, 0);

      realtime.setState(RealtimeStatus.disconnected);
      expect(
        realtime.pollInterval!.inMilliseconds,
        inInclusiveRange(4000, 6000),
      );
    });

    test('một lượt nối lại thất bại KHÔNG xoá nhịp giãn đang có', () {
      final realtime = InboxRealtime.forTest(
        state: RealtimeStatus.disconnected,
      );
      realtime.tickBackoff();
      realtime.tickBackoff();

      // connecting → disconnected là một lượt thử nối lại không thành. Xoá
      // nhịp giãn ở đây là quay về gõ cửa 5 giây một lượt khi server đang sập.
      realtime.setState(RealtimeStatus.connecting);
      realtime.setState(RealtimeStatus.disconnected);

      expect(realtime.backoffStep, 2);
      expect(
        realtime.pollInterval!.inMilliseconds,
        inInclusiveRange(16000, 24000),
      );
    });

    test('nhịp giãn có trần: 8 lần nhịp gốc', () {
      final realtime = InboxRealtime.forTest(
        state: RealtimeStatus.disconnected,
      );
      for (var i = 0; i < 20; i++) {
        realtime.tickBackoff();
      }

      expect(realtime.backoffStep, InboxRealtime.maxBackoffSteps);
      expect(
        realtime.pollInterval!.inMilliseconds,
        inInclusiveRange(32000, 48000),
      );
    });

    test('bản dựng không có realtime thì poll ở nhịp gốc, không nhiễu', () {
      final realtime = InboxRealtime.forTest(state: RealtimeStatus.disabled);

      // Không có kênh nào để chờ, cũng không có đợt nối lại đồng loạt nào để
      // dàn ra — nhịp cố định như trước.
      expect(realtime.pollInterval, RealtimePolling.inboxFallback);
      realtime.tickBackoff();
      expect(realtime.pollInterval, RealtimePolling.inboxFallback);
    });

    test('màn chat lấy nhịp gốc 8 giây của nó', () {
      final realtime = InboxRealtime.thread(
        status: RealtimeStatus.disconnected,
      );

      expect(
        realtime.pollInterval!.inMilliseconds,
        inInclusiveRange(6400, 9600),
      );
    });

    test('setState trả true đúng khi trạng thái đổi (để dựng lại hẹn giờ)', () {
      final realtime = InboxRealtime.forTest(
        state: RealtimeStatus.disconnected,
      );

      expect(realtime.setState(RealtimeStatus.disconnected), isFalse);
      expect(realtime.setState(RealtimeStatus.connected), isTrue);
    });

    test('connecting ↔ disconnected KHÔNG đòi dựng lại hẹn giờ', () {
      // Hai lần đổi mỗi lượt nối lại, mà người gọi `cancel()` + dựng lại từ 0
      // cho mỗi lần đổi, thì nhịp 4–6 giây không bao giờ chạy tới: lượt poll
      // đầu của một đợt mất kết nối lùi tới t ≈ 19 giây.
      final realtime = InboxRealtime.forTest(
        state: RealtimeStatus.disconnected,
      );

      expect(realtime.setState(RealtimeStatus.connecting), isFalse);
      expect(realtime.setState(RealtimeStatus.disconnected), isFalse);
      // Rời/vào `connected` là đổi CHẾ ĐỘ: có poll hay không poll.
      expect(realtime.setState(RealtimeStatus.connected), isTrue);
      expect(realtime.setState(RealtimeStatus.connecting), isTrue);
    });
  });
}
