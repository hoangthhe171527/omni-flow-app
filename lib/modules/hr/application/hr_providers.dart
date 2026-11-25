import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/storage/preferences_store.dart';
import '../../../core/utils/formatters.dart';
import '../../../security/session/session_controller.dart';
import '../data/hr_api.dart';
import '../data/punch_queue.dart';
import '../data/punch_sensors.dart';
import '../domain/clock_state.dart';
import '../domain/hr_format.dart';
import '../domain/hr_models.dart';
import '../domain/hr_permissions.dart';

/// Đồng hồ nghiệp vụ (null = giờ thật; bài kiểm và demo ghim lại).
final hrClockProvider = Provider<DateTime?>((ref) => null);

/// Tháng hiện tại theo giờ VN, `2026-11`.
final hrThisMonthProvider = Provider<String>(
  (ref) => HrFormat.ym(VnTime.now(ref.watch(hrClockProvider))),
);

final hrAccessProvider = Provider<HrAccess>(
  (ref) => HrAccess.of(ref.watch(sessionProvider)),
);

// ---- Chấm công của tôi ----

final hrTodayProvider = FutureProvider.autoDispose<HrToday>(
  (ref) => ref.watch(hrApiProvider).today(),
);

final hrMonthProvider = FutureProvider.autoDispose.family<HrMonth, String>(
  (ref, month) => ref.watch(hrApiProvider).myMonth(month),
);

final hrMyRequestsProvider = FutureProvider.autoDispose<HrMyRequests>(
  (ref) => ref.watch(hrApiProvider).myRequests(),
);

// ---- Quản đốc ----

final hrApprovalsProvider = FutureProvider.autoDispose<List<HrRequest>>(
  (ref) => ref.watch(hrApiProvider).approvals(),
);

/// Số đơn chờ duyệt — huy hiệu của mục "Duyệt đơn". 0 khi không có quyền
/// (không gọi mạng thay người không duyệt được).
final hrPendingApprovalsProvider = Provider<int>((ref) {
  if (!ref.watch(hrAccessProvider).approve) return 0;
  final list = ref.watch(hrApprovalsProvider).valueOrNull ?? const [];
  return list.where((r) => r.pending).length;
});

final hrWorkshopProvider = FutureProvider.autoDispose<HrWorkshopToday>(
  (ref) => ref.watch(hrApiProvider).workshopToday(),
);

/// Bảng giá mặc định (`AttendanceSettings::defaults`) — chỉ để biết MÃ loại
/// khi không đọc được cài đặt; giá thì không hiện (không bịa giá).
const _defaultContCodes = ['A', 'B', 'C', 'D'];

final hrContTypesProvider = FutureProvider.autoDispose<List<HrContType>>((
  ref,
) async {
  // `/hr/today` trả `cont_types` cho quản đốc (không cần quyền cài đặt).
  try {
    final fromToday = (await ref.watch(hrWorkshopProvider.future)).contTypes;
    if (fromToday.isNotEmpty) return fromToday;
  } catch (_) {
    // API cũ / lỗi mạng: thử cài đặt bên dưới.
  }
  final canRead = ref
      .watch(sessionProvider)
      .policy
      .can(HrPermissions.settingsManage);
  if (canRead) {
    try {
      final types = await ref.watch(hrApiProvider).contTypes();
      if (types.isNotEmpty) return types;
    } catch (_) {
      // Rơi về mã mặc định bên dưới.
    }
  }
  return [for (final c in _defaultContCodes) HrContType(code: c)];
});

// ---- Lương, thưởng ----

final hrKpiMeProvider = FutureProvider.autoDispose.family<KpiMe?, String>((
  ref,
  period,
) {
  if (!ref.watch(hrAccessProvider).kpi) return Future.value(null);
  return ref.watch(hrApiProvider).kpiMe(period);
});

final hrPayslipsProvider = FutureProvider.autoDispose<List<PayslipSummary>>(
  (ref) => ref.watch(hrApiProvider).payslips(),
);

final hrPayslipProvider = FutureProvider.autoDispose.family<Payslip, String>(
  (ref, period) => ref.watch(hrApiProvider).payslip(period),
);

// ---- Hàng chờ offline + nút chấm ----

final punchQueueProvider = Provider<PunchQueue?>((ref) {
  final session = ref.watch(sessionProvider);
  final tenant = session.tenant?.id;
  final membership = session.membershipId;
  if (tenant == null || membership == null) return null;
  return PunchQueue(
    ref.watch(sharedPreferencesProvider),
    tenantId: tenant,
    membershipId: membership,
  );
});

/// Những gì nút chấm cần ngoài `/hr/me/today`.
@immutable
class ClockUiState {
  const ClockUiState({
    this.reading = SensorReading.empty,
    this.rejection,
    this.lastDistanceM,
    this.offline = false,
    this.busy = false,
    this.queued = const [],
  });

  final SensorReading reading;
  final PunchRejection? rejection;
  final double? lastDistanceM;

  /// Lần gọi gần nhất không tới được máy chủ.
  final bool offline;
  final bool busy;

  /// Loại các lượt còn trong hàng chờ.
  final List<String> queued;

  ClockUiState copyWith({
    SensorReading? reading,
    PunchRejection? rejection,
    bool clearRejection = false,
    double? lastDistanceM,
    bool? offline,
    bool? busy,
    List<String>? queued,
  }) => ClockUiState(
    reading: reading ?? this.reading,
    rejection: clearRejection ? null : rejection ?? this.rejection,
    lastDistanceM: lastDistanceM ?? this.lastDistanceM,
    offline: offline ?? this.offline,
    busy: busy ?? this.busy,
    queued: queued ?? this.queued,
  );
}

