import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/channels_api.dart';
import '../domain/channel_connection.dart';

/// Danh sách kênh của workspace. Server đã cắt theo quyền (`channels.read` toàn
/// tenant, `channels.read.own` chỉ tài khoản mình ghép) nên client không lọc lại.
final channelsProvider = FutureProvider<List<ChannelConnection>>((ref) {
  return ref.watch(channelsApiProvider).list();
});
