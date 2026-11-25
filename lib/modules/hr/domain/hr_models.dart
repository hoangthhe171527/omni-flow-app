import 'package:flutter/foundation.dart';

import 'hr_format.dart';

// Mô hình dữ liệu Nhân sự, đọc an toàn: khoá thiếu / sai kiểu không làm vỡ
// màn — API mới thêm khoá, API cũ thiếu khoá đều đọc được. Hợp đồng nằm ở
// omni-flow-api `modules/Hr` (AttendanceService, LeaveRequestService,
// PayrollService) và `modules/Tasks` (TeamKpiService::me).

double _d(Object? v) =>
    v is num ? v.toDouble() : double.tryParse('${v ?? ''}') ?? 0;

int _i(Object? v) => v is num ? v.round() : int.tryParse('${v ?? ''}') ?? 0;

String? _s(Object? v) {
  if (v == null) return null;
  final s = v is String ? v : '$v';
  return s.isEmpty ? null : s;
}

bool _b(Object? v) => v == true || v == 1 || v == '1' || v == 'true';

Map<String, dynamic> _m(Object? v) =>
    v is Map ? v.cast<String, dynamic>() : const <String, dynamic>{};

List<Map<String, dynamic>> _l(Object? v) => v is List
    ? v.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList()
    : const [];

List<String> _strings(Object? v) =>
    v is List ? v.map((e) => '$e').where((s) => s.isNotEmpty).toList() : [];

/// Ca làm (`hr_shifts`).
@immutable
class HrShift {
  const HrShift({
    required this.name,
    required this.start,
    required this.end,
    this.otFrom,
    this.weekdays = const [],
  });

  factory HrShift.fromJson(Map<String, dynamic> j) => HrShift(
    name: _s(j['name']) ?? 'Ca làm',
    start: _s(j['start']) ?? '',
    end: _s(j['end']) ?? '',
    otFrom: _s(j['ot_from']),
    weekdays: [
      for (final w in (j['weekdays'] is List ? j['weekdays'] as List : []))
        _i(w),
    ],
  );

  final String name;
  final String start;
  final String end;
  final String? otFrom;
  final List<int> weekdays;

  /// `Ca hành chính · 08:00 – 17:30`.
  String get label => start.isEmpty ? name : '$name · $start – $end';

  /// `Ca 08:00 – 17:30`.
  String get hours => start.isEmpty ? name : 'Ca $start – $end';
}

/// Trạng thái ngày công (`DayBuilder`): `w` đi làm, `p` phép, `le` lễ, `k`
/// nghỉ không lương, `x` thiếu chấm, `off` không có lịch, `fut` chưa tới.
@immutable
class HrDay {
  const HrDay({
    required this.date,
    required this.status,
    this.scheduled = false,
    this.work = 0,
    this.paidLeave = 0,
    this.unpaid = 0,
    this.holiday = 0,
    this.missing = 0,
    this.inAt,
    this.outAt,
    this.method,
    this.lateMin = 0,
    this.otHours = 0,
    this.otPendingHours = 0,
    this.cont = const {},
    this.explainDue,
    this.holidayName,
    this.manual = false,
    this.leaveSession,
    this.leaveKind,
  });

  factory HrDay.fromJson(Map<String, dynamic> j) {
    final leave = _m(j['leave']);
    return HrDay(
      date: _s(j['date']) ?? '',
      status: _s(j['status']) ?? 'off',
      scheduled: _b(j['scheduled']),
      work: _d(j['work']),
      paidLeave: _d(j['paid_leave']),
      unpaid: _d(j['unpaid']),
      holiday: _d(j['holiday']),
      missing: _d(j['missing']),
      inAt: _s(j['in_at']),
      outAt: _s(j['out_at']),
      method: _s(j['method']),
      lateMin: _i(j['late_min']),
      otHours: _d(j['ot_hours']),
      otPendingHours: _d(j['ot_pending_hours']),
      cont: {for (final e in _m(j['cont']).entries) e.key: _i(e.value)},
      explainDue: _s(j['explain_due']),
      holidayName: _s(j['holiday_name']),
      manual: _b(j['manual']),
      leaveSession: _s(leave['session']),
      leaveKind: _s(leave['kind']),
    );
  }

