import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
          child: Scaffold(body: SingleChildScrollView(child: child)),
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

  test('chuẩn hoá số: tel giữ + đầu, zalo đổi 0 → 84', () {
    expect(dialNumber(' 0901 234.567 '), '0901234567');
    expect(dialNumber('+84 901-234-567'), '+84901234567');
    expect(zaloNumber('0901 234 567'), '84901234567');
    expect(zaloNumber('+84 901 234 567'), '84901234567');
  });

  test('tiền tố quốc tế 00 → +; zalo bỏ 00', () {
    expect(dialNumber('0084 901 234 567'), '+84901234567');
    expect(dialNumber('001 555 0100'), '+15550100');
    expect(zaloNumber('0084 901 234 567'), '84901234567');
    expect(zaloNumber('+84 0901 234 567'), '84901234567');
  });

  test('tel bỏ số 0 gõ thừa sau +84 / 0084, như zaloNumber', () {
    expect(dialNumber('+84 0901 234 567'), '+84901234567');
    expect(dialNumber('0084 0901 234 567'), '+84901234567');
    expect(dialNumber('+84 901 234 567'), '+84901234567');
    expect(dialNumber('0901 234 567'), '0901234567', reason: 'nội địa giữ 0');
  });

  test('hasPhone cần có chữ số', () {
    Customer withPhone(String phone) =>
        Customer.fromJson({'id': 'c1', 'primary_contact_phone': phone});
    expect(withPhone('0901 234 567').hasPhone, isTrue);
    expect(withPhone('  ').hasPhone, isFalse);
    expect(withPhone('chưa có').hasPhone, isFalse);
    expect(withPhone('-').hasPhone, isFalse);
  });

  group('mở ứng dụng ngoài', () {
    const channel = MethodChannel('plugins.flutter.io/url_launcher');
    final calls = <MethodCall>[];

    setUp(() {
      calls.clear();
      TestWidgetsFlutterBinding.ensureInitialized();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return false;
          });
    });
    tearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );

    testWidgets('Gọi thất bại → SnackBar; số được chuẩn hoá', (t) async {
      await t.pumpWidget(
        host(
          CustomerRow(
            customer: c(phone: '0901 234 567'),
            expanded: true,
            onTap: () {},
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.tap(find.text('Gọi'));
      await t.pumpAndSettle();
      expect(find.text('Không mở được ứng dụng gọi điện.'), findsOneWidget);
      expect(calls.single.arguments['url'], 'tel:0901234567');
    });

    testWidgets('Nhắn thất bại → SnackBar; zalo.me dùng 84', (t) async {
      await t.pumpWidget(
        host(
          CustomerRow(
            customer: c(phone: '0901 234 567'),
            expanded: true,
            onTap: () {},
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.tap(find.text('Nhắn'));
      await t.pumpAndSettle();
      expect(find.text('Không mở được Zalo.'), findsOneWidget);
      expect(calls.single.arguments['url'], 'https://zalo.me/84901234567');
    });
  });
}
