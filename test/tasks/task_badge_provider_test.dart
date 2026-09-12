import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/core/config/app_config.dart';
import 'package:omni_app/core/network/api_envelope.dart';
import 'package:omni_app/modules/tasks/application/tasks_providers.dart';
import 'package:omni_app/modules/tasks/data/tasks_api.dart';
import 'package:omni_app/modules/tasks/domain/task.dart';
import 'package:omni_app/security/session/session.dart';
import 'package:omni_app/security/session/session_controller.dart';

/// Badge trên tab "Việc của tôi" đếm ở SERVER, không đếm trên danh sách.
///
/// Trước đây `taskBadgeProvider` đọc `myTasksProvider`: con số là số việc trễ
/// trên TRANG ĐẦU của RỔ ĐANG XEM. Đứng ở "Sắp tới" thì badge là 0 dù có ba
/// việc trễ; và vì thanh tab luôn theo dõi badge, `myTasksProvider` — khai là
/// autoDispose — không bao giờ được dọn, kéo theo mỗi tín hiệu realtime là
/// một lượt tải lại danh sách cho một tab có thể đang không mở.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _CountingTasksApi api;
  late ProviderContainer container;

  ProviderContainer make({String? userId = 'u1'}) => ProviderContainer(
    overrides: [
      tasksApiProvider.overrideWithValue(api),
      sessionProvider.overrideWithValue(
        userId == null
            ? const Session.unauthenticated()
            : Session(
                status: SessionStatus.authenticated,
                user: SessionUser(id: userId, fullName: 'Hằng Ni', email: ''),
              ),
      ),
    ],
  );

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  setUp(() {
    api = _CountingTasksApi();
    container = make();
  });

  tearDown(() => container.dispose());

  Future<int> openTab() async {
    // Thanh tab theo dõi badge suốt phiên; ở đây là người nghe đó.
    container.listen(taskBadgeProvider, (_, _) {});
    await container.read(taskOverdueCountProvider.future);

    return container.read(taskBadgeProvider);
  }

  test('con số là số việc trễ server đếm cho ĐÚNG người này', () async {
    api.overdue = 3;

    expect(await openTab(), 3);
    expect(api.overdueFor, ['u1']);
    expect(
      api.mineCalls,
      0,
      reason:
          'Badge không được kéo theo danh sách: đó là lý do myTasksProvider '
          'khai autoDispose mà không bao giờ được dọn.',
    );
  });

  test('đổi rổ đang xem thì badge không đổi, không gọi lại', () async {
    api.overdue = 3;
    await openTab();

    container.read(taskBucketProvider.notifier).state = TaskBucket.upcoming;
    await settle();

    expect(container.read(taskBadgeProvider), 3);
    expect(api.overdueCalls, 1);
    expect(api.mineCalls, 0);
  });

  test('tín hiệu realtime thì đếm lại', () async {
    api.overdue = 3;
    await openTab();

    api.overdue = 2;
    container.read(taskRealtimeSignalProvider.notifier).bump();
    await container.read(taskOverdueCountProvider.future);

    expect(container.read(taskBadgeProvider), 2);
    expect(api.overdueCalls, 2);
  });

  test('chưa đăng nhập thì 0 và không hỏi server', () async {
    container.dispose();
    container = make(userId: null);

    expect(await openTab(), 0);
    expect(api.overdueCalls, 0);
  });
}

class _CountingTasksApi implements TasksApi {
  int overdue = 0;
  int overdueCalls = 0;
  int mineCalls = 0;
  final List<String> overdueFor = [];

  @override
  Future<int> overdueCount(String userId) async {
    overdueCalls++;
    overdueFor.add(userId);

    return overdue;
  }

  @override
  Future<Paged<Task>> mine({
    required TaskBucket bucket,
    int page = 1,
    int perPage = AppConfig.defaultPerPage,
  }) async {
    mineCalls++;

    return const Paged.empty();
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
