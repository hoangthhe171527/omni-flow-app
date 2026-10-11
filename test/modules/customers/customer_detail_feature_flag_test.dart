import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/core/module/customer_opportunities_section.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/modules/opportunities/presentation/customer_opportunities_section.dart';
import 'package:omni_app/modules/customers/application/customers_providers.dart';
import 'package:omni_app/modules/customers/domain/customer.dart';
import 'package:omni_app/modules/customers/presentation/customer_detail_page.dart';
import 'package:omni_app/modules/opportunities/application/opportunities_providers.dart';
import 'package:omni_app/security/permissions/access_policy.dart';
import 'package:omni_app/security/session/session.dart';
import 'package:omni_app/security/session/session_controller.dart';

/// Đợt 7 P5 (MS-I33): workspace tắt module Cơ hội thì hồ sơ khách không còn
/// nút "Cơ hội", tab Cơ hội, lời mời "Tạo cơ hội" (API sẽ trả 403
/// FEATURE_DISABLED) và không gọi API cơ hội.
void main() {
  var opportunityCalls = 0;

  Future<void> pump(WidgetTester tester, Map<String, bool> features) async {
    opportunityCalls = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          customerOpportunitiesSectionProvider.overrideWithValue(
            opportunitiesCustomerSection,
          ),
          customerOpportunitiesSectionProvider.overrideWithValue(
            opportunitiesCustomerSection,
          ),
          sessionProvider.overrideWithValue(
            Session(
              status: SessionStatus.authenticated,
              policy: const AccessPolicy({
                'crm.customers.read',
                'crm.sales_opportunities.read',
                'crm.sales_opportunities.create',
              }),
              features: features,
            ),
          ),
          customerProvider('c1').overrideWith(
            (ref) async => Customer.fromJson(const {
              'id': 'c1',
              'display_name': 'Chú Đức',
              'primary_contact_phone': '0900000000',
            }),
          ),
          customerSummaryProvider('c1').overrideWith((ref) async => null),
          customerOpportunitiesProvider('c1').overrideWith((ref) async {
            opportunityCalls++;
            return const [];
          }),
        ],
        child: MaterialApp(
          theme: OmniTheme.light(TargetPlatform.android),
          home: const CustomerDetailPage(customerId: 'c1'),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('cơ hội bật: có nút Cơ hội và tab; tab rỗng mời Tạo cơ hội', (
    tester,
  ) async {
    await pump(tester, const {});

    expect(find.text('Cơ hội'), findsOneWidget);
    expect(find.text('Cơ hội · 0'), findsOneWidget);
    await tester.tap(find.text('Cơ hội · 0'));
    await tester.pumpAndSettle();
    expect(find.text('Tạo cơ hội'), findsOneWidget);
    expect(opportunityCalls, 1);
  });

  testWidgets(
    'cơ hội tắt: không nút, không tab, không lời mời, không gọi API',
    (tester) async {
      await pump(tester, const {'opportunities': false});

      expect(find.text('Chú Đức'), findsWidgets);
      expect(find.textContaining('Cơ hội'), findsNothing);
      expect(find.text('Tạo cơ hội'), findsNothing);
      expect(opportunityCalls, 0);
    },
  );
}
