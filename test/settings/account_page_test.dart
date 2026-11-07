import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:omni_app/core/error/app_exception.dart';
import 'package:omni_app/core/storage/preferences_store.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/modules/auth/application/login_controller.dart';
import 'package:omni_app/modules/channels/application/channels_providers.dart';
import 'package:omni_app/modules/channels/domain/channel_connection.dart';
import 'package:dio/dio.dart';
import 'package:omni_app/core/network/api_client.dart';
import 'package:omni_app/modules/settings/data/password_api.dart';
import 'package:omni_app/modules/settings/presentation/account_page.dart';
import 'package:omni_app/modules/team/team.dart';
import 'package:omni_app/security/permissions/access_policy.dart';
import 'package:omni_app/security/session/auth_gateway.dart';
import 'package:omni_app/security/session/session.dart';
import 'package:omni_app/security/session/session_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeSession extends SessionController {
  _FakeSession(this.policy, this.deletionError);

  final AccessPolicy policy;
  final Object? deletionError;
  int chooseCalls = 0;
  int logoutCalls = 0;
  final List<String> deletionCalls = [];

  @override
  Session build() => Session(
    status: SessionStatus.authenticated,
    user: const SessionUser(
      id: 'u',
      fullName: 'Trần Huy Hoàng',
      email: 'h@x.vn',
    ),
    tenant: const SessionTenant(id: 't-1', name: 'Xưởng đàn Hoàng Gia'),
    policy: policy,
  );

  @override
  void chooseWorkspace() => chooseCalls++;

  @override
  Future<void> logout() async => logoutCalls++;

  @override
  Future<AccountDeletionReceipt> requestAccountDeletion({
    required String password,
  }) async {
    deletionCalls.add(password);
    if (deletionError != null) throw deletionError!;
    return const AccountDeletionReceipt(scheduledFor: null);
  }
}

