import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/modules/customers/application/customers_providers.dart';
import 'package:omni_app/modules/customers/domain/customer.dart';
import 'package:omni_app/modules/customers/presentation/customer_detail_page.dart';
import 'package:omni_app/security/permissions/access_scope.dart';
import 'package:omni_app/security/permissions/resource_access.dart';
import 'package:omni_app/security/session/session.dart';
import 'package:omni_app/security/session/session_controller.dart';

/// Ô "Tổng giá trị" và "Tương tác" của hồ sơ khách (GD-I11, APP-I4, Q8a).
///
/// API cũ (chưa có A1) không có `orders_total`/`last_interaction_at`: hai ô
/// hiện "—", không hiện `lifetime_booking_value` cũ hay mốc sửa hồ sơ.
void main() {
  setUpAll(() => initializeDateFormatting('vi_VN'));

  Widget host(Map<String, dynamic> json) => ProviderScope(
    overrides: [
      customerProvider(
        'c1',
      ).overrideWith((ref) async => Customer.fromJson(json)),
      customerAccessProvider.overrideWithValue(
        const ResourceAccess(readScope: AccessScope.all),
      ),
      sessionProvider.overrideWithValue(
        const Session(status: SessionStatus.authenticated),
      ),
    ],
    child: MaterialApp(
      theme: OmniTheme.light(TargetPlatform.android),
      home: const CustomerDetailPage(customerId: 'c1'),
    ),
  );

  /// Chữ của ô thống kê có nhãn [label].
  String statValue(WidgetTester tester, String label) {
    final tile = find.ancestor(
      of: find.text(label),
      matching: find.byWidgetPredicate(
        (w) => w.runtimeType.toString() == 'OmniStatTile',
      ),
    );
    final texts = tester
        .widgetList<Text>(
          find.descendant(of: tile, matching: find.byType(Text)),
        )
        .map((t) => t.data)
        .where((s) => s != label)
        .toList();
    return texts.single!;
  }

  testWidgets('API cũ: Tổng giá trị và Tương tác đều là —', (tester) async {
    await tester.pumpWidget(
      host({
        'id': 'c1',
        'display_name': 'Chú Đức',
        'lifetime_booking_value': 9000000,
        'updated_at': '2026-09-30T03:00:00Z',
      }),
    );
    await tester.pumpAndSettle();

    expect(statValue(tester, 'Tổng giá trị'), '—');
    expect(statValue(tester, 'Tương tác'), '—');
  });

  testWidgets('API mới: tổng đơn và mốc tương tác có thật', (tester) async {
    await tester.pumpWidget(
      host({
        'id': 'c1',
        'display_name': 'Chú Đức',
        'orders_total': 3200000,
        'last_interaction_at': DateTime.now()
            .toUtc()
            .subtract(const Duration(days: 3))
            .toIso8601String(),
      }),
    );
    await tester.pumpAndSettle();

    expect(statValue(tester, 'Tổng giá trị'), '3,2 tr');
    expect(statValue(tester, 'Tương tác'), '3 ngày');
  });
}