  final String date;
  final String status;
  final bool scheduled;
  final double work;
  final double paidLeave;
  final double unpaid;
  final double holiday;
  final double missing;
  final String? inAt;
  final String? outAt;
  final String? method;
  final int lateMin;
  final double otHours;
  final double otPendingHours;
  final Map<String, int> cont;
  final String? explainDue;
  final String? holidayName;
  final bool manual;
  final String? leaveSession;
  final String? leaveKind;

  int get dayOfMonth => HrFormat.dateOf(date)?.day ?? 0;

  bool get isLate => status == 'w' && lateMin > 0;
  bool get hasOt => otHours > 0;

  /// Ngày cần giải trình: muộn, thiếu chấm.
  bool get needsExplain => isLate || status == 'x';
}

/// Tổng tháng (`DayBuilder::totals`): G đi làm, H phép + lễ, J = G + H, I
/// không lương + thiếu, Y lần muộn, X phút muộn, M giờ tăng ca, T ngày có lịch.
@immutable
class HrMonthTotals {
  const HrMonthTotals({
    this.g = 0,
    this.h = 0,
    this.j = 0,
    this.i = 0,
    this.lateCount = 0,
    this.lateMinutes = 0,
    this.otHours = 0,
    this.scheduled = 0,
    this.missing = 0,
    this.otPending = 0,
    this.scheduledMonth,
    this.cont = const {},
  });

  factory HrMonthTotals.fromJson(Map<String, dynamic> j) => HrMonthTotals(
    g: _d(j['G']),
    h: _d(j['H']),
    j: _d(j['J']),
    i: _d(j['I']),
    lateCount: _i(j['Y']),
    lateMinutes: _i(j['X']),
    otHours: _d(j['M']),
    scheduled: _i(j['T']),
    missing: _d(j['missing']),
    otPending: _d(j['ot_pending']),
    scheduledMonth: j.containsKey('scheduled_month')
        ? _i(j['scheduled_month'])
        : null,
    cont: {for (final e in _m(j['cont']).entries) e.key: _i(e.value)},
  );

  final double g;
  final double h;
  final double j;
  final double i;
  final int lateCount;
  final int lateMinutes;
  final double otHours;
  final int scheduled;
  final double missing;
  final double otPending;

  /// Số ngày có lịch CẢ tháng (chỉ `/hr/me/today` gửi).
  final int? scheduledMonth;
  final Map<String, int> cont;

  /// `1 lần · 20 phút`, `Không` khi chưa muộn.
  String get lateLabel => lateCount == 0
      ? 'Không'
      : '$lateCount lần · ${HrFormat.duration(lateMinutes)}';
}

/// Một WiFi xưởng (tên + SSID; BSSID chỉ server giữ).
@immutable
class HrWifi {
  const HrWifi({required this.name, required this.ssid});

  final String name;
  final String ssid;
}

@immutable
class HrZone {
  const HrZone({
    this.wifi = const [],
    this.hasSite = false,
    this.radiusM,
    this.lockDevice = true,
    this.site,
  });

  factory HrZone.fromJson(Map<String, dynamic> j) => HrZone(
    wifi: [
      for (final w in _l(j['wifi']))
        HrWifi(
          name: _s(w['name']) ?? _s(w['ssid']) ?? '',
          ssid: _s(w['ssid']) ?? '',
        ),
    ],
    hasSite: _b(j['has_site']),
    radiusM: j['radius_m'] == null ? null : _i(j['radius_m']),
    lockDevice: j['lock_device'] == null ? true : _b(j['lock_device']),
    site: HrSite.of(j['site']),
  );

  final List<HrWifi> wifi;
  final bool hasSite;
  final int? radiusM;
  final bool lockDevice;

  /// Toạ độ xưởng + bán kính (null = công ty chưa đặt).
  final HrSite? site;

  /// WiFi xưởng khớp SSID đang kết nối (so không phân biệt hoa thường).
  HrWifi? wifiFor(String? ssid) {
    final s = _cleanSsid(ssid);
    if (s == null) return null;
    for (final w in wifi) {
      if (w.ssid.toLowerCase() == s.toLowerCase()) return w;
    }
    return null;
  }
}

