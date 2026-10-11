import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/channels_api.dart';
import '../domain/channel_connection.dart';

/// Danh sách kênh của workspace. Server đã cắt theo quyền (`channels.read` toàn
/// tenant, `channels.read.own` chỉ tài khoản mình ghép) nên client không lọc lại.
final channelsProvider = FutureProvider<List<ChannelConnection>>((ref) {
  return ref.watch(channelsApiProvider).list();
});

/// Số kênh đang chạy / đang lỗi cho dòng "Kênh kết nối" ở màn Tài khoản.
/// null khi danh sách đang tải hoặc lỗi — màn không vẽ số bịa.
final channelHealthProvider = Provider<({int running, int failing})?>((ref) {
  final list = ref.watch(channelsProvider).valueOrNull;
  if (list == null) return null;
  var running = 0, failing = 0;
  for (final c in list) {
    if (c.status == ChannelStatus.connected) running++;
    if (c.status == ChannelStatus.error) failing++;
  }
  return (running: running, failing: failing);
});

final channelErrorCountProvider = Provider<int>(
  (ref) => ref.watch(channelHealthProvider)?.failing ?? 0,
);