ChannelConnection _conn(String id, ChannelStatus s) =>
    ChannelConnection.fromJson({
      'id': id,
      'channel_id': 'zalo_oa',
      'name': 'Kênh $id',
      'status': s.name,
    });

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late GoRouter router;

  Future<_FakeSession> pump(
    WidgetTester t, {
    AccessPolicy policy = const AccessPolicy({}),
    int tenants = 1,
    Object? deletionError,
    PasswordApi? passwordApi,
  }) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final session = _FakeSession(policy, deletionError);
    router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const AccountPage()),
        for (final name in const [
          'team.list',
          'channels.list',
          'settings.permissions',
          'settings.notifications',
          'settings.background',
        ])
          GoRoute(
            path: '/$name',
            name: name,
            builder: (_, _) => Scaffold(body: Text('đích:$name')),
          ),
      ],
    );
    addTearDown(router.dispose);

    await t.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          passwordApiProvider.overrideWithValue(
            passwordApi ?? _FakePasswordApi(),
          ),
          sessionControllerProvider.overrideWith(() => session),
          tenantOptionsProvider.overrideWith(
            (ref) async => [
              for (var i = 0; i < tenants; i++)
                TenantOption(id: 't-$i', name: 'Không gian $i'),
            ],
          ),
          teamDirectoryProvider.overrideWith(
            (ref) async => [
              for (var i = 0; i < 8; i++)
                TeamMember(membershipId: 'm$i', userId: 'u$i', name: 'NV $i'),
              const TeamMember(
                membershipId: 'mx',
                userId: 'ux',
                name: 'Đã nghỉ',
                status: 'inactive',
              ),
            ],
          ),
          channelsProvider.overrideWith(
            (ref) async => [
              for (var i = 0; i < 4; i++)
                _conn('ok$i', ChannelStatus.connected),
              _conn('bad', ChannelStatus.error),
            ],
          ),
        ],
        child: Consumer(
          builder: (context, ref, _) {
            return MaterialApp.router(
              theme: OmniTheme.light(),
              routerConfig: router,
            );
          },
        ),
      ),
    );
    await t.pumpAndSettle();
    return session;
  }

  testWidgets('chỉ việc của tài khoản: bảo mật, quyền, đăng xuất', (t) async {
    // Thông báo, nền, giao diện, hỗ trợ đã về "Tất cả"; Đội nhóm, Kênh kết
    // nối có ô ở "Tất cả" (`tat-ca-tai-khoan-uiux.html`).
    await pump(t, policy: const AccessPolicy({'*'}));
    expect(find.text('Bảo mật'), findsOneWidget);
    expect(find.text('Đổi mật khẩu'), findsOneWidget);
    expect(find.text('Quyền của tôi'), findsOneWidget);
    for (final gone in [
      'Đội nhóm',
      'Kênh kết nối',
      'Thông báo',
      'Nền',
      'Giao diện',
      'Trung tâm hỗ trợ',
      'Chính sách quyền riêng tư',
    ]) {
      expect(find.text(gone), findsNothing, reason: gone);
    }
  });

  testWidgets('Quyền của tôi đi đúng route', (t) async {
    await pump(t);
    await t.tap(find.text('Quyền của tôi'));
    await t.pumpAndSettle();
    expect(find.text('đích:settings.permissions'), findsOneWidget);
  });

  group('đổi mật khẩu', () {
    testWidgets('hai ô chưa khớp hoặc quá ngắn thì không lưu được', (t) async {
      await pump(t);
      await t.tap(find.text('Đổi mật khẩu'));
      await t.pumpAndSettle();
      final fields = find.byType(TextField);
      await t.enterText(fields.at(1), 'ngan');
      await t.pump();
      expect(find.text('Tối thiểu 8 ký tự.'), findsOneWidget);
      await t.enterText(fields.at(1), 'MatKhauMoi1!');
      await t.enterText(fields.at(2), 'MatKhauKhac1!');
      await t.pump();
      expect(find.text('Hai mật khẩu chưa khớp.'), findsOneWidget);
      final save = t.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Lưu mật khẩu mới'),
      );
      expect(save.onPressed, isNull);
    });

    testWidgets('lưu gửi mật khẩu hiện tại + mới, đóng tấm và báo', (t) async {
      final api = _FakePasswordApi();
      await pump(t, passwordApi: api);
      await t.tap(find.text('Đổi mật khẩu'));
      await t.pumpAndSettle();
      final fields = find.byType(TextField);
      await t.enterText(fields.at(0), 'MatKhauCu1!');
      await t.enterText(fields.at(1), 'MatKhauMoi1!');
      await t.enterText(fields.at(2), 'MatKhauMoi1!');
      await t.pump();
      await t.tap(find.widgetWithText(OutlinedButton, 'Lưu mật khẩu mới'));
      await t.pumpAndSettle();
      expect(api.calls, [('MatKhauCu1!', 'MatKhauMoi1!')]);
      expect(find.text('Lưu mật khẩu mới'), findsNothing);
      expect(find.text('Đã đổi mật khẩu.'), findsOneWidget);
    });

    testWidgets('sai mật khẩu hiện tại: báo dưới ô, tấm vẫn mở', (t) async {
      final api = _FakePasswordApi(
        error: const ValidationException('Mật khẩu hiện tại không đúng.'),
      );
      await pump(t, passwordApi: api);
      await t.tap(find.text('Đổi mật khẩu'));
      await t.pumpAndSettle();
      final fields = find.byType(TextField);
      await t.enterText(fields.at(0), 'sai');
      await t.enterText(fields.at(1), 'MatKhauMoi1!');
      await t.enterText(fields.at(2), 'MatKhauMoi1!');
      await t.pump();
      await t.tap(find.widgetWithText(OutlinedButton, 'Lưu mật khẩu mới'));
      await t.pumpAndSettle();
      expect(find.text('Mật khẩu hiện tại không đúng.'), findsOneWidget);
      expect(find.text('Lưu mật khẩu mới'), findsOneWidget);
    });
  });

  testWidgets('Đổi không hiện khi chỉ có một không gian', (t) async {
    await pump(t);
    expect(find.text('Đổi'), findsNothing);
  });

  testWidgets('Đổi chỉ hiện khi có ≥2 không gian và gọi chooseWorkspace', (
    t,
  ) async {
    final s = await pump(t, tenants: 2);
    await t.tap(find.text('Đổi'));
    expect(s.chooseCalls, 1);
  });

  testWidgets('Đăng xuất hỏi xác nhận rồi mới đăng xuất', (t) async {
    final s = await pump(t);
    await t.scrollUntilVisible(
      find.widgetWithText(OutlinedButton, 'Đăng xuất'),
      200,
    );
    await t.tap(find.widgetWithText(OutlinedButton, 'Đăng xuất'));
    await t.pumpAndSettle();
    expect(s.logoutCalls, 0);
    await t.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(TextButton, 'Đăng xuất'),
      ),
    );
    await t.pumpAndSettle();
    expect(s.logoutCalls, 1);
  });

  testWidgets('Đăng xuất: huỷ thì không đăng xuất', (t) async {
    final s = await pump(t);
    await t.scrollUntilVisible(
      find.widgetWithText(OutlinedButton, 'Đăng xuất'),
      200,
    );
    await t.tap(find.widgetWithText(OutlinedButton, 'Đăng xuất'));
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(TextButton, 'Huỷ'));
    await t.pumpAndSettle();
    expect(s.logoutCalls, 0);
  });

  testWidgets('Xoá tài khoản: sai mật khẩu báo lỗi, vẫn ở màn', (t) async {
    final s = await pump(
      t,
      deletionError: const ValidationException('Mật khẩu không đúng.'),
    );
    await t.scrollUntilVisible(find.text('Xoá tài khoản'), 200);
    await t.tap(find.text('Xoá tài khoản'));
    await t.pumpAndSettle();
    expect(find.widgetWithText(FilledButton, 'Xác nhận xoá'), findsOneWidget);
    await t.enterText(find.byType(TextField), 'sai');
    await t.tap(find.byType(CheckboxListTile));
    await t.pump();
    await t.tap(find.widgetWithText(FilledButton, 'Xác nhận xoá'));
    await t.pumpAndSettle();
    expect(find.text('Mật khẩu không đúng.'), findsOneWidget);
    expect(s.deletionCalls, ['sai']);
    expect(find.byType(AccountPage), findsOneWidget);
  });

  testWidgets('Xoá tài khoản: huỷ hộp thoại thì không gọi API', (t) async {
    final s = await pump(t);
    await t.scrollUntilVisible(find.text('Xoá tài khoản'), 200);
    await t.tap(find.text('Xoá tài khoản'));
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(TextButton, 'Huỷ'));
    await t.pumpAndSettle();
    expect(s.deletionCalls, isEmpty);
  });

  testWidgets('dòng điều hướng cao ≥ 44', (t) async {
    await pump(t);
    expect(
      t
          .getSize(
            find
                .ancestor(
                  of: find.text('Quyền của tôi'),
                  matching: find.byType(InkWell),
                )
                .first,
          )
          .height,
      greaterThanOrEqualTo(44),
    );
  });

  testWidgets('tuỳ chọn ảnh đại diện có nhãn và vùng chạm ≥ 44', (t) async {
    final handle = t.ensureSemantics();
    await pump(t);
    expect(find.bySemanticsLabel('Tuỳ chọn ảnh đại diện'), findsOneWidget);
    expect(
      t.getSize(find.bySemanticsLabel('Tuỳ chọn ảnh đại diện')).shortestSide,
      greaterThanOrEqualTo(44),
    );
    handle.dispose();
  });

  testWidgets('chạm avatar mở menu neo trước khi mở thư viện ảnh', (t) async {
    await pump(t);
    await t.tap(find.bySemanticsLabel('Tuỳ chọn ảnh đại diện'));
    await t.pumpAndSettle();

    expect(find.byKey(const Key('profile-avatar-menu')), findsOneWidget);
    expect(find.text('Đổi ảnh'), findsOneWidget);
    expect(find.text('Xoá ảnh'), findsNothing);
  });
}

class _FakePasswordApi extends PasswordApi {
  _FakePasswordApi({this.error}) : super(ApiClient(Dio()));

  final Object? error;
  final List<(String, String)> calls = [];

  @override
  Future<void> change({required String current, required String next}) async {
    calls.add((current, next));
    if (error != null) throw error!;
  }
}