/// iOS/Android trả SSID trong ngoặc kép (`"Xuong-50"`); `<unknown ssid>` là
/// không đọc được.
String? _cleanSsid(String? raw) {
  if (raw == null) return null;
  var s = raw.trim();
  if (s.length >= 2 && s.startsWith('"') && s.endsWith('"')) {
    s = s.substring(1, s.length - 1);
  }
  if (s.isEmpty || s == '<unknown ssid>') return null;
  return s;
}

/// SSID đã bỏ ngoặc kép, hoặc null.
String? cleanSsid(String? raw) => _cleanSsid(raw);

/// `GET /hr/me/today`.
@immutable
class HrToday {
  const HrToday({
    required this.date,
    required this.next,
    this.shift,
    this.day,
    this.deviceBound = false,
    this.zone = const HrZone(),
    this.month = const HrMonthTotals(),
  });

  factory HrToday.fromJson(Map<String, dynamic> j) {
    final shift = _m(j['shift']);
    final day = _m(j['day']);
    final next = _s(j['next']);
    return HrToday(
      date: _s(j['date']) ?? '',
      next: const {'in', 'out', 'done'}.contains(next) ? next! : 'in',
      shift: shift.isEmpty ? null : HrShift.fromJson(shift),
      day: day.isEmpty ? null : HrDay.fromJson(day),
      deviceBound: j['device'] is Map,
      zone: HrZone.fromJson(_m(j['zone'])),
      month: HrMonthTotals.fromJson(_m(j['month'])),
    );
  }

  final String date;

  /// `in` | `out` | `done` — lượt chấm kế tiếp theo server.
  final String next;
  final HrShift? shift;
  final HrDay? day;
  final bool deviceBound;
  final HrZone zone;
  final HrMonthTotals month;
}

/// `GET /hr/me/days?month=`.
@immutable
class HrMonth {
  const HrMonth({
    required this.month,
    this.days = const [],
    this.totals = const HrMonthTotals(),
    this.locked = false,
  });

  factory HrMonth.fromJson(Map<String, dynamic> j) => HrMonth(
    month: _s(j['month']) ?? '',
    days: [for (final d in _l(j['days'])) HrDay.fromJson(d)],
    totals: HrMonthTotals.fromJson(_m(j['totals'])),
    locked: _b(j['locked']),
  );

  final String month;
  final List<HrDay> days;
  final HrMonthTotals totals;
  final bool locked;

  HrDay? dayOf(int dayOfMonth) {
    for (final d in days) {
      if (d.dayOfMonth == dayOfMonth) return d;
    }
    return null;
  }

  /// Ngày nghỉ phép đã dùng trong tháng.
  double get leaveDays => days.fold(0, (s, d) => s + d.paidLeave + d.unpaid);
}

/// Kết quả `POST /hr/me/punches` (201) hoặc `data` của 422.
@immutable
class HrPunchResult {
  const HrPunchResult({
    required this.accepted,
    this.rejectCode,
    this.method,
    this.at,
    this.distanceM,
  });

  factory HrPunchResult.fromJson(Map<String, dynamic> j) => HrPunchResult(
    accepted: _b(j['accepted']),
    rejectCode: _s(j['reject_code']),
    method: _s(j['method']),
    at: _s(j['at']),
    distanceM: j['distance_m'] == null ? null : _d(j['distance_m']),
  );

  final bool accepted;
  final String? rejectCode;
  final String? method;
  final String? at;
  final double? distanceM;
}

/// Loại đơn (`hr_requests.type`).
enum HrRequestType {
  phep('phep', 'Nghỉ phép'),
  tangca('tangca', 'Tăng ca'),
  giaitrinh('giaitrinh', 'Giải trình'),
  tamung('tamung', 'Tạm ứng');

  const HrRequestType(this.code, this.label);

  final String code;
  final String label;

  static HrRequestType? of(String? code) {
    for (final t in values) {
      if (t.code == code) return t;
    }
    return null;
  }
}

