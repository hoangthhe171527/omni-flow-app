import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../security/session/session_controller.dart';

/// 403 của API khi module bị tắt ở workspace (Đợt 6b B3):
/// `{success:false, message, code:'FEATURE_DISABLED', error_code, feature}`.
bool isFeatureDisabledResponse(Response<dynamic>? response) {
  if (response?.statusCode != 403) return false;
  final body = response?.data;
  if (body is! Map) return false;
  return body['code'] == 'FEATURE_DISABLED' ||
      body['error_code'] == 'FEATURE_DISABLED';
}

/// Đọc lại cờ tính năng (`/auth/context`) khi API báo module đã tắt (MS-I33),
/// để menu ẩn module đó mà không cần đăng nhập lại.
///
/// Gộp các lượt đang chạy, và nghỉ [cooldown] giữa hai lượt — cùng lý do với
/// web `src/lib/feature-disabled.ts`: một màn poll 5 giây cứ nhận 403 thì không
/// được biến thành một cơn bão `/auth/context`. Lỗi khi đọc lại bị nuốt: lỗi
/// gốc vẫn đi tới màn hình với câu của API.
class FeatureFlagRefresher {
  FeatureFlagRefresher(
    this._refresh, {
    DateTime Function()? now,
    this.cooldown = const Duration(seconds: 30),
  }) : _now = now ?? DateTime.now;

  final Future<void> Function() _refresh;
  final DateTime Function() _now;
  final Duration cooldown;

  Future<void>? _inFlight;
  DateTime? _lastStarted;

  Future<void> request() {
    final active = _inFlight;
    if (active != null) return active;

    final now = _now();
    final last = _lastStarted;
    if (last != null && now.difference(last) < cooldown) return Future.value();
    _lastStarted = now;

    final run = () async {
      try {
        await _refresh();
      } on Object catch (error) {
        debugPrint('Feature flag refresh failed: $error');
      }
    }();
    _inFlight = run;
    return run.whenComplete(() => _inFlight = null);
  }
}

final featureFlagRefresherProvider = Provider<FeatureFlagRefresher>((ref) {
  return FeatureFlagRefresher(() async {
    // Chỉ khi đã vào một workspace: đang chọn workspace hay đã hết phiên thì
    // `/auth/context` không có nghĩa, và nạp nó sẽ đè trạng thái phiên.
    if (!ref.read(sessionProvider).isAuthenticated) return;
    await ref.read(sessionControllerProvider.notifier).refreshContext();
  });
});
