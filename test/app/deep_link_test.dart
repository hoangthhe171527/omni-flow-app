import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/app/router/app_router.dart';
import 'package:omni_app/core/module/module_registry.dart';
import 'package:omni_app/core/module/module_route.dart';
import 'package:omni_app/core/module/nav_destination.dart';
import 'package:omni_app/core/module/omni_module.dart';
import 'package:omni_app/security/permissions/access_policy.dart';
import 'package:omni_app/security/session/session.dart';
import 'package:omni_app/security/session/session_controller.dart';

/// Mở thẳng một màn cụ thể phải TỚI được màn đó.
///
/// App khởi động ở trạng thái `restoring`, và redirect của router đẩy mọi thứ
/// về splash. Bản đầu vứt luôn đích đến ở bước đó, rồi khi khôi phục xong thì
/// đưa về tab mặc định — nên ba đường vào một công việc đều rơi về màn chủ:
///
///   - chạm thông báo đẩy ("việc X đã hoàn thành") — PushTarget.task
///   - tải lại trang khi đang xem chi tiết
///   - dán một đường dẫn
///
/// Người dùng gọi đây là "không xem được chi tiết công việc", và nhìn từ trong
/// app thì đó là đúng: màn hình mở ra rồi biến mất.
void main() {
  /// SplashPage quay một spinner không ngừng, nên pumpAndSettle không bao giờ
  /// về. Bơm một khoảng cố định là đủ: thứ đang kiểm là redirect, và nó chạy
  /// đồng bộ ngay trong khung hình kế tiếp.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
  }

  /// Phiên đổi được trong lúc test, để diễn lại đúng chuỗi restoring →
  /// authenticated mà app thật đi qua lúc khởi động.
  final fakeSession = StateProvider<Session>(
    (ref) => const Session(status: SessionStatus.restoring),
  );

  ProviderContainer containerFor() => ProviderContainer(
    overrides: [
      modulesProvider.overrideWithValue(const [_FakeModule()]),
      sessionProvider.overrideWith((ref) => ref.watch(fakeSession)),
    ],
  );

  Future<String> locationAfterRestore(
    WidgetTester tester,
    ProviderContainer container, {
    required String openAt,
  }) async {
    final router = container.read(routerProvider);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await settle(tester);

    // Người dùng mở app THẲNG vào đây (thông báo đẩy / tải lại trang), trong
    // khi phiên còn đang khôi phục.
    router.go(openAt);
    await settle(tester);

    container.read(fakeSession.notifier).state = const Session(
      status: SessionStatus.authenticated,
      policy: AccessPolicy({'tasks.read'}),
    );
    await settle(tester);

    return router.routerDelegate.currentConfiguration.uri.toString();
  }

  testWidgets('mở thẳng vào chi tiết thì tới CHI TIẾT, không rơi về màn chủ', (
    tester,
  ) async {
    final container = containerFor();
    addTearDown(container.dispose);

    final at = await locationAfterRestore(
      tester,
      container,
      openAt: '/tasks/t-123',
    );

    expect(at, '/tasks/t-123');
  });

  testWidgets('giữ cả tham số truy vấn, không chỉ đường dẫn', (tester) async {
    // Bộ lọc cũng là một phần của "chỗ tôi định tới".
    final container = containerFor();
    addTearDown(container.dispose);

    final at = await locationAfterRestore(
      tester,
      container,
      openAt: '/tasks?bucket=overdue',
    );

    expect(at, '/tasks?bucket=overdue');
  });

  testWidgets('không mở thẳng vào đâu thì về màn chủ như cũ', (tester) async {
    final container = containerFor();
    addTearDown(container.dispose);

    final router = container.read(routerProvider);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await settle(tester);

    container.read(fakeSession.notifier).state = const Session(
      status: SessionStatus.authenticated,
      policy: AccessPolicy({'tasks.read'}),
    );
    await settle(tester);

    expect(router.routerDelegate.currentConfiguration.uri.toString(), '/tasks');
  });

  testWidgets('hết phiên giữa chừng thì đăng nhập lại về ĐÚNG chỗ đang đọc', (
    tester,
  ) async {
    // Token hết hạn trong lúc thợ đang mở một công việc. Bắt họ tự tìm lại cây
    // đàn vừa xem là bắt làm lại một việc app đã biết câu trả lời.
    final container = containerFor();
    addTearDown(container.dispose);

    await locationAfterRestore(tester, container, openAt: '/tasks/t-123');

    container.read(fakeSession.notifier).state = const Session(
      status: SessionStatus.expired,
    );
    await settle(tester);
    container.read(fakeSession.notifier).state = const Session(
      status: SessionStatus.authenticated,
      policy: AccessPolicy({'tasks.read'}),
    );
    await settle(tester);

    final router = container.read(routerProvider);
    expect(
      router.routerDelegate.currentConfiguration.uri.toString(),
      '/tasks/t-123',
    );
  });
}

/// Một module tối giản: router thật, trang giả. Thứ đang kiểm là redirect, và
/// dựng cả appModules lên sẽ kéo theo mạng, ảnh, quyền — nhiễu chứ không thêm
/// gì cho câu hỏi này.
class _FakeModule extends OmniModule {
  const _FakeModule();

  @override
  String get id => 'tasks';

  @override
  String get title => 'Công việc';

  @override
  List<String> get permissions => const ['tasks.read'];

  @override
  List<ModuleRoute> routes() => [
    ModuleRoute(
      path: '/tasks',
      name: 'tasks.list',
      builder: (_, _) => const Scaffold(body: Text('danh sách')),
    ),
    ModuleRoute(
      path: '/tasks/:id',
      name: 'tasks.detail',
      rootNavigator: true,
      builder: (_, state) =>
          Scaffold(body: Text('chi tiết ${state.pathParameters['id']}')),
    ),
  ];

  @override
  List<ModuleNavEntry> navEntries() => [
    const ModuleNavEntry(
      moduleId: 'tasks',
      label: 'Việc của tôi',
      icon: Icons.checklist_outlined,
      selectedIcon: Icons.checklist_rounded,
      routeName: 'tasks.list',
      area: NavArea.work,
      weight: NavWeight.primary,
    ),
  ];
}
