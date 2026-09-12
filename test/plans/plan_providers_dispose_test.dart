import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/core/network/api_envelope.dart';
import 'package:omni_app/modules/plans/application/plans_providers.dart';
import 'package:omni_app/modules/plans/data/plans_api.dart';
import 'package:omni_app/modules/plans/domain/feed_entry.dart';
import 'package:omni_app/modules/plans/domain/workshop_kpi.dart';
import 'package:omni_app/modules/tasks/application/tasks_providers.dart';
import 'package:omni_app/modules/tasks/domain/task.dart';
import 'package:omni_app/security/session/session.dart';
import 'package:omni_app/security/session/session_controller.dart';

/// Bảng dự án, thẻ KPI và dòng việc phải TỰ GIẢI PHÓNG sau khi rời màn.
///
/// Ba provider này theo dõi tín hiệu realtime — đúng, vì đang mở bảng thì phải
/// thấy người khác chuyển công đoạn. Nhưng chúng KHÔNG autoDispose, nên sau khi
/// quản đốc đóng bảng, mỗi tick ở xưởng vẫn kéo theo một lượt tải lại toàn bộ
/// việc của dự án đó — cho một màn hình không ai còn nhìn. Mở mười bảng trong
/// ngày là mười lượt tải lại cho mỗi sự kiện.
///
/// Không autoDispose "trần": quản đốc mở một cây đàn ra xem rồi quay lại bảng
/// trong vài giây, và bảng phải còn nguyên chứ không tải lại từ đầu. Nên là
/// một quãng ân hạn [kBoardKeepAlive] rồi mới dọn.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final cases =
      <
        ({
          String name,
          AutoDisposeFutureProvider<Object?> provider,
          int Function(_CountingPlansApi api) calls,
        })
      >[
        (
          name: 'bảng dự án',
          provider: planTasksProvider('p1'),
          calls: (api) => api.tasksCalls,
        ),
        (
          name: 'thẻ KPI',
          provider: workshopKpiProvider,
          calls: (api) => api.kpiCalls,
        ),
        (
          name: 'dòng việc',
          provider: workshopFeedProvider,
          calls: (api) => api.feedCalls,
        ),
      ];

  ({ProviderContainer container, _CountingPlansApi api}) harness() {
    final api = _CountingPlansApi();
    final container = ProviderContainer(
      overrides: [
        plansApiProvider.overrideWithValue(api),
        // Không tenant → tín hiệu realtime không mở kênh; bài này tự bấm nó.
        sessionProvider.overrideWithValue(const Session.unauthenticated()),
      ],
    );

    return (container: container, api: api);
  }

  void bump(ProviderContainer container) =>
      container.read(taskRealtimeSignalProvider.notifier).bump();

  for (final c in cases) {
    group(c.name, () {
      testWidgets('rời màn đủ lâu thì realtime KHÔNG kéo theo lượt tải lại', (
        tester,
      ) async {
        final h = harness();

        final sub = h.container.listen(c.provider, (_, _) {});
        await h.container.read(c.provider.future);
        expect(c.calls(h.api), 1);

        // Màn hình đóng lại.
        sub.close();
        await tester.pump(kBoardKeepAlive);
        await tester.pump(Duration.zero);

        expect(
          h.container.exists(c.provider),
          isFalse,
          reason: 'Hết quãng ân hạn mà provider vẫn còn thì nó sống cả phiên.',
        );

        // Ai đó tick một việc ở xưởng.
        bump(h.container);
        await tester.pump(Duration.zero);

        expect(
          c.calls(h.api),
          1,
          reason:
              'Không ai còn nhìn màn này. Tải lại là trả tiền mạng cho một '
              'màn hình đã đóng — và với bảng, đó là TẤT CẢ việc của dự án.',
        );

        h.container.dispose();
      });

      testWidgets('quay lại trong quãng ân hạn thì không tải lại', (
        tester,
      ) async {
        final h = harness();

        final first = h.container.listen(c.provider, (_, _) {});
        await h.container.read(c.provider.future);
        first.close();

        // Mở một cây đàn ra xem rồi quay lại.
        await tester.pump(const Duration(seconds: 30));
        final second = h.container.listen(c.provider, (_, _) {});
        await h.container.read(c.provider.future);

        expect(
          c.calls(h.api),
          1,
          reason:
              'autoDispose trần sẽ dọn ngay khi rời màn, và bảng tải lại từ '
              'đầu mỗi lần quản đốc mở một cây đàn ra xem.',
        );

        second.close();
        h.container.dispose();
      });

      testWidgets('đang mở thì realtime vẫn tải lại, kể cả sau quãng ân hạn', (
        tester,
      ) async {
        final h = harness();

        final sub = h.container.listen(c.provider, (_, _) {});
        await h.container.read(c.provider.future);

        // Quãng ân hạn là "sau khi rời màn", không phải tuổi thọ của dữ liệu.
        await tester.pump(kBoardKeepAlive * 2);

        bump(h.container);
        await tester.pump(Duration.zero);
        await h.container.read(c.provider.future);

        expect(c.calls(h.api), 2);

        sub.close();
        h.container.dispose();
      });
    });
  }
}

/// Đếm số lần mỗi màn hỏi lại server. Phần còn lại của PlansApi để
/// noSuchMethod lo, như `_CountingPlansApi` trong timeline_realtime_test.
class _CountingPlansApi implements PlansApi {
  int tasksCalls = 0;
  int kpiCalls = 0;
  int feedCalls = 0;

  @override
  Future<Paged<Task>> tasksInPlan(
    String planId, {
    int page = 1,
    int perPage = 30,
  }) async {
    tasksCalls++;

    return const Paged.empty();
  }

  @override
  Future<WorkshopKpi> kpi({String? planId, DateTime? month}) async {
    kpiCalls++;

    return const WorkshopKpi(
      delivered: 0,
      reachedBonus: 0,
      daysLeft: 0,
      tiers: [],
      isConfigured: false,
      rework: 0,
      nextTier: null,
    );
  }

  @override
  Future<WorkshopFeed> feed({
    List<String> types = const [],
    int days = 7,
    int limit = 30,
  }) async {
    feedCalls++;

    return (entries: const <FeedEntry>[], truncated: false);
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
