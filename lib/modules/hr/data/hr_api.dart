import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../domain/hr_models.dart';

/// Lời gọi API Nhân sự (omni-flow-api `modules/Hr/Interfaces/routes.php`,
/// `modules/Tasks` `/kpi/me`). Đường dẫn tương đối `/api/v1`.
class HrApi {
  HrApi(this._client);

  final ApiClient _client;

  // ---- Chấm công của tôi ----

  Future<HrToday> today() async =>
      HrToday.fromJson((await _client.get('/hr/me/today')).object);

  /// Một lượt chấm. 422 (máy lạ, ngoài vùng, khoá tháng) ném
  /// `ValidationException` với `reason` = mã từ chối.
  Future<HrPunchResult> punch(Map<String, dynamic> body) async =>
      HrPunchResult.fromJson(
        (await _client.post('/hr/me/punches', body: body)).object,
      );

  Future<HrMonth> myMonth(String month) async => HrMonth.fromJson(
    (await _client.get('/hr/me/days', query: {'month': month})).object,
  );

  Future<HrMyRequests> myRequests() async =>
      HrMyRequests.fromJson((await _client.get('/hr/me/requests')).object);

  Future<HrRequest> submitRequest(Map<String, dynamic> body) async =>
      HrRequest.fromJson(
        (await _client.post('/hr/me/requests', body: body)).object,
      );

  Future<void> cancelRequest(String id) =>
      _client.post('/hr/me/requests/${Uri.encodeComponent(id)}/cancel');

  // ---- Quản đốc ----

  Future<List<HrRequest>> approvals({String? status}) async {
    final env = await _client.get('/hr/requests', query: {'status': status});
    return [
      for (final r in env.list)
        if (HrRequest.fromJson(r) case final req when req.status != 'huy') req,
    ];
  }

  Future<void> decide(
    String id, {
    required bool approve,
    String? note,
  }) => _client.post(
    '/hr/requests/${Uri.encodeComponent(id)}/${approve ? 'approve' : 'reject'}',
    body: {'note': ?note},
  );

  Future<HrWorkshopToday> workshopToday() async =>
      HrWorkshopToday.fromJson((await _client.get('/hr/today')).object);

  /// Nhắc người chưa chấm vào. Trả số người đã nhắc (0 = vừa nhắc trong 15
  /// phút qua).
  Future<int> remind() async {
    final data = (await _client.post('/hr/today/remind')).object;
    final sent = data['sent'];
    return sent is num ? sent.toInt() : 0;
  }

  Future<void> decideOtPending(
    String membershipId,
    String date, {
    required bool approve,
  }) => _client.post(
    '/hr/days/${Uri.encodeComponent(membershipId)}/${Uri.encodeComponent(date)}/ot-pending',
    body: {'decision': approve ? 'approve' : 'dismiss'},
  );

  Future<List<HrContLoad>> contLoads(String date) async {
    final env = await _client.get('/hr/cont-loads', query: {'date': date});
    return [for (final c in env.list) HrContLoad.fromJson(c)];
  }

  Future<void> addContLoad({
    required String date,
    required String time,
    required String type,
    required List<String> membershipIds,
  }) => _client.post(
    '/hr/cont-loads',
    body: {
      'date': date,
      'time': time,
      'type': type,
      'membership_ids': membershipIds,
    },
  );

  /// Loại cont + giá từ cài đặt (cần `hr.settings.manage`). Không đọc được
  /// thì trả rỗng — chỗ gọi rơi về mã loại không giá.
  Future<List<HrContType>> contTypes() async {
    final data = (await _client.get('/hr/settings')).object;
    final settings = data['settings'] is Map
        ? (data['settings'] as Map).cast<String, dynamic>()
        : data;
    final raw = settings['cont_types'];
    if (raw is! List) return const [];
    return [
      for (final c in raw.whereType<Map>())
        if ('${c['code'] ?? ''}'.isNotEmpty)
          HrContType(
            code: '${c['code']}',
            price: c['price'] is num ? (c['price'] as num).toInt() : null,
          ),
    ];
  }

  Future<void> captureWifi({
    required String ssid,
    required String bssid,
    String? name,
  }) => _client.post(
    '/hr/settings/wifi/capture',
    body: {'ssid': ssid, 'bssid': bssid, 'name': ?name},
  );

  // ---- Lương, thưởng ----

  Future<List<PayslipSummary>> payslips() async {
    final env = await _client.get('/hr/me/payslips');
    return [for (final p in env.list) PayslipSummary.fromJson(p)]
      ..sort((a, b) => b.period.compareTo(a.period));
  }

  Future<Payslip> payslip(String period) async => Payslip.fromJson(
    period,
    (await _client.get(
      '/hr/me/payslips/${Uri.encodeComponent(period)}',
    )).object,
  );

  Future<Payslip> ackPayslip(
    String period, {
    required bool ok,
    String? note,
  }) async => Payslip.fromJson(
    period,
    (await _client.post(
      '/hr/me/payslips/${Uri.encodeComponent(period)}/ack',
      body: {'status': ok ? 'da_xem' : 'hoi_lai', 'note': ?note},
    )).object,
  );

  Future<KpiMe?> kpiMe(String period) async => KpiMe.fromJson(
    (await _client.get('/kpi/me', query: {'period': period})).data,
  );
}

final hrApiProvider = Provider<HrApi>(
  (ref) => HrApi(ref.watch(apiClientProvider)),
);
