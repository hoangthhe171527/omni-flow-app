import 'dart:async';

import 'package:flutter/widgets.dart';

/// Quyết định "ở nền đủ lâu chưa" cho mọi việc nền của app (socket realtime,
/// đăng ký push, tải lại sau khi quay lại).
///
/// Vì sao có ngưỡng: iOS sinh `inactive → resumed` khi kéo Control Center hoặc
/// hiện hộp thoại quyền, Android khi kéo thanh thông báo. Coi mỗi lần đó như
/// "app vừa sống lại" thì bắn một loạt request vô ích. Ngược lại, giữ socket
/// sống suốt thời gian ở nền thì tốn pin và dữ liệu mà tin nền đã có FCM lo.
///
/// - `hidden`/`paused` mở đồng hồ; `inactive` bị bỏ qua.
/// - Sau [grace] vẫn ở nền → [onSettled] (tạm ngắt socket).
/// - `resumed` huỷ hẹn; [onResumed] nhận `true` nếu đã ở nền >= [grace].
class BackgroundPolicy {
  BackgroundPolicy({
    required this.onSettled,
    required this.onResumed,
    this.grace = defaultGrace,
    DateTime Function()? clock,
  }) : _now = clock ?? DateTime.now;

  static const defaultGrace = Duration(seconds: 60);

  final Duration grace;
  final void Function() onSettled;
  final void Function(bool afterLongBackground) onResumed;
  final DateTime Function() _now;

  DateTime? _backgroundedAt;
  bool _settled = false;
  Timer? _timer;

  bool get isBackgrounded => _backgroundedAt != null;

  void onState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        if (_backgroundedAt != null) return;
        _backgroundedAt = _now();
        _settled = false;
        _timer?.cancel();
        _timer = Timer(grace, () {
          _timer = null;
          _settled = true;
          onSettled();
        });
      case AppLifecycleState.resumed:
        _timer?.cancel();
        _timer = null;
        final at = _backgroundedAt;
        if (at == null) return;
        final long = _settled || _now().difference(at) >= grace;
        _backgroundedAt = null;
        _settled = false;
        onResumed(long);
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}
