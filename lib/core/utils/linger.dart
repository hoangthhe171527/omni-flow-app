import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Quãng sống thêm mặc định của một provider autoDispose sau khi mất người nghe.
const kProviderLinger = Duration(minutes: 2);

extension ProviderLinger on Ref<Object?> {
  /// Giữ provider autoDispose sống thêm [duration] — đủ cho một lượt đi về giữa
  /// hai màn mà không tải lại, nhưng không để nó theo dõi tín hiệu realtime cả
  /// phiên cho một màn không ai còn nhìn.
  void lingerFor([Duration duration = kProviderLinger]) {
    final link = keepAlive();
    final timer = Timer(duration, link.close);
    // Đóng link CŨ mỗi lần rebuild: Riverpod không dọn danh sách link khi
    // rebuild, nên một link còn mở mà timer đã huỷ là provider không bao giờ
    // được dọn.
    onDispose(() {
      timer.cancel();
      link.close();
    });
  }
}
