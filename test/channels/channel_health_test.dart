import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/modules/channels/application/channels_providers.dart';
import 'package:omni_app/modules/channels/domain/channel_connection.dart';

ChannelConnection conn(String id, ChannelStatus s) =>
    ChannelConnection.fromJson({
      'id': id,
      'channel_id': 'zalo_oa',
      'name': 'Kênh $id',
      'status': s.name,
    });

void main() {
  test('đếm chạy / lỗi; đang tải thì null', () async {
    final c = ProviderContainer(
      overrides: [
        channelsProvider.overrideWith(
          (ref) async => [
            conn('a', ChannelStatus.connected),
            conn('b', ChannelStatus.connected),
            conn('c', ChannelStatus.error),
            conn('d', ChannelStatus.pending),
          ],
        ),
      ],
    );
    addTearDown(c.dispose);

    expect(c.read(channelHealthProvider), isNull);
    expect(c.read(channelErrorCountProvider), 0);
    await c.read(channelsProvider.future);
    expect(c.read(channelHealthProvider), (running: 2, failing: 1));
    expect(c.read(channelErrorCountProvider), 1);
  });
}
