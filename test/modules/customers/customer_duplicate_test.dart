import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/core/network/api_client.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/modules/customers/data/customers_api.dart';
import 'package:omni_app/modules/customers/presentation/customer_form_page.dart';

/// Hồ sơ trùng NGOÀI phạm vi của người đang gõ (phát hiện #9 ngoài audit).
///
/// `GET /customers/check-duplicate` vẫn báo hồ sơ đó (để không tạo trùng) nhưng
/// `in_scope=false` và che mọi khoá liên hệ (`FindDuplicateCustomers`). App từng
/// hiện "Khách hàng" kèm nút "Xem" — bấm vào là 403.
void main() {
  const outOfScope =
      '{"success":true,"data":[{"id":"x","display_name":null,'
      '"legal_name":null,"primary_contact_phone":null,"in_scope":false}]}';
  const inScope =
      '{"success":true,"data":[{"id":"y","display_name":"Chị Lan",'
      '"primary_contact_phone":"0901000001","in_scope":true}]}';

  CustomersApi api(String body) =>
      CustomersApi(ApiClient(Dio()..httpClientAdapter = _JsonAdapter(body)));

  test('in_scope=false → không xem được, tên là câu chung', () async {
    final match = await api(outOfScope).checkDuplicate(phone: '0901000001');
    expect(match!.inScope, isFalse);
    expect(match.name, 'Hồ sơ do người khác phụ trách');
  });

  test('in_scope=true (hoặc API cũ không có khoá) → xem được', () async {
    final match = await api(inScope).checkDuplicate(phone: '0901000001');
    expect(match!.inScope, isTrue);
    expect(match.name, 'Chị Lan');
  });

  Future<void> typePhone(WidgetTester tester, String body) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [customersApiProvider.overrideWithValue(api(body))],
        child: MaterialApp(
          theme: OmniTheme.light(TargetPlatform.android),
          home: const CustomerFormPage(),
        ),
      ),
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, '09xx xxx xxx'),
      '0901000001',
    );
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
  }

  testWidgets('form: hồ sơ trùng ngoài phạm vi không có nút Xem', (
    tester,
  ) async {
    await typePhone(tester, outOfScope);
    expect(find.textContaining('Số điện thoại này đã tồn tại'), findsOneWidget);
    expect(
      find.textContaining('Hồ sơ do người khác phụ trách'),
      findsOneWidget,
    );
    expect(find.widgetWithText(TextButton, 'Xem'), findsNothing);
  });

  testWidgets('form: hồ sơ trùng trong phạm vi vẫn có nút Xem', (tester) async {
    await typePhone(tester, inScope);
    expect(find.widgetWithText(TextButton, 'Xem'), findsOneWidget);
  });
}

class _JsonAdapter implements HttpClientAdapter {
  _JsonAdapter(this.body);

  final String body;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    body,
    200,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );

  @override
  void close({bool force = false}) {}
}
