import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:omni_app/core/config/app_config.dart';
import 'package:omni_app/core/network/api_envelope.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/modules/tasks/application/task_comments_controller.dart';
import 'package:omni_app/modules/tasks/application/task_controller.dart';
import 'package:omni_app/modules/tasks/data/tasks_api.dart';
import 'package:omni_app/modules/tasks/domain/task.dart';
import 'package:omni_app/modules/tasks/presentation/widgets/comment_section.dart';

/// Bình luận cũ đọc được NGAY TRONG APP.
///
/// Phản hồi chi tiết chỉ mang phần mới nhất và app từng viết "Còn 11 bình luận
/// cũ hơn, xem trên web." — ở xưởng thì không ai mở web, và lý do một cây đàn
/// bị trả về ba tuần trước nằm đúng trong phần bị cắt. Giờ có
/// `GET /tasks/{id}/comments?page&per_page` (mới nhất trước), và một nút.
///
/// Hạt giống là bình luận đi kèm phản hồi chi tiết — đã có trong tay, không
/// tốn lượt gọi nào khi mở việc. Endpoint chỉ được hỏi khi người ta bấm.
void main() {
  // `Formatters.relative` dùng DateFormat('vi_VN'); test không đi qua bootstrap.
  setUpAll(() => initializeDateFormatting('vi_VN'));

  /// 25 bình luận, c25 mới nhất. API trả mới nhất trước.
  List<TaskComment> all() => [
    for (var i = 25; i >= 1; i--)
      TaskComment(
        id: 'c$i',
        body: 'Bình luận $i',
        userName: 'Hằng Ni',
        createdAt: DateTime(2026, 9, 1).add(Duration(minutes: i)),
      ),
  ];

  /// Công việc như phản hồi chi tiết: [seedCount] bình luận MỚI NHẤT, cũ nhất
  /// trước; `comments_count` là tổng thật.
  Task seeded(int seedCount) => Task(
    id: 't1',
    title: 'SCHWESTER No.53',
    comments: all().take(seedCount).toList().reversed.toList(),
    commentCount: 25,
  );

  group('controller', () {
    late _PagedApi api;
    late _StubDetail detail;
    late ProviderContainer container;

    ProviderContainer make(Task task) {
      api = _PagedApi(all());
      detail = _StubDetail(task);
      container = ProviderContainer(
        overrides: [
          tasksApiProvider.overrideWithValue(api),
          taskDetailProvider.overrideWith(() => detail),
        ],
      );
      addTearDown(container.dispose);

      return container;
    }

    Future<CommentsState> open(ProviderContainer c) async {
      c.listen(taskCommentsProvider('t1'), (_, _) {});
      c.listen(taskDetailProvider('t1'), (_, _) {});
      await c.read(taskDetailProvider('t1').future);

      return c.read(taskCommentsProvider('t1').future);
    }

    List<String> ids(CommentsState s) => [for (final c in s.items) c.id];

    test('hạt giống từ phản hồi chi tiết, không gọi mạng', () async {
      final s = await open(make(seeded(20)));

      expect(s.items, hasLength(20));
      expect(ids(s).first, 'c25', reason: 'mới nhất trước');
      expect(s.total, 25);
      expect(s.hiddenCount, 5);
      expect(s.hasMore, isTrue);
      expect(api.calls, isEmpty);
    });

    test('xem thêm: trang kế tiếp theo số đã có, nối vào đuôi', () async {
      final c = make(seeded(20));
      await open(c);

      await c.read(taskCommentsProvider('t1').notifier).loadOlder();
      final s = c.read(taskCommentsProvider('t1')).requireValue;

      expect(api.calls, [(page: 2, perPage: 20)]);
      expect(s.items, hasLength(25));
      expect(ids(s).last, 'c1');
      expect(s.hasMore, isFalse);
      expect(s.hiddenCount, 0);
    });

    test(
      'hạt giống lẻ (10): bỏ qua phần đã có trong trang 1, rồi trang 2',
      () async {
        // Server có thể cắt phản hồi chi tiết ở một cỡ khác cỡ trang. Không
        // được giả định hai con số ấy bằng nhau.
        final c = make(seeded(10));
        await open(c);
        final notifier = c.read(taskCommentsProvider('t1').notifier);

        await notifier.loadOlder();
        expect(
          c.read(taskCommentsProvider('t1')).requireValue.items,
          hasLength(20),
        );

        await notifier.loadOlder();
        final s = c.read(taskCommentsProvider('t1')).requireValue;

        expect(api.calls, [(page: 1, perPage: 20), (page: 2, perPage: 20)]);
        expect(ids(s), [for (var i = 25; i >= 1; i--) 'c$i']);
        expect(s.hasMore, isFalse);
      },
    );

    test(
      'bình luận mới gửi lên đầu, tổng +1, trang cũ đã tải vẫn còn',
      () async {
        final c = make(seeded(20));
        await open(c);
        await c.read(taskCommentsProvider('t1').notifier).loadOlder();

        await detail.comment('Chưa đạt phần đồng.');
        final s = c.read(taskCommentsProvider('t1')).requireValue;

        expect(s.items.first.body, 'Chưa đạt phần đồng.');
        expect(s.items, hasLength(26));
        expect(s.total, 26);
        expect(s.hasMore, isFalse);
      },
    );

    test(
      'trang kế tiếp hỏng thì giữ những gì đang có, còn bấm lại được',
      () async {
        final c = make(seeded(20));
        await open(c);
        api.fail = true;

        // Ném ra để màn hiện snackbar — không im lặng — nhưng KHÔNG mất gì.
        await expectLater(
          c.read(taskCommentsProvider('t1').notifier).loadOlder(),
          throwsException,
        );
        final s = c.read(taskCommentsProvider('t1')).requireValue;

        expect(s.items, hasLength(20));
        expect(s.hasMore, isTrue);
        expect(s.loadingOlder, isFalse);
      },
    );
  });

  group('màn hình', () {
    late _PagedApi api;
    late _StubDetail detail;

    Widget host(Task task) {
      api = _PagedApi(all());
      detail = _StubDetail(task);

      return ProviderScope(
        overrides: [
          tasksApiProvider.overrideWithValue(api),
          taskDetailProvider.overrideWith(() => detail),
        ],
        child: MaterialApp(
          theme: OmniTheme.light(TargetPlatform.android),
          home: Scaffold(
            body: SingleChildScrollView(
              child: CommentSection(task: task, taskId: 't1', canWrite: true),
            ),
          ),
        ),
      );
    }

    testWidgets('20 dòng, nút "Xem thêm 5"; bấm → 25, nút ẩn', (tester) async {
      await tester.pumpWidget(host(seeded(20)));
      await tester.pumpAndSettle();

      expect(find.textContaining('Bình luận '), findsNWidgets(20));
      expect(find.text('Xem thêm 5 bình luận cũ hơn'), findsOneWidget);
      expect(find.textContaining('xem trên web'), findsNothing);

      await tester.tap(find.text('Xem thêm 5 bình luận cũ hơn'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Bình luận '), findsNWidgets(25));
      expect(find.textContaining('Xem thêm'), findsNothing);
    });

    testWidgets('cũ nhất ở trên, mới nhất ở dưới — như một cuộc trò chuyện', (
      tester,
    ) async {
      await tester.pumpWidget(host(seeded(20)));
      await tester.pumpAndSettle();

      final top = tester.getTopLeft(find.text('Bình luận 6')).dy;
      final bottom = tester.getTopLeft(find.text('Bình luận 25')).dy;
      expect(top, lessThan(bottom));
    });

    testWidgets('gửi xong thì dòng mới hiện ngay ở cuối', (tester) async {
      await tester.pumpWidget(host(seeded(20)));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Chưa đạt phần đồng.');
      await tester.tap(find.byTooltip('Gửi'));
      await tester.pumpAndSettle();

      expect(find.text('Chưa đạt phần đồng.'), findsOneWidget);
      final newest = tester.getTopLeft(find.text('Chưa đạt phần đồng.')).dy;
      final previous = tester.getTopLeft(find.text('Bình luận 25')).dy;
      expect(newest, greaterThan(previous));
    });
  });
}

/// Phân trang trên một danh sách cố định, mới nhất trước.
class _PagedApi implements TasksApi {
  _PagedApi(this.rows);

  final List<TaskComment> rows;
  final List<({int page, int perPage})> calls = [];
  bool fail = false;

  @override
  Future<Paged<TaskComment>> comments(
    String taskId, {
    int page = 1,
    int perPage = AppConfig.defaultPerPage,
  }) async {
    calls.add((page: page, perPage: perPage));
    if (fail) throw Exception('offline');

    final start = (page - 1) * perPage;
    final items = start >= rows.length
        ? const <TaskComment>[]
        : rows.sublist(start, (start + perPage).clamp(0, rows.length));

    return Paged(
      items: items,
      pagination: ApiPagination(
        currentPage: page,
        perPage: perPage,
        total: rows.length,
        lastPage: (rows.length + perPage - 1) ~/ perPage,
      ),
    );
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Giữ một công việc; gửi bình luận là nối nó vào đuôi như server làm.
class _StubDetail extends TaskController {
  _StubDetail(this._task);

  Task _task;

  @override
  Future<TaskDetailState> build(String arg) async =>
      TaskDetailState(task: _task);

  @override
  Future<void> comment(
    String body, {
    List<String> mentionedUserIds = const [],
  }) async {
    _task = Task(
      id: _task.id,
      title: _task.title,
      comments: [
        ..._task.comments,
        TaskComment(
          id: 'new',
          body: body,
          userName: 'Tôi',
          createdAt: DateTime(2026, 9, 2),
        ),
      ],
      commentCount: _task.commentCount + 1,
    );
    state = AsyncData(TaskDetailState(task: _task));
  }
}
