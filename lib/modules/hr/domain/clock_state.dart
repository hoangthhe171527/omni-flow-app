import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../../core/error/app_exception.dart';
import 'hr_format.dart';
import 'hr_models.dart';

/// Nút chấm lớn đang ở trạng thái nào.
enum ClockAction {
  /// "Chấm vào" (nút xanh).
  clockIn,

  /// "Chấm ra" (nút xanh lá).
  clockOut,

  /// "Đã xong ca" — tắt.
  done,

  /// "Không chấm được" — máy lạ, ngoài vùng, tháng đã khoá. Bấm vẫn thử lại
  /// (đi vào xưởng rồi bấm lại là được), nhưng trông như tắt.
  blocked,
}

/// Mã từ chối của API khiến nút khoá.
const blockingRejectCodes = {'DEVICE_NOT_BOUND', 'OUT_OF_ZONE', 'MONTH_LOCKED'};

/// Lượt kế tiếp sau khi tính các lượt còn nằm trong hàng chờ offline: chấm
/// vào lúc mất mạng thì nút phải đổi sang "Chấm ra" ngay, không đợi có mạng.
String effectiveNext(String serverNext, Iterable<String> queuedKinds) {
  var next = serverNext;
  for (final kind in queuedKinds) {
    if (kind == 'in' && next == 'in') {
      next = 'out';
    } else if (kind == 'out' && next != 'done') {
      next = 'done';
    }
  }
  return next;
}

/// Phân loại nút chấm (spec 03 §5.2): xong ca → tắt; vừa bị từ chối vì máy lạ
/// / ngoài vùng / khoá tháng → "Không chấm được"; còn lại theo lượt kế tiếp.
ClockAction classifyClock({
  required String serverNext,
  Iterable<String> queuedKinds = const [],
  String? rejectCode,
}) {
  final next = effectiveNext(serverNext, queuedKinds);
  if (next == 'done') return ClockAction.done;
  if (rejectCode != null && blockingRejectCodes.contains(rejectCode)) {
    return ClockAction.blocked;
  }
  return next == 'out' ? ClockAction.clockOut : ClockAction.clockIn;
}

/// Lượt chấm bị server từ chối (422).
@immutable
class PunchRejection {
  const PunchRejection({
    required this.code,
    required this.message,
    this.distanceM,
  });

  /// `DEVICE_NOT_BOUND` | `OUT_OF_ZONE` | `MONTH_LOCKED` | mã khác.
  final String code;
  final String message;
  final double? distanceM;

  /// Đọc từ lỗi của [ApiClient]; null khi không phải lượt chấm bị từ chối.
  static PunchRejection? fromError(Object error) {
    String? reason;
    Object? data;
    String message;
    if (error is ValidationException) {
      reason = error.reason;
      data = error.data;
      message = error.message;
    } else if (error is RequestRejectedException) {
      reason = error.reason;
      data = error.data;
      message = error.message;
    } else {
      return null;
    }
    if (reason == null || reason.isEmpty) return null;
    final result = data is Map
        ? HrPunchResult.fromJson(data.cast<String, dynamic>())
        : null;
    return PunchRejection(
      code: reason,
      message: message,
      distanceM: result?.distanceM,
    );
  }
}

/// Lỗi "không tới được máy chủ" → lượt chấm vào hàng chờ offline.
bool isOfflineError(Object error) =>
    (error is NetworkException && error.code == null) ||
    error is TimeoutException;

/// Những gì máy đọc được lúc chấm.
@immutable
class SensorReading {
  const SensorReading({
    this.ssid,
    this.bssid,
    this.lat,
    this.lng,
    this.accuracyM,
    this.permissionDenied = false,
    this.unavailable = false,
  });

  /// Chưa đọc (chưa từng xin quyền).
  static const empty = SensorReading();

  final String? ssid;
  final String? bssid;
  final double? lat;
  final double? lng;
  final double? accuracyM;

  /// Người dùng từ chối quyền vị trí.
  final bool permissionDenied;

  /// Máy không có cảm biến / nền tảng không hỗ trợ (web).
  final bool unavailable;

  bool get hasGps => lat != null && lng != null;
  bool get hasWifi => cleanSsid(ssid) != null || (bssid?.isNotEmpty ?? false);
}

/// Sắc của dòng vị trí.
enum LocationTone { ok, warn, bad, neutral }

/// Biểu tượng của dòng vị trí (map sang Icons ở tầng giao diện).
enum LocationIcon { wifi, gps, gpsOff, device, offline, lock, unknown }

