import '../../core/utils/formatters.dart';
import '../../modules/hr/data/punch_sensors.dart';
import '../../modules/hr/domain/clock_state.dart';
import '../demo_backend.dart';

/// Máy chủ demo của **Nhân sự** (`/hr/*`, `/kpi/me`): dữ liệu khớp bản đã
/// duyệt `nhan-su-app.html` — Vũ Văn Hoàng, đội Đàn cơ, xưởng 50 Dân Chủ.
/// Có trạng thái trong RAM: chấm vào/ra, gửi đơn, duyệt đơn, ghi bốc cont
/// đều đổi dữ liệu thật của phiên demo.

const _wifiSsid = 'Xuong-50DanChu';

/// Cảm biến giả cho web demo: đang bắt WiFi xưởng, có mã máy cố định.
class DemoPunchSensors implements PunchSensors {
  const DemoPunchSensors();

  @override
  Future<String> deviceKey() async => deviceKeyOf('demo-install', 'demo');

  @override
  Future<({String? platform, String? model})> deviceLabel() async =>
      (platform: 'web', model: 'Demo');

  @override
  Future<SensorReading> read({
    required bool ask,
    required bool wantGps,
  }) async => const SensorReading(ssid: _wifiSsid, bssid: 'aa:bb:cc:dd:ee:01');
}