/// Một đơn (`hr_requests`). Trạng thái: `cho` chờ duyệt, `duyet`, `tuchoi`,
/// `huy`.
@immutable
class HrRequest {
  const HrRequest({
    required this.id,
    required this.type,
    required this.status,
    this.membershipId,
    this.name,
    this.from,
    this.to,
    this.date,
    this.session,
    this.leaveKind,
    this.hours,
    this.inAt,
    this.outAt,
    this.amount,
    this.payrollPeriod,
    this.reason,
    this.decisionNote,
    this.createdAt,
  });

  factory HrRequest.fromJson(Map<String, dynamic> j) => HrRequest(
    id: _s(j['id']) ?? '',
    type: HrRequestType.of(_s(j['type'])) ?? HrRequestType.giaitrinh,
    status: _s(j['status']) ?? 'cho',
    membershipId: _s(j['membership_id']),
    name: _s(j['name']),
    from: _s(j['from']),
    to: _s(j['to']),
    date: _s(j['date']),
    session: _s(j['session']),
    leaveKind: _s(j['leave_kind']),
    hours: j['hours'] == null ? null : _d(j['hours']),
    inAt: _s(j['in_at']),
    outAt: _s(j['out_at']),
    amount: j['amount'] == null ? null : _i(j['amount']),
    payrollPeriod: _s(j['payroll_period']),
    reason: _s(j['reason']),
    decisionNote: _s(j['decision_note']),
    createdAt: _s(j['created_at']),
  );

  final String id;
  final HrRequestType type;
  final String status;
  final String? membershipId;

  /// Tên người gửi (chỉ danh sách của người duyệt).
  final String? name;
  final String? from;
  final String? to;
  final String? date;
  final String? session;
  final String? leaveKind;
  final double? hours;
  final String? inAt;
  final String? outAt;
  final int? amount;
  final String? payrollPeriod;
  final String? reason;
  final String? decisionNote;
  final String? createdAt;

  bool get pending => status == 'cho';

  String get typeLabel =>
      type == HrRequestType.phep && leaveKind == 'khong_luong'
      ? 'Nghỉ không lương'
      : type.label;

  /// Dòng chi tiết như bản duyệt: `Thứ Bảy, 28/11 · cả ngày`.
  String get detail => switch (type) {
    HrRequestType.phep => [
      if (to != null && to != from)
        '${HrFormat.dayMonthOf(from)} – ${HrFormat.dayMonthOf(to)}'
      else
        HrFormat.dayLabelOf(from ?? date),
      switch (session) {
        'sang' => 'buổi sáng',
        'chieu' => 'buổi chiều',
        _ => 'cả ngày',
      },
    ].join(' · '),
    HrRequestType.tangca =>
      '${HrFormat.dayLabelOf(date)} · ${HrFormat.decimal(hours ?? 0)} giờ',
    HrRequestType.giaitrinh => [
      HrFormat.dayLabelOf(date),
      if (HrFormat.hm(inAt) case final t?) 'vào $t',
      if (HrFormat.hm(outAt) case final t?) 'ra $t',
    ].join(' · '),
    HrRequestType.tamung => HrFormat.money(amount ?? 0),
  };

  /// Giờ gửi đơn: `07:40 · 24/11`.
  String get sentLabel {
    final t = HrFormat.hm(createdAt);
    final parsed = createdAt == null ? null : DateTime.tryParse(createdAt!);
    if (t == null || parsed == null) return '';
    final d = HrFormat.dayMonthOf(
      HrFormat.ymd(parsed.toUtc().add(const Duration(hours: 7))),
    );
    return '$t · $d';
  }
}

/// Quỹ phép năm (`LeaveRequestService::balance`).
@immutable
class HrLeaveBalance {
  const HrLeaveBalance({
    this.year = 0,
    this.granted = 0,
    this.carried = 0,
    this.used = 0,
    this.remaining = 0,
  });

  factory HrLeaveBalance.fromJson(Map<String, dynamic> j) => HrLeaveBalance(
    year: _i(j['year']),
    granted: _d(j['granted']),
    carried: _d(j['carried']),
    used: _d(j['used']),
    remaining: _d(j['remaining']),
  );

  final int year;
  final double granted;
  final double carried;
  final double used;
  final double remaining;
}

/// `GET /hr/me/requests`.
@immutable
class HrMyRequests {
  const HrMyRequests({
    this.requests = const [],
    this.leave = const HrLeaveBalance(),
  });

