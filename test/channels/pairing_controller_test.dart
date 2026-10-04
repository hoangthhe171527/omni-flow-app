import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/core/domain/channel.dart';
import 'package:omni_app/core/error/app_exception.dart';
import 'package:omni_app/core/network/api_client.dart';
import 'package:omni_app/modules/channels/application/pairing_controller.dart';
import 'package:omni_app/modules/channels/data/channels_api.dart';
import 'package:omni_app/modules/channels/domain/pairing.dart';

/// Đợt 6 P1 (INB-I25): phiên ghép nối đã kết thúc ở server thì màn phải dừng.
///
/// Trước đây `_poll` nuốt mọi lỗi: API cũ trả 404 cho phiên pending đã gộp vào
/// kết nối có sẵn (hoặc đã bị dọn), và màn hình quay mãi. API mới trả
/// `connected` kèm `connection_id` của kết nối đích.
void main() {
  late _FakeChannelsApi api;
  late ProviderContainer container;

  setUp(() {
    api = _FakeChannelsApi();
    container = ProviderContainer(
      overrides: [channelsApiProvider.overrideWithValue(api)],
    );
    addTearDown(container.dispose);
    container.listen(
      pairingControllerProvider(Channel.zaloPersonal),
      (_, _) {},
    );
  });

  PairingController controller() =>
      container.read(pairingControllerProvider(Channel.zaloPersonal).notifier);

  PairingState state() =>
      container.read(pairingControllerProvider(Channel.zaloPersonal));

  Future<void> pollOnce() async {
    controller().resume();
    // `_poll` chạy `unawaited`; nhường vòng sự kiện cho nó xong.
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
  }

  test('status 404: dừng poll và hiện "hết hạn"', () async {
    api.onStatus = (_) =>
        throw const NotFoundException('Không tìm thấy dữ liệu.');

    await controller().start();
    await pollOnce();

    expect(state().snapshot.view, PairingView.expired);
    final calls = api.statusCalls;

    await pollOnce();
    expect(api.statusCalls, calls, reason: 'Đã dừng thì không hỏi lại nữa.');
  });

  test(
    'status connected kèm connection_id khác (đã gộp): thành connected',
    () async {
      api.onStatus = (_) =>
          const PairingStatus(status: 'connected', connectionId: 'conn-cu');

      await controller().start();
      await pollOnce();

      expect(state().snapshot.view, PairingView.connected);
      final calls = api.statusCalls;
      await pollOnce();
      expect(api.statusCalls, calls);
    },
  );

  // Fix vòng 1 (I1): mạng chậm thì các lượt poll chồng nhau, và một `pending`
  // về muộn đè lên trạng thái đã kết thúc — màn quay mãi.
  test('một lượt đang chờ thì không gửi lượt thứ hai', () async {
    final first = Completer<PairingStatus>();
    api.onStatusAsync = (_) => first.future;

    await controller().start();
    controller().resume();
    controller().resume();
    await Future<void>.delayed(Duration.zero);

    expect(api.statusCalls, 1);

    first.completeError(const NotFoundException('Không tìm thấy dữ liệu.'));
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(state().snapshot.view, PairingView.expired);
  });

  test('phản hồi của phiên cũ về muộn không đè phiên mới', () async {
    final late = Completer<PairingStatus>();
    api.onStatusAsync = (_) => late.future;

    await controller().start();
    controller().resume();
    await Future<void>.delayed(Duration.zero);

    // Người dùng bấm ghép lại: phiên mới, lượt poll cũ vẫn treo.
    api.onStatusAsync = null;
    api.nextConnectionId = 'pend-2';
    await controller().start();
    expect(state().connectionId, 'pend-2');

    late.complete(const PairingStatus(status: 'connected'));
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(state().snapshot.view, PairingView.waiting);
    expect(state().connectionId, 'pend-2');
  });

  test('status error: kết thúc (failed), không poll tiếp', () async {
    api.onStatus = (_) =>
        const PairingStatus(status: 'error', note: 'Phiên Zalo hỏng');

    await controller().start();
    await pollOnce();

    expect(state().snapshot.view, PairingView.failed);
    expect(state().snapshot.note, 'Phiên Zalo hỏng');
    final calls = api.statusCalls;
    await pollOnce();
    expect(api.statusCalls, calls);
  });

  test('PairingStatus đọc connection_id của kết nối đích', () {
    final status = PairingStatus.fromJson({
      'status': 'connected',
      'connection_id': 'conn-cu',
      'qr': null,
      'stage': null,
      'note': null,
    });

    expect(status.connectionId, 'conn-cu');
    expect(resolvePairing(status).view, PairingView.connected);
  });

  test('lỗi mạng tạm thời vẫn poll tiếp, nhưng có trần', () async {
    api.onStatus = (_) => throw const NetworkException('Mất mạng.');

    await controller().start();
    await pollOnce();
    expect(state().snapshot.view, PairingView.waiting);

    for (var i = 1; i < pairingMaxPolls; i++) {
      await pollOnce();
    }
    expect(state().snapshot.view, PairingView.expired);
    final calls = api.statusCalls;
    await pollOnce();
    expect(api.statusCalls, calls);
  });
}

class _FakeChannelsApi extends ChannelsApi {
  _FakeChannelsApi() : super(ApiClient(Dio()));

  PairingStatus Function(String id) onStatus = (_) =>
      const PairingStatus(status: 'pending');

  /// Khi đặt, thắng [onStatus] — để giữ một lượt poll treo bằng Completer.
  Future<PairingStatus> Function(String id)? onStatusAsync;
  String nextConnectionId = 'pend-1';
  int statusCalls = 0;

  @override
  Future<PairingStart> pairStart(
    Channel channel, {
    bool forceRelogin = false,
  }) async => PairingStart(
    connectionId: nextConnectionId,
    pairingCode: 'code',
    expiresAt: '',
  );

  @override
  Future<PairingStatus> pairStatus(String connectionId) async {
    statusCalls++;
    final pending = onStatusAsync;
    if (pending != null) return pending(connectionId);
    return onStatus(connectionId);
  }
}