String _ymd(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Giờ VN `HH:mm` của ngày [d] → ISO UTC.
String _iso(DateTime d, String hm) {
  final p = hm.split(':');
  return DateTime.utc(
    d.year,
    d.month,
    d.day,
    int.parse(p[0]) - 7,
    int.parse(p[1]),
  ).toIso8601String();
}

const _shift = {
  'id': 'shift-hc',
  'name': 'Ca hành chính',
  'start': '08:00',
  'end': '17:30',
  'ot_from': '18:00',
  'weekdays': [1, 2, 3, 4, 5, 6],
  'is_default': true,
};

const _people = [
  ('m-hoang', 'Vũ Văn Hoàng', 'Đàn cơ', '0901000010'),
  ('m-thanh', 'Trịnh Đức Thành', 'Đàn điện', '0901000001'),
  ('m-khoa', 'Nguyễn Khắc Khoa', 'Đàn điện', '0901000002'),
  ('m-tam', 'Trần Văn Tâm', 'Đàn điện', '0901000003'),
  ('m-binh', 'Trần Thanh Bình', 'Đàn điện', '0901000004'),
  ('m-linh', 'Thành Thị Thảo Linh', 'Đàn cơ', '0901000005'),
  ('m-rubi', 'Nguyễn Thị Ru Bi', 'Đàn cơ', '0901000006'),
  ('m-ni', 'Mai Hằng Ni', 'Đàn cơ', '0901000007'),
  ('m-phuong', 'Nguyễn Thị Hồng Phượng', 'Đàn cơ', '0901000008'),
  ('m-khanh', 'Nguyễn Bảo Khánh', 'Đàn cơ', '0901000009'),
  ('m-vinh', 'Nguyễn Quốc Vinh', 'Đàn cơ', '0901000011'),
  ('m-rin', 'Nguyễn Đình Rin', 'Đàn cơ', '0901000012'),
  ('m-son', 'Lê Văn Sơn', 'Đàn điện', '0901000013'),
  ('m-duc', 'Phạm Minh Đức', 'Đàn điện', '0901000014'),
  ('m-an', 'Hoàng Văn An', 'Đàn cơ', '0901000015'),
  ('m-lam', 'Đỗ Văn Lâm', 'Đàn cơ', '0901000016'),
];

class _HrDemoStore {
  _HrDemoStore() {
    _seedRequests();
  }

  DateTime get today => VnTime.today();
  String get month => _ymd(today).substring(0, 7);

  String? inAt;
  String? outAt;
  final notIn = {'m-tam', 'm-binh', 'm-hoang', 'm-vinh'};
  final onLeave = {'m-ni'};
  final otPending = {'m-tam'};
  final contLoads = <Map<String, dynamic>>[];
  final myRequests = <Map<String, dynamic>>[];
  final approvals = <Map<String, dynamic>>[];
  final acks = <String, Map<String, dynamic>>{};
  int _seq = 1;

  String _id() => 'hr-${_seq++}';

  void _seedRequests() {
    final t = VnTime.today();
    DateTime d(int day) => DateTime.utc(t.year, t.month, day);
    final created = DateTime.now().toUtc();
    myRequests.addAll([
      {
        'id': 'r1',
        'type': 'phep',
        'status': 'cho',
        'from': _ymd(d(28)),
        'to': _ymd(d(28)),
        'date': _ymd(d(28)),
        'session': 'ca_ngay',
        'leave_kind': 'phep_nam',
        'reason': 'Về quê có việc gia đình',
        'created_at': created.toIso8601String(),
      },
      {
        'id': 'r2',
        'type': 'tangca',
        'status': 'duyet',
        'date': _ymd(d(19)),
        'hours': 4,
        'reason': 'Kịp giao đàn',
        'created_at': created.toIso8601String(),
      },
      {
        'id': 'r3',
        'type': 'giaitrinh',
        'status': 'tuchoi',
        'date': _ymd(d(11)),
        'in_at': _iso(d(11), '08:20'),
        'reason': 'Kẹt xe',
        'decision_note': 'Có camera vào 08:20',
        'created_at': created.toIso8601String(),
      },
    ]);
    contLoads.add({
      'id': 'c1',
      'date': _ymd(t),
      'time': '10:20',
      'type': 'D',
      'membership_ids': ['m-hoang', 'm-vinh', 'm-rin'],
    });
    approvals.addAll([
      {
        'id': 'a1',
        'membership_id': 'm-hoang',
        'name': 'Vũ Văn Hoàng',
        'type': 'phep',
        'status': 'cho',
        'from': _ymd(d(28)),
        'to': _ymd(d(28)),
        'date': _ymd(d(28)),
        'session': 'ca_ngay',
        'reason': 'Về quê có việc gia đình',
        'created_at': _iso(t, '07:40'),
      },
      {
        'id': 'a2',
        'membership_id': 'm-tam',
        'name': 'Trần Văn Tâm',
        'type': 'tamung',
        'status': 'cho',
        'amount': 2000000,
        'payroll_period': month,
        'reason': 'Tạm ứng tiền học cho con',
        'created_at': _iso(t.subtract(const Duration(days: 2)), '16:40'),
      },
      {
        'id': 'a3',
        'membership_id': 'm-khoa',
        'name': 'Nguyễn Khắc Khoa',
        'type': 'tangca',
        'status': 'cho',
        'date': _ymd(t),
        'hours': 3,
        'reason': 'Kịp giao 2 cây cho đơn DH-1151',
        'created_at': _iso(t, '08:02'),
      },
      {
        'id': 'a4',
        'membership_id': 'm-vinh',
        'name': 'Nguyễn Quốc Vinh',
        'type': 'giaitrinh',
        'status': 'duyet',
        'date': _ymd(d(17)),
        'in_at': _iso(d(17), '07:55'),
        'reason': 'Điện thoại hết pin, vào lúc 07:55',
        'created_at': _iso(d(18), '08:10'),
      },
    ]);
  }

  /// Ngày công của Hoàng trong tháng [ym].
  List<Map<String, dynamic>> days(String ym) {
    final p = ym.split('-');
    final y = int.parse(p[0]);
    final m = int.parse(p[1]);
    final count = DateTime.utc(y, m + 1, 0).day;
    final t = today;
    final out = <Map<String, dynamic>>[];
    for (var i = 1; i <= count; i++) {
      final d = DateTime.utc(y, m, i);
      final scheduled = d.weekday != DateTime.sunday;
      final key = _ymd(d);
      final isToday = key == _ymd(t);
      final past = d.isBefore(t);
      final base = <String, dynamic>{
        'date': key,
        'scheduled': scheduled,
        'status': 'off',
        'work': 0,
        'paid_leave': 0,
        'unpaid': 0,
        'holiday': 0,
        'missing': 0,
        'in_at': null,
        'out_at': null,
        'method': null,
        'late_min': 0,
        'ot_hours': 0,
        'ot_pending_hours': 0,
        'cont': <String, int>{},
        'explain_due': null,
        'holiday_name': null,
        'manual': false,
        'leave': null,
      };
      if (!scheduled) {
        out.add(base);
        continue;
      }
      if (isToday) {
        base['status'] = inAt == null ? 'fut' : 'w';
        base['in_at'] = inAt;
        base['out_at'] = outAt;
        base['method'] = inAt == null ? null : 'wifi';
        base['work'] = inAt == null ? 0 : 1;
        out.add(base);
        continue;
      }
      if (!past) {
        base['status'] = 'fut';
        out.add(base);
        continue;
      }
      final late = i == 11;
      final ot = i == 5 || i == 12 || i == 19;
      base
        ..['status'] = 'w'
        ..['work'] = 1
        ..['method'] = 'wifi'
        ..['in_at'] = _iso(d, late ? '08:20' : '07:5${i % 8}')
        ..['out_at'] = _iso(d, ot ? '21:30' : '17:3${i % 6}')
        ..['late_min'] = late ? 20 : 0
        ..['ot_hours'] = ot ? 4 : 0;
      if (i == 20) {
        base
          ..['status'] = 'x'
          ..['work'] = 0
          ..['missing'] = 1
          ..['out_at'] = null
          ..['late_min'] = 0
          ..['explain_due'] = _ymd(d.add(const Duration(days: 5)));
      }
      if (i == 16 && d.weekday != DateTime.sunday) {
        base
          ..['status'] = 'p'
          ..['work'] = 0
          ..['paid_leave'] = 1
          ..['in_at'] = null
          ..['out_at'] = null
          ..['method'] = null
          ..['leave'] = {'session': 'ca_ngay', 'kind': 'phep_nam'};
      }
      out.add(base);
    }
    return out;
  }

  Map<String, dynamic> totals(List<Map<String, dynamic>> list) {
    double sum(String k) =>
        list.fold<double>(0, (s, d) => s + ((d[k] as num?) ?? 0).toDouble());
    final g = sum('work');
    final h = sum('paid_leave') + sum('holiday');
    return {
      'G': g,
      'H': h,
      'J': g + h,
      'I': sum('unpaid') + sum('missing'),
      'Y': list.where((d) => (d['late_min'] as int) > 0).length,
      'X': list.fold<int>(0, (s, d) => s + (d['late_min'] as int)),
      'M': sum('ot_hours'),
      'T': list.where((d) => d['scheduled'] == true).length,
      'missing': sum('missing'),
      'ot_pending': 0,
      'cont': {'D': 1},
    };
  }

  Map<String, dynamic> todayJson() {
    final all = days(month);
    final key = _ymd(today);
    final past = [
      for (final d in all)
        if ((d['date'] as String).compareTo(key) <= 0) d,
    ];
    final day = all.firstWhere(
      (d) => d['date'] == key,
      orElse: () => all.first,
    );
    return {
      'date': key,
      'shift': _shift,
      'day': day,
      'next': inAt == null ? 'in' : (outAt == null ? 'out' : 'done'),
      'device': {'platform': 'web', 'model': 'Demo'},
      'zone': {
        'wifi': [
          {'name': 'Xưởng 50 Dân Chủ', 'ssid': _wifiSsid},
        ],
        'has_site': true,
        'radius_m': 150,
        'lock_device': true,
        'site': {'lat': 21.0285, 'lng': 105.8542, 'radius_m': 150},
      },
      'month': {
        ...totals(past),
        'scheduled_month': all.where((d) => d['scheduled'] == true).length,
      },
    };
  }

  Map<String, dynamic> workshop() {
    final t = today;
    final key = _ymd(t);
    final rows = [
      for (final (id, name, team, phone) in _people)
        {
          'membership_id': id,
          'name': name,
          'phone': phone,
          'org_unit_name': team,
          'status': onLeave.contains(id)
              ? 'p'
              : (notIn.contains(id) && !(id == 'm-hoang' && inAt != null))
              ? 'fut'
              : 'w',
          'scheduled': true,
          'in_at':
              onLeave.contains(id) ||
                  (notIn.contains(id) && !(id == 'm-hoang' && inAt != null))
              ? null
              : (id == 'm-hoang' ? inAt : _iso(t, '07:4${id.length % 9}')),
          'out_at': null,
          'late_min': 0,
          'ot_hours': 0,
          'ot_pending_yesterday': otPending.contains(id) ? 2 : 0,
        },
    ];
    final scheduled = [
      for (final r in rows)
        if (r['status'] != 'p') r,
    ];
    return {
      'date': key,
      'yesterday': _ymd(t.subtract(const Duration(days: 1))),
      'total': rows.length,
      'clocked_in': scheduled.where((r) => r['in_at'] != null).length,
      'on_leave': [
        for (final r in rows)
          if (r['status'] == 'p') r,
      ],
      'not_clocked_in': [
        for (final r in scheduled)
          if (r['in_at'] == null) r,
      ],
      'ot_pending': [
        for (final r in rows)
          if ((r['ot_pending_yesterday'] as int) > 0) r,
      ],
      'cont_loads': contLoads,
      'cont_types': _contTypes,
      'rows': rows,
    };
  }

  static const _slips = {0: 19566000, 1: 18912000, 2: 19204000};

  String _period(int back) {
    final t = today;
    final d = DateTime.utc(t.year, t.month - 1 - back);
    return _ymd(d).substring(0, 7);
  }

  List<Map<String, dynamic>> payslips() => [
    for (final e in _slips.entries)
      {
        'period': _period(e.key),
        'AE': e.value,
        'published_at': _iso(DateTime.utc(2026, 11, 5), '09:00'),
        'adjusting': false,
        'ack':
            acks[_period(e.key)] ??
            (e.key == 0 ? null : {'status': 'da_xem', 'note': null}),
      },
  ];

  Map<String, dynamic>? payslip(String period) {
    final summary = payslips().where((p) => p['period'] == period);
    if (summary.isEmpty) return null;
    final net = summary.first['AE'] as int;
    final lines = [
      ('L', 'Lương theo công', 'cong', 13500000, '500.000 đ × 27 công'),
      ('E', 'Trách nhiệm', 'cong', 1450000, ''),
      ('N', 'Tăng ca', 'cong', 2250000, '18 giờ × 2'),
      ('O', 'Bốc cont', 'cong', 800000, '1 lượt D'),
      ('S', 'Xăng xe', 'cong', 400000, ''),
      ('U', 'Chuyên cần', 'cong', 675000, '5% lương theo công'),
      ('V', 'Thưởng KPI đội', 'cong', 666000, 'Đàn cơ · 42 cây'),
      ('P', 'Bảo hành', 'cong', 200000 + (net - 19566000), ''),
      ('AA', 'Trừ đi muộn', 'tru', 375000, '0,75 ngày công · 2 lần, 40 phút'),
    ];
    final income = lines
        .where((l) => l.$3 == 'cong')
        .fold<int>(0, (s, l) => s + l.$4);
    return {
      'published_at': summary.first['published_at'],
      'adjusting': false,
      'ack': summary.first['ack'],
      'bank': {
        'name': 'Techcombank',
        'bin': '970407',
        'account_masked': '•••• 3307',
        'account': '190223353307',
        'holder': 'VU VAN HOANG',
        'has_qr_image': false,
      },
      'name': 'Vũ Văn Hoàng',
      'code': 'NV010',
      'result': {'AC': income, 'AD': 375000, 'AE': income - 375000},
      'lines': [
        for (final l in lines)
          {
            'code': l.$1,
            'name': l.$2,
            'kind': l.$3,
            'amount': l.$4,
            'detail': l.$5,
          },
      ],
      'issues': <String>[],
    };
  }

  Map<String, dynamic> kpi(String period) {
    final closed = period.compareTo(month) < 0;
    final tiers = [
      {'at': 35, 'total': 4500000, 'ramp': false},
      {'at': 40, 'total': 6300000, 'ramp': false},
      {'at': 45, 'total': 7950000, 'ramp': false},
      {'at': 50, 'total': 9600000, 'ramp': false},
    ];
    return {
      'team': {'id': 'team-dan-co', 'name': 'Đàn cơ'},
      'period': period,
      'closed': closed,
      'target': 50,
      'n': closed ? 47 : 42,
      'trees': closed ? 47 : 42,
      'tiers': tiers,
      'gross': closed ? 7950000 : 6300000,
      'deducted': 300000,
      'pool': closed ? 7650000 : 6000000,
      'next': closed ? null : {'at': 45, 'need': 3, 'gain': 1650000},
      'next_tier': closed ? null : {'at': 45, 'need': 3, 'gain': 1650000},
      'standards': ['Không xước mặt đàn', 'Lên dây đủ 3 lần'],
      'mine': {
        'amount': closed ? 850000 : 666000,
        'expected': closed ? 850000 : 666000,
        'squad': 'Chỉnh máy',
        'weight': 1,
        'workdays': closed ? 26 : 19,
      },
    };
  }
}

/// Đăng ký trước `crm` trong `buildDemoRoutes` (spec 03 §5.3).
void registerHrDemo(DemoRoutes r) {
  final s = _HrDemoStore();

  r.get('/hr/me/today', (_) => ok(s.todayJson()));
  r.post('/hr/me/punches', (req) {
    final kind = req.json['kind'];
    final now = DateTime.now().toUtc().toIso8601String();
    if (kind == 'in') {
      s.inAt ??= now;
    } else {
      s.outAt ??= now;
    }
    return created({
      'accepted': true,
      'reject_code': null,
      'method': 'wifi',
      'at': now,
      'distance_m': null,
      'punch_id': s._id(),
    });
  });
  r.get('/hr/me/days', (req) {
    final m = req.q('month') ?? s.month;
    final days = s.days(m);
    return ok({
      'month': m,
      'days': days,
      'totals': s.totals(days),
      'locked': m.compareTo(s.month) < 0,
    });
  });
  r.get(
    '/hr/me/requests',
    (_) => ok({
      'requests': s.myRequests,
      'leave': {
        'year': s.today.year,
        'granted': 12,
        'carried': 0,
        'used': 1,
        'remaining': 11,
      },
    }),
  );
  r.post('/hr/me/requests', (req) {
    final body = {
      ...req.json,
      'id': s._id(),
      'status': 'cho',
      'created_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (body['type'] == 'giaitrinh' && body['in_time'] != null) {
      final d = DateTime.parse('${body['date']}T00:00:00Z');
      body['in_at'] = _iso(d, '${body['in_time']}');
    }
    s.myRequests.insert(0, body);
    return created(body);
  });
  r.post('/hr/me/requests/{id}/cancel', (req) {
    s.myRequests.removeWhere((x) => x['id'] == req.params['id']);
    return ok({'id': req.params['id'], 'status': 'huy'});
  });

  r.get('/hr/requests', (_) => ok(s.approvals));
  r.post('/hr/requests/{id}/{decision}', (req) {
    final hit = s.approvals.where((x) => x['id'] == req.params['id']);
    if (hit.isEmpty) return notFound();
    hit.first['status'] = req.params['decision'] == 'approve'
        ? 'duyet'
        : 'tuchoi';
    hit.first['decision_note'] = req.json['note'];
    return ok(hit.first);
  });

  r.get('/hr/today', (_) => ok(s.workshop()));
  r.post(
    '/hr/today/remind',
    (_) => ok({'sent': s.notIn.length, 'retry_after': 0}),
  );
  r.post('/hr/days/{membershipId}/{date}/ot-pending', (req) {
    s.otPending.remove(req.params['membershipId']);
    return ok({'date': req.params['date']});
  });
  r.get('/hr/cont-loads', (_) => ok(s.contLoads));
  r.post('/hr/cont-loads', (req) {
    final load = {...req.json, 'id': s._id()};
    s.contLoads.add(load);
    return created(load);
  });
  r.get(
    '/hr/settings',
    (_) => ok({
      'settings': {
        'cont_types': [
          {'code': 'A', 'price': 350000},
          {'code': 'B', 'price': 400000},
          {'code': 'C', 'price': 500000},
          {'code': 'D', 'price': 800000},
        ],
      },
      'shifts': [_shift],
      'holidays': <Object>[],
    }),
  );
  r.post('/hr/settings/wifi/capture', (req) => ok(req.json));

  r.get('/hr/me/payslips', (_) => ok(s.payslips()));
  r.get('/hr/me/payslips/{period}', (req) {
    final p = s.payslip(req.params['period']!);
    return p == null ? notFound('Chưa có phiếu lương kỳ này.') : ok(p);
  });
  r.post('/hr/me/payslips/{period}/ack', (req) {
    final period = req.params['period']!;
    s.acks[period] = {
      'status': req.json['status'],
      'note': req.json['note'],
      'at': DateTime.now().toUtc().toIso8601String(),
    };
    return ok(s.payslip(period));
  });

  r.get('/kpi/me', (req) => ok(s.kpi(req.q('period') ?? s.month)));
}

const _contTypes = [
  {'code': 'A', 'price': 350000},
  {'code': 'B', 'price': 400000},
  {'code': 'C', 'price': 500000},
  {'code': 'D', 'price': 800000},
];