  factory HrMyRequests.fromJson(Map<String, dynamic> j) => HrMyRequests(
    requests: [
      for (final r in _l(j['requests']))
        if (HrRequest.fromJson(r) case final req when req.status != 'huy') req,
    ],
    leave: HrLeaveBalance.fromJson(_m(j['leave'])),
  );

  final List<HrRequest> requests;
  final HrLeaveBalance leave;
}

/// Một người trong "Xưởng hôm nay".
@immutable
class HrWorkshopRow {
  const HrWorkshopRow({
    required this.membershipId,
    required this.name,
    this.phone,
    this.orgUnitName,
    this.status,
    this.inAt,
    this.outAt,
    this.lateMin = 0,
    this.otPendingYesterday = 0,
  });

  factory HrWorkshopRow.fromJson(Map<String, dynamic> j) => HrWorkshopRow(
    membershipId: _s(j['membership_id']) ?? '',
    name: _s(j['name']) ?? '—',
    phone: _s(j['phone']),
    orgUnitName: _s(j['org_unit_name']),
    status: _s(j['status']),
    inAt: _s(j['in_at']),
    outAt: _s(j['out_at']),
    lateMin: _i(j['late_min']),
    otPendingYesterday: _d(j['ot_pending_yesterday']),
  );

  final String membershipId;
  final String name;
  final String? phone;
  final String? orgUnitName;
  final String? status;
  final String? inAt;
  final String? outAt;
  final int lateMin;
  final double otPendingYesterday;

  /// Tên gọi (chữ cuối): `Vũ Văn Hoàng` → `Hoàng`.
  String get shortName => name.trim().split(RegExp(r'\s+')).last;
}

/// Một lượt bốc cont.
@immutable
class HrContLoad {
  const HrContLoad({
    required this.id,
    required this.type,
    this.date,
    this.time,
    this.membershipIds = const [],
    this.names = const [],
  });

  factory HrContLoad.fromJson(Map<String, dynamic> j) => HrContLoad(
    id: _s(j['id']) ?? '',
    type: _s(j['type']) ?? '',
    date: _s(j['date']),
    time: _s(j['time']),
    membershipIds: _strings(j['membership_ids']),
    names: _strings(j['names']),
  );

  final String id;
  final String type;
  final String? date;
  final String? time;
  final List<String> membershipIds;
  final List<String> names;
}

/// Loại cont và giá một lượt (cài đặt nhân sự).
@immutable
class HrContType {
  const HrContType({required this.code, this.price});

  final String code;

  /// null khi người dùng không đọc được cài đặt (không bịa giá).
  final int? price;
}

/// `GET /hr/today` (quản đốc).
@immutable
class HrWorkshopToday {
  const HrWorkshopToday({
    required this.date,
    this.total = 0,
    this.clockedIn = 0,
    this.onLeave = const [],
    this.notClockedIn = const [],
    this.otPending = const [],
    this.contLoads = const [],
    this.contTypes = const [],
    this.rows = const [],
    this.yesterday,
  });

  factory HrWorkshopToday.fromJson(Map<String, dynamic> j) {
    final rows = [for (final r in _l(j['rows'])) HrWorkshopRow.fromJson(r)];
    final names = {for (final r in rows) r.membershipId: r.shortName};
    return HrWorkshopToday(
      date: _s(j['date']) ?? '',
      yesterday: _s(j['yesterday']),
      total: _i(j['total']),
      clockedIn: _i(j['clocked_in']),
      onLeave: [for (final r in _l(j['on_leave'])) HrWorkshopRow.fromJson(r)],
      notClockedIn: [
        for (final r in _l(j['not_clocked_in'])) HrWorkshopRow.fromJson(r),
      ],
      otPending: [
        for (final r in _l(j['ot_pending'])) HrWorkshopRow.fromJson(r),
      ],
      contTypes: [
        for (final c in _l(j['cont_types']))
          if (_s(c['code']) case final code?)
            HrContType(
              code: code,
              price: c['price'] is num ? (c['price'] as num).toInt() : null,
            ),
      ],
      contLoads: [
        for (final c in _l(j['cont_loads']))
          if (HrContLoad.fromJson(c) case final load)
            load.names.isNotEmpty
                ? load
                : HrContLoad(
                    id: load.id,
                    type: load.type,
                    date: load.date,
                    time: load.time,
                    membershipIds: load.membershipIds,
                    names: [
                      for (final id in load.membershipIds) names[id] ?? '',
                    ],
                  ),
      ],
      rows: rows,
    );
  }

