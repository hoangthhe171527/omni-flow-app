import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:network_info_plus/network_info_plus.dart';

import '../../../core/device/installation_id.dart';
import '../domain/clock_state.dart';

/// Máy chấm công: mã máy, WiFi đang kết nối, vị trí.
///
/// Tách thành giao diện để demo web và bài kiểm thay bằng bản giả — plugin
/// thật cần thiết bị. Web không có WiFi/GPS: trả [SensorReading.unavailable],
/// màn hiện "Ngoài vùng", không vỡ.
abstract class PunchSensors {
  /// Đọc WiFi + GPS. [ask] = được phép bật hộp xin quyền (chỉ khi người dùng
  /// vừa bấm Chấm — spec 03 §5.3: không xin lúc mở app). [wantGps] = cần cả
  /// GPS (không có WiFi xưởng).
  Future<SensorReading> read({required bool ask, required bool wantGps});

  /// `device_key` = SHA-256(InstallationId + mã máy của hệ điều hành).
  Future<String> deviceKey();

  /// `(platform, model)` gửi kèm lượt chấm để quản đốc nhận ra máy.
  Future<({String? platform, String? model})> deviceLabel();
}

class DevicePunchSensors implements PunchSensors {
  DevicePunchSensors(this._installationId);

  final InstallationId _installationId;
  final _info = DeviceInfoPlugin();
  final _network = NetworkInfo();
  BaseDeviceInfo? _cached;

  Future<BaseDeviceInfo?> _device() async {
    if (_cached != null) return _cached;
    try {
      return _cached = await _info.deviceInfo;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<String> deviceKey() async {
    final info = await _device();
    final vendor = switch (info) {
      IosDeviceInfo i => i.identifierForVendor ?? '',
      // device_info_plus không đọc ANDROID_ID; vân tay bản dựng + mã cài đặt
      // đủ phân biệt máy (mã cài đặt đổi khi cài lại — đúng là "máy mới").
      AndroidDeviceInfo a => '${a.fingerprint}|${a.id}',
      _ => '',
    };
    return deviceKeyOf(_installationId.value, vendor);
  }

  @override
  Future<({String? platform, String? model})> deviceLabel() async {
    final info = await _device();
    return switch (info) {
      IosDeviceInfo i => (platform: 'ios', model: i.utsname.machine),
      AndroidDeviceInfo a => (
        platform: 'android',
        model: '${a.manufacturer} ${a.model}'.trim(),
      ),
      _ => (platform: kIsWeb ? 'web' : null, model: null),
    };
  }

  @override
  Future<SensorReading> read({required bool ask, required bool wantGps}) async {
    if (kIsWeb) return const SensorReading(unavailable: true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied && ask) {
        permission = await Geolocator.requestPermission();
      }
      final granted =
          permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;
      if (!granted) {
        // Chưa xin (mở màn lần đầu) khác bị từ chối: chỉ báo "chưa cho
        // phép" khi đã hỏi rồi mà vẫn không có.
        final denied =
            permission == LocationPermission.deniedForever ||
            (ask && permission == LocationPermission.denied);
        return SensorReading(permissionDenied: denied);
      }

      String? ssid;
      String? bssid;
      try {
        ssid = await _network.getWifiName();
        bssid = await _network.getWifiBSSID();
      } catch (_) {
        // Không có WiFi / entitlement chưa bật: rơi về GPS.
      }
      if (bssid == '02:00:00:00:00:00') bssid = null;

      Position? pos;
      if (wantGps) {
        try {
          if (await Geolocator.isLocationServiceEnabled()) {
            pos = await Geolocator.getCurrentPosition(
              locationSettings: const LocationSettings(
                accuracy: LocationAccuracy.high,
                timeLimit: Duration(seconds: 10),
              ),
            );
          }
        } catch (_) {
          pos = await Geolocator.getLastKnownPosition();
        }
      }
      return SensorReading(
        ssid: ssid,
        bssid: bssid,
        lat: pos?.latitude,
        lng: pos?.longitude,
        accuracyM: pos?.accuracy,
      );
    } catch (_) {
      return const SensorReading(unavailable: true);
    }
  }
}

/// SHA-256 hex của `installationId|vendorId` — server chỉ so chuỗi, không
/// đọc được ngược ra mã máy.
String deviceKeyOf(String installationId, String vendorId) =>
    sha256.convert(utf8.encode('$installationId|$vendorId')).toString();

final punchSensorsProvider = Provider<PunchSensors>(
  (ref) => DevicePunchSensors(ref.watch(installationIdProvider)),
);