/// Kết quả một lần bấm Chấm, để màn hiện toast.
@immutable
class PunchOutcome {
  const PunchOutcome(this.message, {this.ok = true});

  final String message;
  final bool ok;
}

class ClockController extends StateNotifier<ClockUiState> {
  ClockController(this._ref) : super(const ClockUiState()) {
    _syncQueued();
    unawaited(flush());
    unawaited(refreshReading());
  }

  final Ref _ref;
  Timer? _retry;

  HrApi get _api => _ref.read(hrApiProvider);
  PunchQueue? get _queue => _ref.read(punchQueueProvider);

  void _syncQueued() {
    final kinds = _queue?.kinds ?? const <String>[];
    state = state.copyWith(queued: kinds);
    _retry?.cancel();
    // Còn lượt chờ thì thử lại mỗi phút: app không có cờ "vừa có mạng" nên
    // hỏi định kỳ, dừng ngay khi hàng rỗng.
    if (kinds.isNotEmpty) {
      _retry = Timer.periodic(const Duration(minutes: 1), (_) => flush());
    }
  }

  /// Đọc WiFi/GPS không bật hộp xin quyền (mở màn, kéo làm mới).
  /// Không bắt WiFi xưởng mà công ty có toạ độ xưởng → đọc thêm GPS (chỉ khi
  /// đã có quyền) để dòng vị trí ước lượng "Trong xưởng / Ngoài vùng".
  Future<void> refreshReading() async {
    final sensors = _ref.read(punchSensorsProvider);
    var reading = await sensors.read(ask: false, wantGps: false);
    HrZone? zone;
    try {
      zone = (await _ref.read(hrTodayProvider.future)).zone;
    } catch (_) {
      zone = null;
    }
    if (zone?.site != null &&
        zone!.wifiFor(reading.ssid) == null &&
        !reading.permissionDenied &&
        !reading.unavailable) {
      reading = await sensors.read(ask: false, wantGps: true);
    }
    if (!mounted) return;
    state = state.copyWith(reading: reading);
  }

  /// Gửi các lượt chờ. Trả số lượt đã gửi.
  Future<int> flush() async {
    final queue = _queue;
    if (queue == null || queue.isEmpty) return 0;
    final result = await queue.flush((body) => _api.punch(body));
    if (!mounted) return result.sent;
    state = state.copyWith(
      offline: result.remaining > 0,
      rejection: result.rejected,
    );
    _syncQueued();
    if (result.sent > 0 || result.rejected != null) {
      _ref.invalidate(hrTodayProvider);
    }
    return result.sent;
  }

  /// Bấm Chấm vào / Chấm ra.
  Future<PunchOutcome> punch({
    required String kind,
    required HrZone zone,
  }) async {
    if (state.busy) return const PunchOutcome('Đang chấm…', ok: false);
    state = state.copyWith(busy: true);
    try {
      final sensors = _ref.read(punchSensorsProvider);
      // Có WiFi xưởng thì khỏi chờ GPS (server xét WiFi trước).
      var reading = await sensors.read(ask: true, wantGps: false);
      if (zone.wifiFor(reading.ssid) == null && zone.hasSite) {
        reading = await sensors.read(ask: true, wantGps: true);
      }
      final label = await sensors.deviceLabel();
      final body = <String, dynamic>{
        'kind': kind,
        'client_at': DateTime.now().toUtc().toIso8601String(),
        'ssid': cleanSsid(reading.ssid),
        'bssid': reading.bssid,
        'lat': reading.lat,
        'lng': reading.lng,
        'accuracy_m': reading.accuracyM,
        'device_key': await sensors.deviceKey(),
        'platform': label.platform,
        'model': label.model,
      }..removeWhere((_, v) => v == null);
      if (!mounted) return const PunchOutcome('');
      state = state.copyWith(reading: reading);

      try {
        final result = await _api.punch(body);
        if (!mounted) return const PunchOutcome('');
        state = state.copyWith(
          clearRejection: true,
          offline: false,
          lastDistanceM: result.distanceM,
        );
        _ref.invalidate(hrTodayProvider);
        final at = HrFormat.hm(result.at) ?? HrFormat.nowHm();
        // Có mạng lại: đẩy luôn lượt cũ còn kẹt.
        unawaited(flush());
        return PunchOutcome(
          kind == 'in' ? 'Đã chấm vào $at' : 'Đã chấm ra $at',
        );
      } catch (error) {
        if (isOfflineError(error)) {
          await _queue?.add(body);
          if (!mounted) return const PunchOutcome('');
          state = state.copyWith(offline: true);
          _syncQueued();
          return const PunchOutcome('Đã lưu trên máy, có mạng tự gửi');
        }
        final rejection = PunchRejection.fromError(error);
        if (rejection != null) {
          if (!mounted) return const PunchOutcome('');
          state = state.copyWith(rejection: rejection, offline: false);
          return PunchOutcome(rejection.message, ok: false);
        }
        return PunchOutcome(
          error is AppException ? error.message : 'Không chấm được.',
          ok: false,
        );
      }
    } finally {
      if (mounted) state = state.copyWith(busy: false);
    }
  }

  @override
  void dispose() {
    _retry?.cancel();
    super.dispose();
  }
}

final clockControllerProvider =
    StateNotifierProvider.autoDispose<ClockController, ClockUiState>(
      (ref) => ClockController(ref),
    );
