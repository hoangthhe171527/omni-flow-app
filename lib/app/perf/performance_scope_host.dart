import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design/platform/omni_performance.dart';
import 'performance_controller.dart';

/// Đặt trong `MaterialApp.builder`: cấp bậc hiệu năng cho cả app và, ở chế độ
/// Tự động, nghe thời gian khung hình để tự hạ bậc khi giật kéo dài.
///
/// - Bỏ qua 3 giây đầu sau khi mở / trở lại (khung dựng màn đầu luôn nặng).
/// - Chỉ nghe khi app đang hiện; vào nền không đếm.
/// - Trở lại từ nền: đọc lại máy (tiết kiệm pin có thể vừa bật / tắt).
class PerformanceScopeHost extends ConsumerStatefulWidget {
  const PerformanceScopeHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<PerformanceScopeHost> createState() =>
      _PerformanceScopeHostState();
}

class _PerformanceScopeHostState extends ConsumerState<PerformanceScopeHost>
    with WidgetsBindingObserver {
  final _detector = JankDetector();
  DateTime _listenFrom = DateTime.now().add(const Duration(seconds: 3));
  bool _listening = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _syncListening();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopListening();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _listenFrom = DateTime.now().add(const Duration(seconds: 3));
      ref.invalidate(deviceSnapshotProvider);
      _syncListening();
    } else {
      _stopListening();
    }
  }

  /// Chỉ nghe ở chế độ Tự động và khi còn bậc để hạ.
  void _syncListening() {
    final auto =
        ref.read(performanceControllerProvider).preference ==
        PerfPreference.auto;
    final canLower =
        ref.read(effectivePerfTierProvider) != OmniPerfTier.minimal;
    if (auto && canLower) {
      if (!_listening) {
        SchedulerBinding.instance.addTimingsCallback(_onTimings);
        _listening = true;
      }
    } else {
      _stopListening();
    }
  }

  void _stopListening() {
    if (!_listening) return;
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    _listening = false;
  }

  void _onTimings(List<FrameTiming> timings) {
    if (DateTime.now().isBefore(_listenFrom)) return;
    for (final t in timings) {
      final build = t.buildDuration.inMicroseconds;
      final raster = t.rasterDuration.inMicroseconds;
      final ms = (build > raster ? build : raster) / 1000;
      if (_detector.add(ms)) {
        final current = ref.read(effectivePerfTierProvider);
        ref.read(performanceControllerProvider.notifier).reportJank(current);
        // Cho bậc mới vài giây ổn định rồi mới đo tiếp.
        _listenFrom = DateTime.now().add(const Duration(seconds: 5));
        break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tier = ref.watch(effectivePerfTierProvider);
    ref.listen(performanceControllerProvider, (_, _) => _syncListening());
    ref.listen(effectivePerfTierProvider, (_, _) => _syncListening());
    return OmniPerformanceScope(tier: tier, child: widget.child);
  }
}
