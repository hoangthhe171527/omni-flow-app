import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/modules/hr/application/hr_providers.dart';
import 'package:omni_app/modules/hr/domain/hr_models.dart';
import 'package:omni_app/modules/hr/presentation/payslip_page.dart';
import 'package:omni_app/modules/settings/application/appearance_providers.dart';
import 'package:omni_app/security/permissions/access_policy.dart';
import 'package:omni_app/security/session/session.dart';
import 'package:omni_app/security/session/session_controller.dart';

import '../../support/fixed_background.dart';

/// Phiếu lương với phông Be Vietnam Pro THẬT (phông thử Ahem lệch vài px):
/// mọi số tiền phải hiện đủ trên một dòng, không "…", không tràn — kể cả ở
/// máy hẹp 320 px.
Future<void> _loadFonts() async {
  final loader = FontLoader('Be Vietnam Pro');
  for (final f in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold']) {
    final bytes = File('assets/fonts/BeVietnamPro-$f.ttf').readAsBytesSync();
    loader.addFont(Future.value(ByteData.view(bytes.buffer)));
  }
  await loader.load();
}

final _slip = Payslip.fromJson('2026-10', {
  'published_at': '2026-11-05T02:00:00Z',
  'ack': null,
  'bank': {'name': 'Techcombank', 'account_masked': '•••• 3307'},
  'result': {'AC': 19941000, 'AD': 375000, 'AE': 19566000},
  'lines': [
    for (final (code, name, amount, detail) in const [
      ('L', 'Lương theo công', 13500000, '500.000 đ × 27 công'),
      ('E', 'Trách nhiệm', 1450000, ''),
      ('N', 'Tăng ca', 2250000, '18 giờ × 2'),
      ('O', 'Bốc cont', 800000, '1 lượt D'),
      ('S', 'Xăng xe', 400000, ''),
      ('U', 'Chuyên cần', 675000, '5% lương theo công'),
      ('V', 'Thưởng KPI đội', 666000, 'Đàn cơ · 42 cây'),
      ('P', 'Bảo hành', 200000, ''),
    ])
      {
        'code': code,
        'name': name,
        'kind': 'cong',
        'amount': amount,
        'detail': detail,
      },
    {
      'code': 'AA',
      'name': 'Trừ đi muộn',
      'kind': 'tru',
      'amount': 375000,
      'detail': '0,75 ngày công · 2 lần, 40 phút',
    },
  ],
});

Future<void> _pump(WidgetTester t, double width) async {
  t.view.physicalSize = Size(width, 2400);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    ProviderScope(
      overrides: [
        sessionProvider.overrideWithValue(
          const Session(
            status: SessionStatus.authenticated,
            policy: AccessPolicy({'hr.payslips.self'}),
          ),
        ),
        backgroundProvider.overrideWith(FixedBackground.new),
        hrPayslipsProvider.overrideWith(
          (_) async => [
            const PayslipSummary(period: '2026-10', net: 19566000),
            const PayslipSummary(period: '2026-09', net: 18912000),
          ],
        ),
        hrPayslipProvider.overrideWith((_, _) async => _slip),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: OmniTheme.light(),
        home: const PayslipPage(),
      ),
    ),
  );
  for (var i = 0; i < 10; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

/// Đoạn chữ hiện trọn trên một dòng: rộng bằng độ rộng tự nhiên, không cắt.
void _expectWhole(WidgetTester t, Finder f) {
  expect(f, findsWidgets, reason: '$f');
  for (final e in f.evaluate()) {
    final p = e.renderObject! as RenderParagraph;
    expect(
      p.didExceedMaxLines,
      isFalse,
      reason: '${p.text.toPlainText()} bị cắt',
    );
    final natural = p.getMaxIntrinsicWidth(double.infinity);
    expect(
      p.size.width + .5,
      greaterThanOrEqualTo(natural),
      reason: '${p.text.toPlainText()} bị xuống dòng / co lại',
    );
  }
}

void main() {
  setUpAll(_loadFonts);

  for (final width in [390.0, 320.0]) {
    testWidgets('mọi số tiền đủ số, một dòng — rộng $width', (t) async {
      await _pump(t, width);
      expect(t.takeException(), isNull);

      _expectWhole(t, find.textContaining('19.566.000', findRichText: true));
      for (final money in [
        '19.941.000 đ',
        '13.500.000 đ',
        '2.250.000 đ',
        '666.000 đ',
        '−375.000 đ',
      ]) {
        _expectWhole(t, find.text(money));
      }
      expect(find.textContaining('…'), findsNothing);
      expect(
        find.ancestor(
          of: find.text('19.941.000 đ'),
          matching: find.byType(FittedBox),
        ),
        findsNothing,
      );
      expect(find.text('Hỏi lại kế toán'), findsOneWidget);
      expect(find.text('Đã xem, đúng'), findsOneWidget);
    });
  }
}
