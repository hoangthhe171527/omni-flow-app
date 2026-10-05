import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/core/error/app_exception.dart';
import 'package:omni_app/core/network/api_client.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/modules/customers/data/customers_api.dart';
import 'package:omni_app/modules/customers/domain/customer.dart';
import 'package:omni_app/modules/customers/presentation/customer_form_page.dart';
import 'package:dio/dio.dart';

/// Form khách hiện MỌI lỗi 422 (CRM-X6, APP-I8).
///
/// Trước đây chỉ ba ô có `error:`, ô tên đọc `legal_name` trong khi lúc sửa app
/// gửi `display_name`, còn khoá không có ô (`assigned_sales_rep_id`,
/// `tax_code`, `metadata.*`) thì im lặng: bấm Lưu, nút hết quay, không gì xảy ra.
void main() {
  group('splitCustomerFormErrors', () {
    test('khoá có ô → đúng ô; tên nhận cả display_name', () {
      final split = splitCustomerFormErrors(
        const ValidationException(
          'x',
          errors: {
            'display_name': ['Tên quá dài'],
            'address': ['Địa chỉ tối đa 500 ký tự'],
          },
        ),
      );
      expect(split.fields, {
        'name': 'Tên quá dài',
        'address': 'Địa chỉ tối đa 500 ký tự',
      });
      expect(split.banner, isNull);
    });

    test('khoá không có ô → snackbar', () {
      final split = splitCustomerFormErrors(
        const ValidationException(
          'x',
          errors: {
            'assigned_sales_rep_id': [
              'Người phụ trách phải là thành viên đang làm',
            ],
          },
        ),
      );
      expect(split.fields, isEmpty);
      expect(split.banner, 'Người phụ trách phải là thành viên đang làm');
    });

    test('không có lỗi theo khoá → câu chung của API', () {
      final split = splitCustomerFormErrors(const ValidationException('x'));
      expect(split.fields, isEmpty);
      expect(split.banner, 'x');
    });
  });

  testWidgets(
    'lưu bị 422 ở địa chỉ → chữ lỗi dưới ô địa chỉ, nút Lưu bật lại',
    (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [customersApiProvider.overrideWithValue(_RejectingApi())],
          child: MaterialApp(
            theme: OmniTheme.light(TargetPlatform.android),
            home: const CustomerFormPage(),
          ),
        ),
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'VD: Nguyễn Thu Hà'),
        'Chú Đức',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, '09xx xxx xxx'),
        '0901000001',
      );
      await tester.pump(const Duration(milliseconds: 600));
      await tester.tap(find.text('Lưu khách hàng'));
      await tester.pumpAndSettle();

      expect(find.text('Địa chỉ tối đa 500 ký tự'), findsOneWidget);
      final save = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Lưu khách hàng'),
      );
      expect(save.onPressed, isNotNull);
    },
  );
}

class _RejectingApi extends CustomersApi {
  _RejectingApi() : super(ApiClient(Dio()));

  @override
  Future<DuplicateMatch?> checkDuplicate({String? phone, String? email}) =>
      Future.value();

  @override
  Future<Customer> create(Customer draft) => Future.error(
    const ValidationException(
      'Dữ liệu không hợp lệ.',
      errors: {
        'address': ['Địa chỉ tối đa 500 ký tự'],
      },
    ),
  );
}
