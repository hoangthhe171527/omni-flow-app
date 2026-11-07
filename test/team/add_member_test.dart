import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/core/network/api_client.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/modules/team/application/team_providers.dart';
import 'package:omni_app/modules/team/data/team_api.dart';
import 'package:omni_app/modules/team/domain/new_member.dart';
import 'package:omni_app/modules/team/domain/team_member.dart';
import 'package:omni_app/modules/team/presentation/team_page.dart';
import 'package:omni_app/security/permissions/access_policy.dart';
import 'package:omni_app/security/session/session.dart';
import 'package:omni_app/security/session/session_controller.dart';

/// Bug sheet 07/11: "Cho phép thêm nhân viên trên điện thoại".
void main() {
  late _Adapter adapter;

  const manager = {'membership.members.read', 'membership.members.create'};

  Widget host({
    Set<String> permissions = manager,
    bool userCreated = true,
    List<RoleOption> roles = const [
      RoleOption(slug: 'worker', label: 'Thợ'),
      RoleOption(slug: 'manager', label: 'Quản lý'),
    ],
  }) {
    adapter = _Adapter(userCreated: userCreated);

    return ProviderScope(
      overrides: [
        teamApiProvider.overrideWithValue(
          TeamApi(ApiClient(Dio()..httpClientAdapter = adapter)),
        ),
        teamDirectoryProvider.overrideWith(
          (ref) async => [
            TeamMember(membershipId: 'm1', userId: 'u1', name: 'Hằng Ni'),
          ],
        ),
        assignableRolesProvider.overrideWith((ref) async => roles),
        sessionProvider.overrideWithValue(
          Session(
            status: SessionStatus.authenticated,
            policy: AccessPolicy(permissions),
          ),
        ),
      ],
      child: MaterialApp(
        theme: OmniTheme.light(TargetPlatform.android),
        home: const TeamPage(),
      ),
    );
  }

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Thêm'));
    await tester.pumpAndSettle();
  }

  Finder field(String label) => find.descendant(
    of: find
        .ancestor(of: find.text(label), matching: find.byType(Column))
        .first,
    matching: find.byType(TextField),
  );

  testWidgets('không có quyền tạo thành viên thì không thấy nút Thêm', (
    tester,
  ) async {
    await tester.pumpWidget(host(permissions: {'membership.members.read'}));
    await tester.pumpAndSettle();

    expect(find.text('Thêm'), findsNothing);
  });

  testWidgets('tạo tài khoản: gửi đủ trường và hiện mật khẩu để gửi Zalo', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    await open(tester);

    await tester.enterText(field('Họ tên'), 'Phạm Văn Tùng');
    await tester.enterText(field('Số điện thoại'), '0912345678');
    await tester.enterText(field('Email đăng nhập'), 'tung@xuong.vn');
    await tester.tap(find.text('Quản lý'));
    final password = tester
        .widget<TextField>(field('Mật khẩu tạm'))
        .controller!
        .text;
    await tester.tap(find.widgetWithText(OutlinedButton, 'Tạo tài khoản'));
    await tester.pumpAndSettle();

    final request = adapter.single;
    expect(request.uri.path, '/api/v1/memberships/add-user');
    expect(request.data, {
      'email': 'tung@xuong.vn',
      'full_name': 'Phạm Văn Tùng',
      'phone': '0912345678',
      'member_type': 'employee',
      'password': password,
      'role_slug': 'manager',
    });
    expect(find.text('Đã thêm nhân viên'), findsOneWidget);
    expect(find.text(password), findsOneWidget);
    expect(find.text('Sao chép'), findsOneWidget);
  });

  testWidgets(
    'email đã có tài khoản: không đưa mật khẩu tạm (server không đổi)',
    (tester) async {
      await tester.pumpWidget(host(userCreated: false));
      await open(tester);

      await tester.enterText(field('Họ tên'), 'Lê Na');
      await tester.enterText(field('Email đăng nhập'), 'na@xuong.vn');
      await tester.tap(find.widgetWithText(OutlinedButton, 'Tạo tài khoản'));
      await tester.pumpAndSettle();

      expect(find.textContaining('mật khẩu cũ'), findsOneWidget);
      expect(find.text('Mật khẩu tạm'), findsNothing);
      expect(find.text('Sao chép'), findsNothing);
    },
  );

  testWidgets('mời qua email gọi /memberships/invite', (tester) async {
    await tester.pumpWidget(host());
    await open(tester);

    await tester.tap(find.text('Mời qua email'));
    await tester.pumpAndSettle();
    expect(find.text('Họ tên'), findsNothing);
    await tester.enterText(field('Email đăng nhập'), 'moi@xuong.vn');
    await tester.tap(find.widgetWithText(OutlinedButton, 'Gửi lời mời'));
    await tester.pumpAndSettle();

    expect(adapter.single.uri.path, '/api/v1/memberships/invite');
    expect(adapter.single.data, {
      'email': 'moi@xuong.vn',
      'member_type': 'employee',
    });
    expect(find.text('Đã gửi lời mời'), findsOneWidget);
  });

  testWidgets('email sai thì báo dưới ô, không gửi', (tester) async {
    await tester.pumpWidget(host());
    await open(tester);

    await tester.enterText(field('Họ tên'), 'A');
    await tester.enterText(field('Email đăng nhập'), 'khong-phai-email');
    await tester.tap(find.widgetWithText(OutlinedButton, 'Tạo tài khoản'));
    await tester.pumpAndSettle();

    expect(find.text('Email chưa đúng.'), findsOneWidget);
    expect(adapter.requests, isEmpty);
  });

  test('vai chọn được: bỏ admin, Thợ đứng đầu, tên tiếng Việt', () {
    final options = roleOptionsFrom([
      {'slug': 'admin', 'name': 'System Administrator'},
      {'slug': 'manager', 'name': 'Sales Manager'},
      {'slug': 'worker', 'name': 'Nhân viên thực thi'},
      {'slug': 'qc', 'name': 'Kiểm tra chất lượng'},
    ]);

    expect(options.map((o) => o.slug), ['worker', 'manager', 'qc']);
    expect(options.map((o) => o.label), [
      'Thợ',
      'Quản lý',
      'Kiểm tra chất lượng',
    ]);
  });

  test('mật khẩu tạm đủ mạnh cho server (≥ 8) và không có ký tự dễ nhầm', () {
    for (var i = 0; i < 50; i++) {
      final pw = generateTempPassword();
      expect(pw.length, greaterThanOrEqualTo(8));
      expect(pw, isNot(matches(RegExp('[01lIO]'))));
    }
  });
}

class _Adapter implements HttpClientAdapter {
  _Adapter({required this.userCreated});

  final bool userCreated;
  final List<RequestOptions> requests = [];

  RequestOptions get single {
    expect(requests, hasLength(1));
    return requests.single;
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode({
        'success': true,
        'data': {'user_created': userCreated},
      }),
      options.path.endsWith('add-user') ? 201 : 200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
