import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/modules/opportunities/application/opportunities_providers.dart';
import 'package:omni_app/modules/opportunities/domain/opportunity.dart';
import 'package:omni_app/modules/opportunities/domain/pipeline_catalog.dart';
import 'package:omni_app/modules/opportunities/presentation/opportunity_detail_page.dart';
import 'package:omni_app/security/permissions/access_scope.dart';
import 'package:omni_app/security/permissions/resource_access.dart';

/// Thanh hành động của chi tiết cơ hội theo trạng thái (Đợt 5, OPP-X2).
///
/// API từ chối (422) "Đánh dấu thắng" và đổi giai đoạn trên cơ hội đã HUỶ, nên
/// app không bày hai nút đó ra để người dùng bấm vào một lỗi. Cơ hội đã Thắng
/// hoặc Thua thì giống web: không còn "Đánh dấu thắng", nhưng vẫn đổi giai
/// đoạn được — đó là đường mở lại cơ hội.
void main() {
  setUpAll(() => initializeDateFormatting('vi_VN'));

  Widget host(String? status, {String stage = 'consulting'}) {
    return ProviderScope(
      overrides: [
        opportunityProvider('o1').overrideWith(
          (ref) async => Opportunity.fromJson({
            'id': 'o1',
            'title': 'Đàn KAWAI cho chị Lan',
            'opportunity_stage': stage,
            'opportunity_status': ?status,
            'expected_value': 10000000,
          }),
        ),
        opportunityAccessProvider.overrideWithValue(
          const ResourceAccess(readScope: AccessScope.all, canUpdate: true),
        ),
        pipelineCatalogProvider.overrideWith(
          (ref) async => const PipelineCatalog(defaultCode: '', pipelines: []),
        ),
      ],
      child: MaterialApp(
        theme: OmniTheme.light(TargetPlatform.android),
        home: const OpportunityDetailPage(opportunityId: 'o1'),
      ),
    );
  }

  testWidgets('cơ hội đang mở: có cả hai nút', (tester) async {
    await tester.pumpWidget(host('OPEN'));
    await tester.pumpAndSettle();

    expect(find.text('Đánh dấu thắng'), findsOneWidget);
    expect(find.text('Đổi giai đoạn'), findsOneWidget);
  });

  testWidgets('cơ hội đã huỷ: không còn Đánh dấu thắng lẫn Đổi giai đoạn', (
    tester,
  ) async {
    await tester.pumpWidget(host('CANCELLED'));
    await tester.pumpAndSettle();

    expect(find.text('Đánh dấu thắng'), findsNothing);
    expect(find.text('Đổi giai đoạn'), findsNothing);
  });

  testWidgets(
    'đã thắng / đã thua: ẩn Đánh dấu thắng, vẫn đổi giai đoạn (mở lại)',
    (tester) async {
      for (final (status, stage) in [('WON', 'won'), ('LOST', 'lost')]) {
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(host(status, stage: stage));
        await tester.pumpAndSettle();

        expect(find.text('Đánh dấu thắng'), findsNothing, reason: status);
        expect(find.text('Đổi giai đoạn'), findsOneWidget, reason: status);
      }
    },
  );
}