/// Dòng vị trí dưới nút chấm: `WiFi xưởng · Trong xưởng`.
@immutable
class LocationLine {
  const LocationLine({
    required this.icon,
    required this.title,
    required this.value,
    required this.tone,
    this.subtitle,
  });

  final LocationIcon icon;
  final String title;
  final String value;
  final String? subtitle;
  final LocationTone tone;
}

/// Dòng vị trí từ những gì biết được: mất mạng / từ chối gần nhất / WiFi /
/// GPS. Client không có toạ độ xưởng nên "Trong vùng GPS" chỉ biết sau lượt
/// chấm; trước đó GPS chỉ nói "Đã có vị trí".
LocationLine describeLocation({
  required HrZone zone,
  SensorReading reading = SensorReading.empty,
  PunchRejection? rejection,
  double? lastDistanceM,
  bool offline = false,
}) {
  if (offline) {
    return const LocationLine(
      icon: LocationIcon.offline,
      title: 'Mất mạng',
      value: 'Lưu trên máy',
      tone: LocationTone.warn,
    );
  }
  switch (rejection?.code) {
    case 'DEVICE_NOT_BOUND':
      return const LocationLine(
        icon: LocationIcon.device,
        title: 'Điện thoại này',
        value: 'Chưa đăng ký',
        tone: LocationTone.bad,
      );
    case 'OUT_OF_ZONE':
      final d = rejection!.distanceM;
      return LocationLine(
        icon: LocationIcon.gpsOff,
        title: 'Định vị GPS',
        value: d == null ? 'Ngoài vùng' : 'Cách xưởng ${HrFormat.distance(d)}',
        tone: LocationTone.bad,
      );
    case 'MONTH_LOCKED':
      return const LocationLine(
        icon: LocationIcon.lock,
        title: 'Bảng công',
        value: 'Đã khoá',
        tone: LocationTone.bad,
      );
  }
  if (zone.wifiFor(reading.ssid) case final wifi?) {
    return LocationLine(
      icon: LocationIcon.wifi,
      title: 'WiFi xưởng',
      subtitle: wifi.name,
      value: 'Trong xưởng',
      tone: LocationTone.ok,
    );
  }
  final site = zone.site;
  if (reading.hasGps && site != null) {
    // Ước lượng trước khi chấm (server vẫn quyết định), cùng luật PunchJudge:
    // bán kính cộng sai số GPS, tối đa 50 m.
    final d = distanceM(reading.lat!, reading.lng!, site.lat, site.lng);
    final bonus = (reading.accuracyM ?? 0).clamp(0, 50);
    final inside = d <= site.radiusM + bonus;
    return LocationLine(
      icon: inside ? LocationIcon.gps : LocationIcon.gpsOff,
      title: 'Định vị GPS',
      subtitle: 'Cách xưởng ${HrFormat.distance(d)}',
      value: inside ? 'Trong xưởng' : 'Ngoài vùng',
      tone: inside ? LocationTone.ok : LocationTone.bad,
    );
  }
  if (reading.hasGps) {
    return LocationLine(
      icon: LocationIcon.gps,
      title: 'Định vị GPS',
      value: lastDistanceM == null
          ? 'Đã có vị trí'
          : 'Cách xưởng ${HrFormat.distance(lastDistanceM)}',
      tone: LocationTone.ok,
    );
  }
  if (reading.permissionDenied) {
    return const LocationLine(
      icon: LocationIcon.gpsOff,
      title: 'Vị trí',
      value: 'Chưa cho phép',
      tone: LocationTone.bad,
    );
  }
  if (reading.unavailable) {
    // Web demo / máy không có cảm biến: nói thật là ngoài vùng, không vỡ.
    return const LocationLine(
      icon: LocationIcon.gpsOff,
      title: 'Định vị GPS',
      value: 'Ngoài vùng',
      tone: LocationTone.bad,
    );
  }
  return const LocationLine(
    icon: LocationIcon.unknown,
    title: 'Vị trí',
    value: 'Kiểm tra khi chấm',
    tone: LocationTone.neutral,
  );
}

/// Khoảng cách haversine (mét) giữa hai toạ độ — cùng công thức
/// `AttendanceClock::distanceM` của API.
double distanceM(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371000.0;
  double rad(double d) => d * math.pi / 180;
  final dLat = rad(lat2 - lat1);
  final dLng = rad(lng2 - lng1);
  final a =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(rad(lat1)) *
          math.cos(rad(lat2)) *
          math.pow(math.sin(dLng / 2), 2);
  return 2 * r * math.asin(math.min(1, math.sqrt(a)));
}
