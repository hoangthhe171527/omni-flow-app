import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/modules/customers/application/customers_providers.dart';
import 'package:omni_app/modules/customers/domain/customer.dart';
import 'package:omni_app/modules/customers/presentation/customer_detail_page.dart';
import 'package:omni_app/security/permissions/access_policy.dart';
import 'package:omni_app/security/session/session.dart';
import 'package:omni_app/security/session/session_controller.dart';

/// Đợt 7 P5 (MS-I33): workspace tắt module Cơ hội thì hồ sơ khách không còn
/// nút "Tạo cơ hội" (API sẽ trả 403 FEATURE_DISABLED).
void main() {
  Future<void> pump(WidgetTester tester, Map<String, bool> features) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionProvider.overrideWithValue(
            Session(
              status: SessionStatus.authenticated,
              policy: const AccessPolicy({'crm.customers.read'}),
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
        ],
        child: const MaterialApp(home: CustomerDetailPage(customerId: 'c1')),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('cơ hội bật: có nút Tạo cơ hội', (tester) async {
    await pump(tester, const {});

    expect(find.text('Tạo cơ hội'), findsOneWidget);
  });

  testWidgets('cơ hội tắt: không có nút Tạo cơ hội', (tester) async {
    await pump(tester, const {'opportunities': false});

    expect(find.text('Chú Đức'), findsWidgets);
    expect(find.text('Tạo cơ hội'), findsNothing);
  });
}