  final String date;
  final String? yesterday;
  final int total;
  final int clockedIn;
  final List<HrWorkshopRow> onLeave;
  final List<HrWorkshopRow> notClockedIn;
  final List<HrWorkshopRow> otPending;
  final List<HrContLoad> contLoads;

  /// Loại cont + giá (`cont_types`), quản đốc đọc được không cần quyền cài đặt.
  final List<HrContType> contTypes;
  final List<HrWorkshopRow> rows;
}

/// Một mốc thưởng đội: đạt [at] cây thì cả đội nhận [total].
@immutable
class KpiTier {
  const KpiTier({required this.at, required this.total, this.ramp = false});

  final int at;
  final int total;
  final bool ramp;
}

/// Bước kế: thêm [need] cây (tới [at]) thì cả đội thêm [gain].
@immutable
class KpiNext {
  const KpiNext({required this.at, required this.need, required this.gain});

  static KpiNext? of(Object? v) {
    final j = _m(v);
    if (j.isEmpty) return null;
    return KpiNext(at: _i(j['at']), need: _i(j['need']), gain: _i(j['gain']));
  }

  final int at;
  final int need;
  final int gain;
}

/// Phần thưởng của chính người xem.
@immutable
class KpiMine {
  const KpiMine({
    required this.amount,
    this.expected = 0,
    this.squad,
    this.weight = 0,
    this.workdays = 0,
  });

  final int amount;
  final double expected;
  final String? squad;
  final double weight;
  final double workdays;
}

/// `GET /kpi/me?period=` — null khi người dùng không thuộc đội nào.
@immutable
class KpiMe {
  const KpiMe({
    required this.teamId,
    required this.teamName,
    required this.period,
    this.closed = false,
    this.target = 0,
    this.n = 0,
    this.trees = 0,
    this.tiers = const [],
    this.gross = 0,
    this.deducted = 0,
    this.pool = 0,
    this.next,
    this.nextTier,
    this.standards = const [],
    this.mine,
  });

  static KpiMe? fromJson(Object? raw) {
    final j = _m(raw);
    final team = _m(j['team']);
    if (j.isEmpty || team.isEmpty) return null;
    final mine = _m(j['mine']);
    return KpiMe(
      teamId: _s(team['id']) ?? '',
      teamName: _s(team['name']) ?? 'Đội',
      period: _s(j['period']) ?? '',
      closed: _b(j['closed']),
      target: _i(j['target']),
      n: _d(j['n']),
      trees: _i(j['trees']),
      tiers: [
        for (final t in _l(j['tiers']))
          KpiTier(at: _i(t['at']), total: _i(t['total']), ramp: _b(t['ramp'])),
      ]..sort((a, b) => a.at.compareTo(b.at)),
      gross: _i(j['gross']),
      deducted: _i(j['deducted']),
      pool: _i(j['pool']),
      next: KpiNext.of(j['next']),
      nextTier: KpiNext.of(j['next_tier']),
      standards: _strings(j['standards']),
      mine: mine.isEmpty
          ? null
          : KpiMine(
              amount: _i(mine['amount']),
              expected: _d(mine['expected']),
              squad: _s(mine['squad']),
              weight: _d(mine['weight']),
              workdays: _d(mine['workdays']),
            ),
    );
  }

  final String teamId;
  final String teamName;
  final String period;
  final bool closed;
  final int target;

  /// Số cây đã tính (có thể lẻ khi có hệ số loại cây).
  final double n;
  final int trees;
  final List<KpiTier> tiers;
  final int gross;
  final int deducted;
  final int pool;
  final KpiNext? next;
  final KpiNext? nextTier;
  final List<String> standards;
  final KpiMine? mine;

  /// Mốc trên thước: mục tiêu, không có thì mốc lớn nhất.
  int get scale {
    final top = tiers.isEmpty ? 0 : tiers.last.at;
    return target > top ? target : top;
  }

