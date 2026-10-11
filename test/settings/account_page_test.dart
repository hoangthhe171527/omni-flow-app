import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:omni_app/core/config/app_config.dart';
import 'package:omni_app/core/error/app_exception.dart';
import 'package:omni_app/core/storage/preferences_store.dart';
import 'package:omni_app/core/theme/theme_mode_controller.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/modules/auth/application/login_controller.dart';
import 'package:omni_app/modules/channels/application/channels_providers.dart';
import 'package:omni_app/modules/channels/domain/channel_connection.dart';
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

  late ProviderContainer container;
  late GoRouter router;

  Future<_FakeSession> pump(
    WidgetTester t, {
    AccessPolicy policy = const AccessPolicy({}),
    int tenants = 1,
    Object? deletionError,
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
            container = ProviderScope.containerOf(context);
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

  testWidgets('đủ quyền: Đội nhóm 8 người, Kênh ● 4 · ● 1 lỗi, phiên bản', (
    t,
  ) async {
    await pump(
      t,
      policy: const AccessPolicy({'membership.members.read', 'channels.read'}),
    );
    expect(find.text('8 người'), findsOneWidget);
    expect(find.text('1 lỗi'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    await t.scrollUntilVisible(
      find.text('Viomni ${AppConfig.appVersion}'),
      200,
    );
    expect(find.text('Viomni ${AppConfig.appVersion}'), findsOneWidget);
  });

  testWidgets('thiếu quyền: không có Đội nhóm, Kênh kết nối', (t) async {
    await pump(t, policy: const AccessPolicy({}));
    expect(find.text('Đội nhóm'), findsNothing);
    expect(find.text('Kênh kết nối'), findsNothing);
    expect(find.text('Quyền của tôi'), findsOneWidget);
  });

  testWidgets('bấm các dòng điều hướng đi đúng route', (t) async {
    await pump(
      t,
      policy: const AccessPolicy({'membership.members.read', 'channels.read'}),
    );
    for (final (label, route) in const [
      ('Đội nhóm', 'team.list'),
      ('Kênh kết nối', 'channels.list'),
      ('Quyền của tôi', 'settings.permissions'),
      ('Thông báo', 'settings.notifications'),
      ('Nền', 'settings.background'),
    ]) {
      await t.ensureVisible(find.text(label));
      await t.tap(find.text(label));
      await t.pumpAndSettle();
      expect(find.text('đích:$route'), findsOneWidget, reason: label);
      router.pop();
      await t.pumpAndSettle();
    }
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

  testWidgets('Giao diện: Sáng / Tối / Theo máy đổi themeModeProvider', (
    t,
  ) async {
    await pump(t);
    expect(container.read(themeModeProvider), ThemeMode.system);
    await t.tap(find.text('Tối'));
    await t.pumpAndSettle();
    expect(container.read(themeModeProvider), ThemeMode.dark);
    await t.tap(find.text('Sáng'));
    await t.pumpAndSettle();
    expect(container.read(themeModeProvider), ThemeMode.light);
    await t.tap(find.text('Theo máy'));
    await t.pumpAndSettle();
    expect(container.read(themeModeProvider), ThemeMode.system);
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

  testWidgets('Xóa tài khoản: sai mật khẩu báo lỗi, vẫn ở màn', (t) async {
    final s = await pump(
      t,
      deletionError: const ValidationException('Mật khẩu không đúng.'),
    );
    await t.scrollUntilVisible(find.text('Xóa tài khoản'), 200);
    await t.tap(find.text('Xóa tài khoản'));
    await t.pumpAndSettle();
    expect(find.widgetWithText(FilledButton, 'Xác nhận xóa'), findsOneWidget);
    await t.enterText(find.byType(TextField), 'sai');
    await t.tap(find.byType(CheckboxListTile));
    await t.pump();
    await t.tap(find.widgetWithText(FilledButton, 'Xác nhận xóa'));
    await t.pumpAndSettle();
    expect(find.text('Mật khẩu không đúng.'), findsOneWidget);
    expect(s.deletionCalls, ['sai']);
    expect(find.byType(AccountPage), findsOneWidget);
  });

  testWidgets('Xóa tài khoản: huỷ hộp thoại thì không gọi API', (t) async {
    final s = await pump(t);
    await t.scrollUntilVisible(find.text('Xóa tài khoản'), 200);
    await t.tap(find.text('Xóa tài khoản'));
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(TextButton, 'Hủy'));
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

  testWidgets('Kênh kết nối: trình đọc màn hình nghe "4 chạy, 1 lỗi"', (
    t,
  ) async {
    final handle = t.ensureSemantics();
    await pump(t, policy: const AccessPolicy({'channels.read'}));
    expect(find.bySemanticsLabel('4 chạy, 1 lỗi'), findsOneWidget);
    handle.dispose();
  });

  testWidgets(
    'Hỗ trợ và Chính sách có mũi tên ra ngoài, Xóa tài khoản thì không',
    (t) async {
      await pump(t);
      await t.scrollUntilVisible(find.text('Xóa tài khoản'), 200);
      for (final label in ['Trung tâm hỗ trợ', 'Chính sách quyền riêng tư']) {
        expect(
          find.descendant(
            of: find
                .ancestor(of: find.text(label), matching: find.byType(InkWell))
                .first,
            matching: find.byIcon(Icons.open_in_new_rounded),
          ),
          findsOneWidget,
          reason: label,
        );
      }
      expect(find.byIcon(Icons.open_in_new_rounded), findsNWidgets(2));
    },
  );

  group('mở liên kết ngoài', () {
    const channel = MethodChannel('plugins.flutter.io/url_launcher');
    final calls = <MethodCall>[];

    void mock(Future<Object?> Function(MethodCall) handler) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) {
            calls.add(call);
            return handler(call);
          });
    }

    setUp(calls.clear);
    tearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );

    for (final (label, expected) in [
      ('Trung tâm hỗ trợ', AppConfig.supportUrl),
      ('Chính sách quyền riêng tư', AppConfig.privacyPolicyUrl),
    ]) {
      testWidgets('$label: nền tảng ném PlatformException → snackbar lỗi', (
        t,
      ) async {
        mock((_) async => throw PlatformException(code: 'ACTIVITY_NOT_FOUND'));
        await pump(t);
        await t.scrollUntilVisible(find.text(label), 200);
        await t.tap(find.text(label));
        await t.pumpAndSettle();
        expect(
          find.text('Không mở được liên kết. Vui lòng thử lại.'),
          findsOneWidget,
        );
        expect(calls.single.arguments['url'], expected.toString());
      });
    }

    testWidgets('trả false → vẫn snackbar lỗi', (t) async {
      mock((_) async => false);
      await pump(t);
      await t.scrollUntilVisible(find.text('Trung tâm hỗ trợ'), 200);
      await t.tap(find.text('Trung tâm hỗ trợ'));
      await t.pumpAndSettle();
      expect(
        find.text('Không mở được liên kết. Vui lòng thử lại.'),
        findsOneWidget,
      );
    });
  });

  testWidgets('đổi ảnh đại diện có nhãn và vùng chạm ≥ 44', (t) async {
    final handle = t.ensureSemantics();
    await pump(t);
    expect(find.bySemanticsLabel('Đổi ảnh đại diện'), findsOneWidget);
    expect(
      t.getSize(find.bySemanticsLabel('Đổi ảnh đại diện')).shortestSide,
      greaterThanOrEqualTo(44),
    );
    handle.dispose();
  });
}
