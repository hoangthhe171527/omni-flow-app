import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/modules/opportunities/application/opportunities_providers.dart';
import 'package:omni_app/modules/opportunities/domain/opportunity.dart';
import 'package:omni_app/modules/opportunities/domain/pipeline_catalog.dart';
import 'package:omni_app/modules/opportunities/presentation/customer_opportunities_section.dart';
import 'package:omni_app/modules/opportunities/presentation/widgets/opportunity_row.dart';
import 'package:omni_app/security/permissions/access_scope.dart';
import 'package:omni_app/security/permissions/resource_access.dart';
import 'package:omni_app/security/session/session.dart';
import 'package:omni_app/security/session/session_controller.dart';

/// Đoạn Cơ hội trong hồ sơ khách: đổi giai đoạn (giữ dòng) theo cùng quyền
/// như danh sách cơ hội — `canUpdate`.
void main() {
  setUpAll(() => initializeDateFormatting('vi_VN'));

  Widget host({required bool canUpdate}) => ProviderScope(
    overrides: [
      customerOpportunitiesProvider('c1').overrideWith(
        (ref) async => [
          Opportunity.fromJson({
            'id': 'o1',
            'title': 'Đàn KAWAI',
            'opportunity_stage': 'consulting',
            'expected_value': 1000000,
          }),
        ],
      ),
      pipelineCatalogProvider.overrideWith(
        (ref) async => const PipelineCatalog(defaultCode: '', pipelines: []),
      ),
      opportunityAccessProvider.overrideWithValue(
        ResourceAccess(readScope: AccessScope.all, canUpdate: canUpdate),
      ),
      sessionProvider.overrideWithValue(
        const Session(status: SessionStatus.authenticated),
      ),
    ],
    child: MaterialApp(
      theme: OmniTheme.light(TargetPlatform.android),
      home: const Scaffold(body: CustomerOpportunitiesTab(customerId: 'c1')),
    ),
  );

  testWidgets('được sửa cơ hội → dòng đổi được giai đoạn', (tester) async {
    await tester.pumpWidget(host(canUpdate: true));
    await tester.pumpAndSettle();

    expect(
      tester.widget<OpportunityRow>(find.byType(OpportunityRow)).canMove,
      isTrue,
    );
  });

  testWidgets('không được sửa → không đổi giai đoạn', (tester) async {
    await tester.pumpWidget(host(canUpdate: false));
    await tester.pumpAndSettle();

    expect(
      tester.widget<OpportunityRow>(find.byType(OpportunityRow)).canMove,
      isFalse,
    );
  });
}