  double get progress => scale <= 0 ? 0 : (n / scale).clamp(0, 1).toDouble();
}

/// Một kỳ trong danh sách phiếu lương.
@immutable
class PayslipSummary {
  const PayslipSummary({
    required this.period,
    required this.net,
    this.publishedAt,
    this.adjusting = false,
    this.ackStatus,
  });

  factory PayslipSummary.fromJson(Map<String, dynamic> j) => PayslipSummary(
    period: _s(j['period']) ?? '',
    net: _i(j['AE']),
    publishedAt: _s(j['published_at']),
    adjusting: _b(j['adjusting']),
    ackStatus: _s(_m(j['ack'])['status']),
  );

  final String period;
  final int net;
  final String? publishedAt;
  final bool adjusting;

  /// `da_xem` | `hoi_lai` | null (chưa xem).
  final String? ackStatus;

  bool get isNew => ackStatus == null;
}

/// Một dòng thu nhập / khấu trừ của phiếu lương.
@immutable
class PayLine {
  const PayLine({
    required this.code,
    required this.name,
    required this.amount,
    this.deduction = false,
    this.detail,
  });

  final String code;
  final String name;
  final int amount;
  final bool deduction;
  final String? detail;
}

/// `GET /hr/me/payslips/{YYYY-MM}`.
@immutable
class Payslip {
  const Payslip({
    required this.period,
    required this.net,
    this.income = 0,
    this.deduct = 0,
    this.lines = const [],
    this.issues = const [],
    this.publishedAt,
    this.adjusting = false,
    this.ackStatus,
    this.ackNote,
    this.bankName,
    this.accountMasked,
    this.bankBin,
    this.bankAccount,
    this.bankHolder,
    this.hasQrImage = false,
  });

  factory Payslip.fromJson(String period, Map<String, dynamic> j) {
    final result = _m(j['result']);
    final bank = _m(j['bank']);
    final ack = _m(j['ack']);
    return Payslip(
      period: period,
      net: _i(result['AE']),
      income: _i(result['AC']),
      deduct: _i(result['AD']),
      lines: [
        for (final l in _l(j['lines']))
          PayLine(
            code: _s(l['code']) ?? '',
            name: _s(l['name']) ?? '',
            amount: _i(l['amount']),
            deduction: _s(l['kind']) == 'tru',
            detail: _s(l['detail']),
          ),
      ],
      issues: _strings(j['issues']),
      publishedAt: _s(j['published_at']),
      adjusting: _b(j['adjusting']),
      ackStatus: _s(ack['status']),
      ackNote: _s(ack['note']),
      bankName: _s(bank['name']),
      accountMasked: _s(bank['account_masked']),
      bankBin: _s(bank['bin']),
      bankAccount: _s(bank['account']),
      bankHolder: _s(bank['holder']),
      hasQrImage: _b(bank['has_qr_image']),
    );
  }

  final String period;
  final int net;
  final int income;
  final int deduct;
  final List<PayLine> lines;
  final List<String> issues;
  final String? publishedAt;
  final bool adjusting;
  final String? ackStatus;
  final String? ackNote;
  final String? bankName;
  final String? accountMasked;
  final String? bankBin;

  /// Số tài khoản ĐỦ của chính người xem (để dựng QR); null với API cũ.
  final String? bankAccount;
  final String? bankHolder;
  final bool hasQrImage;

  List<PayLine> get incomeLines => [
    for (final l in lines)
      if (!l.deduction) l,
  ];
  List<PayLine> get deductionLines => [
    for (final l in lines)
      if (l.deduction) l,
  ];

  bool get isNew => ackStatus == null;
}

/// Toạ độ xưởng (`zone.site`).
@immutable
class HrSite {
  const HrSite({required this.lat, required this.lng, required this.radiusM});

  static HrSite? of(Object? raw) {
    final j = _m(raw);
    if (j['lat'] is! num || j['lng'] is! num) return null;
    return HrSite(
      lat: _d(j['lat']),
      lng: _d(j['lng']),
      radiusM: j['radius_m'] == null ? 150 : _d(j['radius_m']),
    );
  }

  final double lat;
  final double lng;
  final double radiusM;
}
