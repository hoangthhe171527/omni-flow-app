import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/modules/customers/application/customers_providers.dart';
import 'package:omni_app/modules/customers/presentation/widgets/customer_filter_panel.dart';
import 'package:omni_app/security/permissions/access_scope.dart';
import 'package:omni_app/security/permissions/resource_access.dart';

/// Ô tìm khách theo bộ lọc khi bộ lọc bị đặt lại từ nơi khác (dựng lại khi
/// quyền đổi): ô về rỗng và lượt gõ đang chờ bị huỷ, không đặt lại chữ cũ.
void main() {
  late ProviderContainer container;

  Future<Finder> pumpRow(WidgetTester tester) async {
    container = ProviderContainer(
      overrides: [
        customerAccessProvider.overrideWithValue(
          const ResourceAccess(readScope: AccessScope.all),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: OmniTheme.light(TargetPlatform.android),
          home: Scaffold(
            appBar: CustomerSearchRow(
              filtersOpen: false,
              onToggleFilters: () {},
            ),
          ),
        ),
      ),
    );
    return find.descendant(
      of: find.byType(CustomerSearchRow),
      matching: find.byType(TextField),
    );
  }

  String text(WidgetTester tester, Finder field) =>
      tester.widget<TextField>(field).controller!.text;

  testWidgets('bộ lọc đặt lại từ ngoài → ô tìm về rỗng', (tester) async {
    final field = await pumpRow(tester);
    await tester.enterText(field, 'lan');
    await tester.pump(const Duration(milliseconds: 400));
    expect(container.read(customerFilterProvider).search, 'lan');

    container.invalidate(customerFilterProvider);
    await tester.pump();
    expect(container.read(customerFilterProvider).search, '');
    expect(text(tester, field), '');
  });

  testWidgets('đặt lại khi đang chờ gõ → lượt gõ cũ không quay lại', (
    tester,
  ) async {
    final field = await pumpRow(tester);
    await tester.enterText(field, 'lan');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.enterText(field, 'lan anh');
    await tester.pump(const Duration(milliseconds: 100));

    container.invalidate(customerFilterProvider);
    // Riverpod dựng lại ở khung hình kế (vsync qua microtask).
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(container.read(customerFilterProvider).search, '');
    expect(text(tester, field), '');
  });
}
