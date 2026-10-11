import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:omni_app/core/module/customer_opportunities_section.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/modules/opportunities/presentation/customer_opportunities_section.dart';
import 'package:omni_app/modules/customers/application/customers_providers.dart';
import 'package:omni_app/modules/customers/domain/customer.dart';
import 'package:omni_app/modules/customers/domain/customer_summary.dart';
import 'package:omni_app/modules/customers/presentation/customer_detail_page.dart';
import 'package:omni_app/security/permissions/access_policy.dart';
import 'package:omni_app/security/session/session.dart';
import 'package:omni_app/security/session/session_controller.dart';

/// Dải số "Đã mua" / "Đơn hàng" của hồ sơ khách (GD-I11, APP-I4, Q8a).
///
/// Con số lấy từ `GET /customers/{id}/summary` (đơn không huỷ do máy chủ
/// cộng), KHÔNG từ `lifetime_booking_value` cũ — số nhập tay không ai cập nhật.
void main() {
  setUpAll(() => initializeDateFormatting('vi_VN'));

  Widget host(CustomerSummary? summary, {Map<String, dynamic>? extra}) =>
      ProviderScope(
        overrides: [
          customerOpportunitiesSectionProvider.overrideWithValue(
            opportunitiesCustomerSection,
          ),
          customerOpportunitiesSectionProvider.overrideWithValue(
            opportunitiesCustomerSection,
          ),
          customerProvider('c1').overrideWith(
            (ref) async => Customer.fromJson({
              'id': 'c1',
              'display_name': 'Chú Đức',
              ...?extra,
            }),
          ),
          customerSummaryProvider('c1').overrideWith((ref) async => summary),
          sessionProvider.overrideWithValue(
            const Session(
              status: SessionStatus.authenticated,
              policy: AccessPolicy({'crm.customers.read'}),
            ),
          ),
        ],
        child: MaterialApp(
          theme: OmniTheme.light(TargetPlatform.android),
          home: const CustomerDetailPage(customerId: 'c1'),
        ),
      );

  testWidgets(
    'Đã mua theo summary máy chủ, không theo lifetime_booking_value',
    (tester) async {
      await tester.pumpWidget(
        host(
          const CustomerSummary(ordersTotal: 3200000, ordersCount: 7),
          extra: {'lifetime_booking_value': 9000000},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Đã mua'), findsOneWidget);
      expect(find.text('3,2 tr'), findsOneWidget);
      expect(find.text('9 tr'), findsNothing);
      expect(find.text('Đơn hàng'), findsOneWidget);
      expect(find.text('7'), findsOneWidget);
      // Không đọc được cơ hội → không có ô "Đang mở".
      expect(find.text('Đang mở'), findsNothing);
    },
  );

  testWidgets('summary không có (API cũ / 403) → không dải số', (tester) async {
    await tester.pumpWidget(
      host(null, extra: {'lifetime_booking_value': 9000000}),
    );
    await tester.pumpAndSettle();

    expect(find.text('Chú Đức'), findsOneWidget);
    expect(find.text('Đã mua'), findsNothing);
    expect(find.text('9 tr'), findsNothing);
  });

  testWidgets('summary chưa có đơn: tổng null hiện —', (tester) async {
    await tester.pumpWidget(host(const CustomerSummary()));
    await tester.pumpAndSettle();

    expect(find.text('Đã mua'), findsOneWidget);
    final stat = find.ancestor(
      of: find.text('Đã mua'),
      matching: find.byType(Column),
    );
    expect(
      find.descendant(of: stat.first, matching: find.text('—')),
      findsOneWidget,
    );
    expect(find.text('0'), findsOneWidget);
  });
}
