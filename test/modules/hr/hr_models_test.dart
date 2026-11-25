import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/app/apps/app_shell_layout.dart';
import 'package:omni_app/modules/hr/domain/hr_format.dart';
import 'package:omni_app/modules/hr/domain/hr_models.dart';
import 'package:omni_app/modules/hr/domain/hr_permissions.dart';
import 'package:omni_app/modules/hr/hr_module.dart';
import 'package:omni_app/security/permissions/access_policy.dart';
import 'package:omni_app/security/session/session.dart';

void main() {
  group('kpi/me', () {
    test('đọc đúng hình dạng TeamKpiService::me', () {
      final k = KpiMe.fromJson({
        'team': {'id': 'ou-1', 'name': 'Đàn cơ'},
        'period': '2026-11',
        'closed': false,
        'target': 50,
        'n': 42,
        'trees': 42,
        'tiers': [
          {'at': 45, 'total': 7950000, 'ramp': false},
          {'at': 35, 'total': 4500000, 'ramp': true},
        ],
        'gross': 6300000,
        'deducted': 300000,
        'pool': 6000000,
        'next': {'at': 45, 'need': 3, 'gain': 1650000},
        'next_tier': null,
        'standards': ['Không xước mặt đàn'],
        'mine': {
          'amount': 666000,
          'expected': 665.5,
          'squad': 'Chỉnh máy',
          'weight': 1,
          'workdays': 19,
        },
      })!;
      expect(k.teamName, 'Đàn cơ');
      expect(k.n, 42);
      expect(k.tiers.map((t) => t.at), [35, 45], reason: 'sắp theo mốc');
      expect(k.tiers.first.ramp, isTrue);
      expect(k.next!.gain, 1650000);
      expect(k.nextTier, isNull);
      expect(k.mine!.amount, 666000);
      expect(k.scale, 50);
      expect(k.progress, closeTo(.84, .001));
    });

    test('data null (không thuộc đội) → null; mine null khi admin tắt', () {
      expect(KpiMe.fromJson(null), isNull);
      expect(KpiMe.fromJson(const <String, dynamic>{}), isNull);
      final k = KpiMe.fromJson({
        'team': {'id': 'x', 'name': 'Đàn điện'},
        'mine': null,
        'tiers': 'hỏng',
      })!;
      expect(k.mine, isNull);
      expect(k.tiers, isEmpty);
    });
  });

  group('phiếu lương', () {
    test('đọc result/lines/bank/ack của PayrollService::mySlip', () {
      final p = Payslip.fromJson('2026-10', {
        'published_at': '2026-11-05T02:00:00Z',
        'adjusting': false,
        'ack': null,
        'bank': {
          'name': 'Techcombank',
          'bin': '970407',
          'account_masked': '•••• 3307',
          'has_qr_image': false,
        },
        'result': {'AC': 19941000, 'AD': 375000, 'AE': 19566000},
        'lines': [
          {
            'code': 'L',
            'name': 'Lương theo công',
            'kind': 'cong',
            'amount': 13500000,
            'detail': '500.000 đ × 27 công',
          },
          {
            'code': 'AA',
            'name': 'Trừ đi muộn',
            'kind': 'tru',
            'amount': 375000,
            'detail': '0,75 ngày công',
          },
        ],
        'issues': ['Muộn 3 lần, mất chuyên cần'],
      });
      expect(p.net, 19566000);
      expect(p.income, 19941000);
      expect(p.incomeLines.single.name, 'Lương theo công');
      expect(p.deductionLines.single.amount, 375000);
      expect(p.accountMasked, '•••• 3307');
      expect(p.isNew, isTrue);
      expect(p.issues, hasLength(1));
      expect(HrFormat.money(p.net), '19.566.000 đ');
      expect(HrFormat.money(-375000), '−375.000 đ');
    });

    test('danh sách: AE và ack', () {
      final s = PayslipSummary.fromJson({
        'period': '2026-09',
        'AE': 18912000,
        'ack': {'status': 'da_xem'},
      });
      expect(s.net, 18912000);
      expect(s.isNew, isFalse);
    });
  });

  group('hôm nay / đơn', () {
    test('/hr/me/today: next, ca, vùng, tổng tháng', () {
      final t = HrToday.fromJson({
        'date': '2026-11-24',
        'shift': {
          'name': 'Ca hành chính',
          'start': '08:00',
          'end': '17:30',
          'ot_from': '18:00',
          'weekdays': [1, 2, 3, 4, 5, 6],
        },
        'day': {
          'date': '2026-11-24',
          'status': 'w',
          'in_at': '2026-11-24T00:52:00Z',
          'out_at': null,
        },
        'next': 'out',
        'device': null,
        'zone': {
          'wifi': [
            {'name': 'Xưởng 50 Dân Chủ', 'ssid': 'Xuong-50DanChu'},
          ],
          'has_site': true,
          'radius_m': 150,
          'lock_device': true,
        },
        'month': {
          'G': 18,
          'H': 1,
          'J': 19,
          'Y': 1,
          'X': 20,
          'T': 20,
          'scheduled_month': 26,
        },
      });
      expect(t.next, 'out');
      expect(t.shift!.label, 'Ca hành chính · 08:00 – 17:30');
      expect(HrFormat.hm(t.day!.inAt), '07:52', reason: 'giờ VN');
      expect(t.zone.wifiFor('xuong-50danchu')?.name, 'Xưởng 50 Dân Chủ');
      expect(t.month.j, 19);
      expect(t.month.scheduledMonth, 26);
      expect(t.month.lateLabel, '1 lần · 20 phút');
    });

    test('dòng chi tiết đơn như bản duyệt', () {
      final r = HrRequest.fromJson({
        'id': 'r1',
        'type': 'phep',
        'status': 'cho',
        'from': '2026-11-28',
        'to': '2026-11-28',
        'session': 'ca_ngay',
      });
      expect(r.detail, 'Thứ Bảy, 28/11 · cả ngày');
      final t = HrRequest.fromJson({
        'id': 'r2',
        'type': 'tamung',
        'status': 'duyet',
        'amount': 2000000,
      });
      expect(t.detail, '2.000.000 đ');
    });
  });

  group('cờ + khả năng + quyền', () {
    Session session({
      Set<String> perms = const {'hr.attendance.self', 'hr.payslips.self'},
      Map<String, bool> features = const {
        'hr_attendance': true,
        'hr_payroll': true,
      },
      Set<String> caps = const {'hr.attendance', 'hr.payroll'},
    }) => Session(
      status: SessionStatus.authenticated,
      policy: AccessPolicy(perms),
      features: features,
      apiCapabilities: caps,
    );

    test('đủ ba điều mới hiện', () {
      final a = HrAccess.of(session());
      expect(a.clock, isTrue);
      expect(a.payslips, isTrue);
      expect(a.workshop, isFalse);
      expect(a.kpi, isFalse);
    });

    test('cờ tắt / API cũ / thiếu quyền → ẩn', () {
      expect(
        HrAccess.of(session(features: const {'hr_attendance': false})).clock,
        isFalse,
      );
      expect(HrAccess.of(session(caps: const {})).clock, isFalse);
      expect(HrAccess.of(session(perms: const {})).clock, isFalse);
    });
  });

  group('khung ứng dụng', () {
    test('mọi khoá hr_* trỏ tới route Nhân sự có thật, nhãn tab ≤ 9', () {
      final routes = {for (final r in const HrModule().routes()) r.name};
      const keys = [
        'hr_clock',
        'hr_timesheet',
        'hr_requests',
        'hr_kpi',
        'hr_payslip',
        'hr_workshop_today',
        'hr_approvals',
      ];
      for (final k in keys) {
        final spec = appItemSpecs[k];
        expect(spec, isNotNull, reason: k);
        expect(routes, contains(spec!.routeName), reason: k);
        final label = tabLabels[spec.routeName];
        expect(label, isNotNull, reason: k);
        expect(label!.length, lessThanOrEqualTo(maxTabLabelLength), reason: k);
      }
      expect(tabLabels['hr.clock'], 'Chấm công');
      expect(tabLabels['hr.timesheet'], 'Công');
      expect(tabLabels['hr.requests'], 'Đơn từ');
      expect(tabLabels['hr.payslip'], 'Lương');
    });

    test('mục điều hướng mang cờ + khả năng API', () {
      for (final e in const HrModule().navEntries()) {
        expect(e.feature, isNotNull, reason: e.routeName);
        expect(e.capabilities, isNotEmpty, reason: e.routeName);
      }
    });
  });
}
