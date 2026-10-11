import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/modules/plans/application/plans_providers.dart';
import 'package:omni_app/modules/plans/data/plans_api.dart';
import 'package:omni_app/modules/plans/domain/plan.dart';
import 'package:omni_app/modules/plans/domain/workshop_kpi.dart';
import 'package:omni_app/modules/plans/presentation/plan_report_page.dart';
import 'package:omni_app/modules/plans/presentation/widgets/kpi_card.dart';

/// Báo cáo một kế hoạch (Task 7): khối số từ `plan.stats` và `KpiCard` gọi
/// `/tasks/kpi?project_id=` theo tháng.
void main() {
  const planId = 'p1';

  late _ReportApi api;

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    api = _ReportApi();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          plansApiProvider.overrideWithValue(api),
          planProvider(planId).overrideWith(
            (ref) async => Plan.fromJson({
              'id': planId,
              'name': 'Bảo hành',
              'stats': {'total': 10, 'done': 4, 'overdue': 2, 'progress': 40},
            }),
          ),
        ],
        child: MaterialApp(
          theme: OmniTheme.light(TargetPlatform.android),
          home: const PlanReportPage(planId: planId),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('(c) gọi kpi với project_id của kế hoạch, tháng này', (
    tester,
  ) async {
    await pump(tester);

    final now = DateTime.now();
    expect(find.text('Báo cáo kế hoạch'), findsOneWidget);
    expect(find.byType(KpiCard), findsOneWidget);
    expect(api.calls, contains((planId, DateTime(now.year, now.month))));
    for (final (planIdSent, _) in api.calls) {
      expect(planIdSent, planId);
    }
  });

  testWidgets('khối số từ plan.stats: tổng, xong, trễ, tiến độ', (
    tester,
  ) async {
    await pump(tester);

    expect(
      find.descendant(
        of: find.byKey(const Key('plan-report-total')),
        matching: find.text('10'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('plan-report-done')),
        matching: find.text('4'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('plan-report-overdue')),
        matching: find.text('2'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('plan-report-progress')),
        matching: find.text('40%'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('lùi tháng gọi kpi tháng trước, vẫn theo kế hoạch', (
    tester,
  ) async {
    await pump(tester);
    final now = DateTime.now();

    await tester.tap(find.byTooltip('Tháng trước'));
    await tester.pumpAndSettle();

    expect(api.calls.last.$1, planId);
    expect(
      api.calls.map((c) => c.$2),
      contains(DateTime(now.year, now.month - 1)),
    );
    expect(
      find.text(
        'Tháng ${DateTime(now.year, now.month - 1).month}/'
        '${DateTime(now.year, now.month - 1).year}',
      ),
      findsOneWidget,
    );
  });
}

class _ReportApi implements PlansApi {
  final calls = <(String?, DateTime?)>[];

  @override
  Future<WorkshopKpi> kpi({String? planId, DateTime? month}) async {
    calls.add((planId, month));
    return WorkshopKpi.fromJson({
      'delivered': 3,
      'reached_bonus': 0,
      'days_left': 10,
      'counting_sections': ['s9'],
      'tiers': {'10': 1000000},
      'next_tier': {'count': 10, 'bonus': 1000000},
    });
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
