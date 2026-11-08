import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/core/lifecycle/background_policy.dart';

void main() {
  late DateTime now;
  late int settled;
  late List<bool> resumed;
  late BackgroundPolicy policy;

  setUp(() {
    now = DateTime(2026, 11, 8, 12);
    settled = 0;
    resumed = [];
    policy = BackgroundPolicy(
      grace: const Duration(milliseconds: 100),
      clock: () => now,
      onSettled: () => settled++,
      onResumed: resumed.add,
    );
  });

  tearDown(() => policy.dispose());

  test('ở nền quá hạn: onSettled bắn một lần, resume báo "lâu"', () async {
    policy.onState(AppLifecycleState.hidden);
    policy.onState(AppLifecycleState.paused); // hidden → paused: không đặt lại
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(settled, 1);

    policy.onState(AppLifecycleState.resumed);
    expect(resumed, [true]);
  });

  test('resume trước hạn: huỷ hẹn ngắt, báo "ngắn" (không bump)', () async {
    policy.onState(AppLifecycleState.paused);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    policy.onState(AppLifecycleState.resumed);
    await Future<void>.delayed(const Duration(milliseconds: 200));

    expect(settled, 0, reason: 'đã huỷ hẹn ngắt');
    expect(resumed, [false]);
  });

  test('inactive → resumed (kéo Control Center) không làm gì cả', () {
    policy.onState(AppLifecycleState.inactive);
    policy.onState(AppLifecycleState.resumed);

    expect(settled, 0);
    expect(resumed, isEmpty);
  });

  test(
    'đồng hồ đi quá hạn dù timer chưa kịp bắn (tiến trình bị đóng băng)',
    () {
      policy.onState(AppLifecycleState.paused);
      now = now.add(const Duration(minutes: 10));
      policy.onState(AppLifecycleState.resumed);

      expect(resumed, [true]);
    },
  );
}
