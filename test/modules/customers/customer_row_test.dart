import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:omni_app/design/components/components.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/modules/customers/domain/customer.dart';
import 'package:omni_app/modules/customers/presentation/widgets/customer_row.dart';
import 'package:omni_app/security/permissions/access_policy.dart';
import 'package:omni_app/security/session/session.dart';
import 'package:omni_app/security/session/session_controller.dart';

Customer c({
  double? lifetimeValue,
  List<String> tags = const [],
  String phone = '0901234567',
}) => Customer.fromJson({
  'id': 'c1',
  'display_name': 'Lan Anh',
  'primary_contact_phone': phone,
  'orders_total': ?lifetimeValue,
  'metadata': {'source': 'zalo', 'tags': tags},
});

final _theme = OmniTheme.light(TargetPlatform.android);

Widget host(Widget child, {bool reduce = false, bool canTask = true}) =>
    ProviderScope(
      overrides: [
        sessionProvider.overrideWithValue(
          Session(
            status: SessionStatus.authenticated,
            user: const SessionUser(id: 'u1', fullName: 'K', email: 'k@x.vn'),
            tenant: const SessionTenant(id: 't1', name: 'X'),
            policy: AccessPolicy(canTask ? const {'tasks.write'} : const {}),
          ),
        ),
      ],
      child: MaterialApp(
        theme: _theme,
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduce),
          child: Material(child: SingleChildScrollView(child: child)),
        ),
      ),
    );

void main() {
  setUpAll(() => initializeDateFormatting('vi_VN'));

  testWidgets('dòng khách không hiện tiền dù có lifetimeValue', (t) async {
    await t.pumpWidget(
      host(
        CustomerRow(
          customer: c(lifetimeValue: 186000000),
          expanded: false,
          onTap: () {},
        ),
      ),
    );
    expect(find.textContaining('tr'), findsNothing);
    expect(find.textContaining('₫'), findsNothing);
    expect(find.textContaining('186'), findsNothing);
  });

  testWidgets('chấm nhãn ở mép trái, có Semantics', (t) async {
    await t.pumpWidget(
      host(
        CustomerRow(
          customer: c(tags: ['Báo giá']),
          expanded: false,
          onTap: () {},
        ),
      ),
    );
    expect(find.bySemanticsLabel('Nhãn: Báo giá'), findsOneWidget);
    final dot = t.getRect(find.bySemanticsLabel('Nhãn: Báo giá'));
    final avatar = t.getRect(find.byType(OmniAvatar));
    expect(dot.right, lessThanOrEqualTo(avatar.left));
  });

  testWidgets('dòng phụ: loại nguồn · —  khi chưa liên hệ', (t) async {
    await t.pumpWidget(
      host(CustomerRow(customer: c(), expanded: false, onTap: () {})),
    );
    expect(find.textContaining('OA · —', findRichText: true), findsOneWidget);
  });

  testWidgets('mở ra có Nhắn · Gọi · Tạo việc · Hồ sơ; không số → Gọi tắt', (
    t,
  ) async {
    await t.pumpWidget(
      host(
        CustomerRow(
          customer: c(phone: ''),
          expanded: true,
          onTap: () {},
        ),
      ),
    );
    await t.pumpAndSettle();
    for (final l in ['Nhắn', 'Gọi', 'Tạo việc', 'Hồ sơ']) {
      expect(find.text(l), findsOneWidget);
    }
    InkWell inkOf(String label) => t.widget<InkWell>(
      find.ancestor(of: find.text(label), matching: find.byType(InkWell)).first,
    );
    expect(inkOf('Gọi').onTap, isNull);
    expect(inkOf('Nhắn').onTap, isNull);
    expect(inkOf('Hồ sơ').onTap, isNotNull);
  });

  testWidgets('không quyền tạo việc → ẩn Tạo việc', (t) async {
    await t.pumpWidget(
      host(
        CustomerRow(customer: c(), expanded: true, onTap: () {}),
        canTask: false,
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('Tạo việc'), findsNothing);
    expect(find.text('Hồ sơ'), findsOneWidget);
  });

  testWidgets('đóng thì không dựng hàng thao tác', (t) async {
    await t.pumpWidget(
      host(CustomerRow(customer: c(), expanded: false, onTap: () {})),
    );
    expect(find.text('Gọi'), findsNothing);
  });

  testWidgets(
    'giảm chuyển động: mở hàng thao tác không còn hoạt ảnh sau 1 pump',
    (t) async {
      await t.pumpWidget(
        host(
          CustomerRow(customer: c(), expanded: false, onTap: () {}),
          reduce: true,
        ),
      );
      await t.pumpWidget(
        host(
          CustomerRow(customer: c(), expanded: true, onTap: () {}),
          reduce: true,
        ),
      );
      await t.pump();
      expect(t.hasRunningAnimations, isFalse);
      expect(find.text('Gọi'), findsOneWidget);
    },
  );
}
