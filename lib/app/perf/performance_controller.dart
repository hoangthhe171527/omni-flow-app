import 'dart:io' show Platform;

import 'package:battery_plus/battery_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/preferences_store.dart';
import '../../core/storage/storage_keys.dart';
import '../../design/platform/omni_performance.dart';

/// Người dùng chọn trong Tất cả → Hiệu ứng.
enum PerfPreference { auto, full, reduced, minimal }

enum DevicePlatform { android, ios, other }

/// Những gì cần biết về máy để chọn bậc. Tách khỏi plugin để test được.
@immutable
class DeviceSnapshot {
  const DeviceSnapshot({
    required this.platform,
    this.androidSdk,
    this.ramMb,
    this.lowRam = false,
    this.iosMachine,
    this.iosMajor,
    this.batterySaver = false,
  });

  static const unknown = DeviceSnapshot(platform: DevicePlatform.other);

  final DevicePlatform platform;
  final int? androidSdk;
  final int? ramMb;
  final bool lowRam;
  final String? iosMachine;
  final int? iosMajor;
  final bool batterySaver;
}

OmniPerfTier lowerTier(OmniPerfTier t) => switch (t) {
  OmniPerfTier.full => OmniPerfTier.reduced,
  OmniPerfTier.reduced => OmniPerfTier.minimal,
  OmniPerfTier.minimal => OmniPerfTier.minimal,
};

/// Bậc thấp hơn trong hai bậc.
OmniPerfTier minTier(OmniPerfTier a, OmniPerfTier b) =>
    a.index >= b.index ? a : b;

/// Bậc theo máy (rà soát hiệu năng 08/11/2026).
///
/// - Android < 10 (API 29) thường không có Vulkan → Flutter chạy Skia/OpenGL,
///   làm mờ σ22 là điểm đau nhất; máy RAM thấp / < 3GB: tối giản.
/// - Android 10–11 (API < 31) hoặc RAM < 4GB: giảm.
/// - iPhone A10 trở xuống (`iPhone9,x`, iPhone 7) hoặc iOS < 15: giảm.
/// - Tiết kiệm pin bật: hạ thêm một bậc.
/// - Không đọc được (web, lỗi plugin): đầy đủ — đo lúc chạy sẽ hạ nếu giật.
OmniPerfTier tierForDevice(DeviceSnapshot d) {
  var tier = OmniPerfTier.full;
  switch (d.platform) {
    case DevicePlatform.android:
      final sdk = d.androidSdk ?? 99;
      final ram = d.ramMb ?? 1 << 20;
      if (sdk < 29 || d.lowRam || ram < 3072) {
        tier = OmniPerfTier.minimal;
      } else if (sdk < 31 || ram < 4096) {
        tier = OmniPerfTier.reduced;
      }
    case DevicePlatform.ios:
      final match = RegExp(r'^iPhone(\d+),').firstMatch(d.iosMachine ?? '');
      final generation = match == null ? null : int.tryParse(match.group(1)!);
      if ((generation != null && generation <= 9) || (d.iosMajor ?? 99) < 15) {
        tier = OmniPerfTier.reduced;
      }
    case DevicePlatform.other:
      break;
  }
  return d.batterySaver ? lowerTier(tier) : tier;
}

/// Đọc máy một lần (và lại khi app trở lại, vì tiết kiệm pin có thể đổi).
/// Lỗi plugin hay chạy trên web → [DeviceSnapshot.unknown].
final deviceSnapshotProvider = FutureProvider<DeviceSnapshot>((ref) async {
  if (kIsWeb) return DeviceSnapshot.unknown;
  try {
    var saver = false;
    try {
      saver = await Battery().isInBatterySaveMode;
    } on Object {
      saver = false;
    }
    final info = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final a = await info.androidInfo;
      return DeviceSnapshot(
        platform: DevicePlatform.android,
        androidSdk: a.version.sdkInt,
        ramMb: a.physicalRamSize > 0 ? a.physicalRamSize : null,
        lowRam: a.isLowRamDevice,
        batterySaver: saver,
      );
    }
    if (Platform.isIOS) {
      final i = await info.iosInfo;
      return DeviceSnapshot(
        platform: DevicePlatform.ios,
        iosMachine: i.utsname.machine,
        iosMajor: int.tryParse(i.systemVersion.split('.').first),
        ramMb: i.physicalRamSize > 0 ? i.physicalRamSize : null,
        batterySaver: saver,
      );
    }
  } on Object {
    // Không chặn app vì một plugin thông tin máy.
  }
  return DeviceSnapshot.unknown;
});

