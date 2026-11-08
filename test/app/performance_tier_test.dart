import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/app/perf/performance_controller.dart';
import 'package:omni_app/design/platform/omni_performance.dart';

/// Chọn bậc hiệu năng tự động (rà soát 08/11/2026): máy yếu / tiết kiệm pin /
/// đo thấy giật thì hạ bậc làm mờ để đỡ giật, đỡ nóng, đỡ tốn pin.
void main() {
  group('tierForDevice', () {
    DeviceSnapshot android({
      int sdk = 34,
      int ram = 8192,
      bool lowRam = false,
      bool saver = false,
    }) => DeviceSnapshot(
      platform: DevicePlatform.android,
      androidSdk: sdk,
      ramMb: ram,
      lowRam: lowRam,
      batterySaver: saver,
    );

    test('Android mới, RAM 8GB: đầy đủ', () {
      expect(tierForDevice(android()), OmniPerfTier.full);
    });

    test('Android 9 trở xuống (API < 29, thường không Vulkan): tối giản', () {
      expect(tierForDevice(android(sdk: 28)), OmniPerfTier.minimal);
    });

    test('máy RAM thấp hoặc < 3GB: tối giản', () {
      expect(tierForDevice(android(lowRam: true)), OmniPerfTier.minimal);
      expect(tierForDevice(android(ram: 2900)), OmniPerfTier.minimal);
    });

    test('Android 10–11 hoặc RAM < 4GB: giảm', () {
      expect(tierForDevice(android(sdk: 30)), OmniPerfTier.reduced);
      expect(tierForDevice(android(ram: 3800)), OmniPerfTier.reduced);
    });

    test('tiết kiệm pin hạ thêm một bậc', () {
      expect(tierForDevice(android(saver: true)), OmniPerfTier.reduced);
      expect(
        tierForDevice(android(sdk: 30, saver: true)),
        OmniPerfTier.minimal,
      );
    });

    test('iPhone A10 trở xuống (iPhone9,x) hoặc iOS < 15: giảm', () {
      DeviceSnapshot ios(String machine, int major) => DeviceSnapshot(
        platform: DevicePlatform.ios,
        iosMachine: machine,
        iosMajor: major,
      );
      expect(tierForDevice(ios('iPhone9,3', 15)), OmniPerfTier.reduced);
      expect(tierForDevice(ios('iPhone14,2', 14)), OmniPerfTier.reduced);
      expect(tierForDevice(ios('iPhone14,2', 17)), OmniPerfTier.full);
    });

    test(
      'không đọc được máy (web, lỗi): đầy đủ — đo lúc chạy sẽ hạ nếu giật',
      () {
        expect(tierForDevice(DeviceSnapshot.unknown), OmniPerfTier.full);
      },
    );
  });

  group('JankDetector', () {
    // 60Hz: ngân sách 16,7ms. p90 > 20ms trong 2 cửa sổ liền nhau = hạ bậc.
    test('hai cửa sổ giật liền nhau thì báo hạ bậc, một cửa sổ thì không', () {
      final d = JankDetector(window: 10);
      var fired = 0;
      void feed(double ms, int n) {
        for (var i = 0; i < n; i++) {
          if (d.add(ms)) fired++;
        }
      }

      feed(30, 10);
      expect(fired, 0, reason: 'mới một cửa sổ giật');
      feed(30, 10);
      expect(fired, 1);
    });

    test('cửa sổ mượt xen giữa thì đếm lại từ đầu', () {
      final d = JankDetector(window: 10);
      var fired = 0;
      for (final ms in [
        ...List.filled(10, 30.0),
        ...List.filled(10, 8.0),
        ...List.filled(10, 30.0),
      ]) {
        if (d.add(ms)) fired++;
      }
      expect(fired, 0);
    });

    test('vài khung giật lẻ (dưới 10%) không tính là giật', () {
      final d = JankDetector(window: 20);
      var fired = 0;
      for (var w = 0; w < 4; w++) {
        for (var i = 0; i < 20; i++) {
          if (d.add(i == 0 ? 80 : 8)) fired++;
        }
      }
      expect(fired, 0);
    });
  });

  test('lower: hạ một bậc, tối giản là đáy', () {
    expect(lowerTier(OmniPerfTier.full), OmniPerfTier.reduced);
    expect(lowerTier(OmniPerfTier.reduced), OmniPerfTier.minimal);
    expect(lowerTier(OmniPerfTier.minimal), OmniPerfTier.minimal);
  });
}