@immutable
class PerfSettings {
  const PerfSettings({required this.preference, this.learned});

  final PerfPreference preference;

  /// Bậc đã tự hạ vì đo thấy giật (chỉ dùng ở chế độ Tự động). Nhớ qua các
  /// lần mở app để máy yếu không phải giật lại mới hạ.
  final OmniPerfTier? learned;
}

class PerformanceController extends Notifier<PerfSettings> {
  @override
  PerfSettings build() {
    final store = ref.read(preferencesStoreProvider);
    return PerfSettings(
      preference: PerfPreference.values.firstWhere(
        (p) => p.name == store.getString(StorageKeys.perfPreference),
        orElse: () => PerfPreference.auto,
      ),
      learned: OmniPerfTier.values
          .where((t) => t.name == store.getString(StorageKeys.perfLearnedTier))
          .firstOrNull,
    );
  }

  Future<void> setPreference(PerfPreference p) async {
    final store = ref.read(preferencesStoreProvider);
    // Chọn lại "Tự động" = cho máy một cơ hội mới: quên bậc đã tự hạ.
    state = PerfSettings(
      preference: p,
      learned: p == PerfPreference.auto ? null : state.learned,
    );
    await store.setString(StorageKeys.perfPreference, p.name);
    if (p == PerfPreference.auto) {
      await store.remove(StorageKeys.perfLearnedTier);
    }
  }

  /// Đo thấy giật kéo dài: hạ một bậc (chỉ ở chế độ Tự động).
  Future<void> reportJank(OmniPerfTier current) async {
    if (state.preference != PerfPreference.auto) return;
    final next = lowerTier(current);
    if (next == current) return;
    state = PerfSettings(preference: state.preference, learned: next);
    await ref
        .read(preferencesStoreProvider)
        .setString(StorageKeys.perfLearnedTier, next.name);
  }
}

final performanceControllerProvider =
    NotifierProvider<PerformanceController, PerfSettings>(
      PerformanceController.new,
    );

/// Bậc đang áp dụng cho cả app.
final effectivePerfTierProvider = Provider<OmniPerfTier>((ref) {
  final settings = ref.watch(performanceControllerProvider);
  switch (settings.preference) {
    case PerfPreference.full:
      return OmniPerfTier.full;
    case PerfPreference.reduced:
      return OmniPerfTier.reduced;
    case PerfPreference.minimal:
      return OmniPerfTier.minimal;
    case PerfPreference.auto:
      final device = ref.watch(deviceSnapshotProvider).valueOrNull;
      final base = tierForDevice(device ?? DeviceSnapshot.unknown);
      return settings.learned == null ? base : minTier(base, settings.learned!);
  }
});

/// Phát hiện giật kéo dài từ thời gian khung hình (ms, max của build và
/// raster). Một cửa sổ là "giật" khi p90 vượt [budgetMs]; hai cửa sổ giật LIỀN
/// nhau thì [add] trả true một lần. Khung giật lẻ (dưới 10%) không tính.
class JankDetector {
  JankDetector({this.window = 120, this.budgetMs = 20});

  final int window;
  final double budgetMs;
  final List<double> _frames = [];
  int _jankyWindows = 0;

  bool add(double ms) {
    _frames.add(ms);
    if (_frames.length < window) return false;
    final sorted = [..._frames]..sort();
    _frames.clear();
    final p90 =
        sorted[(sorted.length * .9).floor().clamp(0, sorted.length - 1)];
    if (p90 > budgetMs) {
      _jankyWindows++;
      if (_jankyWindows >= 2) {
        _jankyWindows = 0;
        return true;
      }
    } else {
      _jankyWindows = 0;
    }
    return false;
  }
}
