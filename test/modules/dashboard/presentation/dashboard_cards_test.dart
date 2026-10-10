import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:omni_app/core/domain/channel.dart';
import 'package:omni_app/core/error/app_exception.dart';
import 'package:omni_app/core/network/api_envelope.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/modules/dashboard/application/dashboard_providers.dart';
import 'package:omni_app/modules/dashboard/presentation/widgets/awaiting_reply_card.dart';
import 'package:omni_app/modules/dashboard/presentation/widgets/my_tasks_card.dart';
import 'package:omni_app/modules/inbox/application/inbox_providers.dart';
import 'package:omni_app/modules/inbox/domain/conversation.dart';
import 'package:omni_app/modules/inbox/domain/inbox_filter.dart';
import 'package:omni_app/modules/inbox/inbox_routes.dart';
import 'package:omni_app/modules/inbox/presentation/widgets/conversation_row.dart';
import 'package:omni_app/modules/tasks/domain/task.dart';
import 'package:omni_app/modules/tasks/routes.dart';
import 'package:omni_app/security/permissions/access_policy.dart';
import 'package:omni_app/security/session/session_controller.dart';

String ymd(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

Task task(int i, {int daysAgo = 0}) => Task.fromJson({
  'id': 't$i',
  'title': 'Việc số $i',
  'status': 'todo',
  'due_date': ymd(DateTime.now().subtract(Duration(days: daysAgo))),
});

Conversation conv(int i) => Conversation(
  id: 'c$i',
  channel: Channel.zalo,
  status: ConversationStatus.open,
  customerName: 'Khách $i',
  lastMessage: 'Tin $i',
  unread: 1,
);

Paged<Task> tasks(int n, {int total = 0}) => Paged(
  items: [for (var i = 0; i < n; i++) task(i, daysAgo: i == 0 ? 3 : 0)],
  pagination: ApiPagination(
    currentPage: 1,
    lastPage: 1,
    perPage: 5,
    total: total,
  ),
);

class Harness {
  final visited = <String>[];
  late ProviderContainer container;
}

Future<Harness> pump(
  WidgetTester t,
  Widget card, {
  Set<String> perms = const {'tasks.read', 'inbox.read'},
  Future<Paged<Task>> Function(Ref)? myTasks,
  Future<CursorPaged<Conversation>> Function(Ref)? awaiting,
}) async {
  final h = Harness();
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => Scaffold(
          body: SingleChildScrollView(child: SizedBox(width: 380, child: card)),
        ),
      ),
      GoRoute(
        path: '/tasks',
        name: TaskRoutes.list,
        builder: (_, s) {
          h.visited.add(s.uri.toString());
          return const Text('TRANG VIỆC');
        },
      ),
      GoRoute(
        path: '/tasks/:id',
        name: TaskRoutes.detail,
        builder: (_, s) {
          h.visited.add(s.uri.toString());
          return const Text('CHI TIẾT');
        },
      ),
      GoRoute(
        path: InboxRoutes.listPath,
        name: InboxRoutes.list,
        builder: (_, s) {
          h.visited.add(s.uri.toString());
          return const Text('HỘP THƯ');
        },
      ),
      GoRoute(
        path: InboxRoutes.threadPath,
        name: InboxRoutes.thread,
        builder: (_, s) {
          h.visited.add(s.uri.toString());
          return const Text('LUỒNG');
        },
      ),
    ],
  );
  await t.pumpWidget(
    ProviderScope(
      overrides: [
        accessProvider.overrideWithValue(AccessPolicy(perms)),
        dashboardMyTasksProvider.overrideWith(myTasks ?? (_) async => tasks(0)),
        dashboardAwaitingReplyProvider.overrideWith(
          awaiting ?? (_) async => const CursorPaged.empty(),
        ),
      ],
      child: MaterialApp.router(
        theme: OmniTheme.light(),
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(size: const Size(800, 1200), disableAnimations: true),
          child: child!,
        ),
      ),
    ),
  );
  await t.pumpAndSettle();
  h.container = ProviderScope.containerOf(
    t.element(find.byType(Scaffold).first),
  );
  return h;
}

void main() {
  setUpAll(() => initializeDateFormatting('vi_VN'));

  group('MyTasksCard', () {
    testWidgets('≤5 việc, chip hạn, số = pagination.total', (t) async {
      await pump(
        t,
        const MyTasksCard(),
        myTasks: (_) async => tasks(6, total: 12),
      );
      expect(find.text('Việc của tôi'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
      expect(find.textContaining('Việc số '), findsNWidgets(5));
      expect(find.text('Quá hạn 3 ngày'), findsOneWidget);
      expect(find.text('Hạn hôm nay'), findsNWidgets(4));
    });

    testWidgets('bấm dòng → /tasks/:id', (t) async {
      final h = await pump(
        t,
        const MyTasksCard(),
        myTasks: (_) async => tasks(2, total: 2),
      );
      await t.tap(find.text('Việc số 1'));
      await t.pumpAndSettle();
      expect(h.visited.last, '/tasks/t1');
    });

    testWidgets('Xem tất cả → danh sách việc', (t) async {
      final h = await pump(
        t,
        const MyTasksCard(),
        myTasks: (_) async => tasks(2, total: 2),
      );
      await t.tap(find.text('Xem tất cả'));
      await t.pumpAndSettle();
      expect(h.visited.last, '/tasks');
    });

    testWidgets('rỗng → Không có việc hôm nay', (t) async {
      await pump(t, const MyTasksCard());
      expect(find.text('Không có việc hôm nay'), findsOneWidget);
    });

    testWidgets('thiếu tasks.read → ẩn hẳn, không gọi provider', (t) async {
      var called = false;
      await pump(
        t,
        const MyTasksCard(),
        perms: {'inbox.read'},
        myTasks: (_) async {
          called = true;
          return tasks(1);
        },
      );
      expect(find.text('Việc của tôi'), findsNothing);
      expect(find.text('Thử lại'), findsNothing);
      expect(called, isFalse);
    });

    testWidgets('lỗi → Thử lại trong thẻ, thẻ kia vẫn hiện', (t) async {
      var calls = 0;
      await pump(
        t,
        const Column(children: [MyTasksCard(), AwaitingReplyCard()]),
        myTasks: (_) async {
          calls++;
          throw const ServerException('Lỗi máy chủ', code: '500');
        },
        awaiting: (_) async => CursorPaged(items: [conv(1)]),
      );
      expect(find.text('Thử lại'), findsOneWidget);
      expect(find.text('Khách 1'), findsOneWidget);
      await t.tap(find.text('Thử lại'));
      await t.pumpAndSettle();
      expect(calls, 2);
    });
  });

  group('AwaitingReplyCard', () {
    testWidgets('≤5 ConversationRow; bấm → luồng', (t) async {
      final h = await pump(
        t,
        const AwaitingReplyCard(),
        awaiting: (_) async =>
            CursorPaged(items: [for (var i = 0; i < 7; i++) conv(i)]),
      );
      expect(find.text('Chờ phản hồi'), findsOneWidget);
      expect(find.byType(ConversationRow), findsNWidgets(5));
      await t.tap(find.text('Khách 2'));
      await t.pumpAndSettle();
      expect(h.visited.last, '/inbox/c2');
    });

    testWidgets('Xem tất cả → hộp thư với lọc Chưa đọc', (t) async {
      final h = await pump(
        t,
        const AwaitingReplyCard(),
        awaiting: (_) async => CursorPaged(items: [conv(1)]),
      );
      await t.tap(find.text('Xem tất cả'));
      await t.pumpAndSettle();
      expect(h.visited.last, '/inbox');
      expect(
        h.container.read(inboxFilterProvider).quick,
        InboxQuickFilter.unread,
      );
    });

    testWidgets('rỗng → Đã trả lời hết', (t) async {
      await pump(t, const AwaitingReplyCard());
      expect(find.text('Đã trả lời hết'), findsOneWidget);
    });

    testWidgets('thiếu quyền hộp thư → ẩn hẳn', (t) async {
      var called = false;
      await pump(
        t,
        const AwaitingReplyCard(),
        perms: {'tasks.read'},
        awaiting: (_) async {
          called = true;
          return const CursorPaged.empty();
        },
      );
      expect(find.text('Chờ phản hồi'), findsNothing);
      expect(called, isFalse);
    });

    testWidgets('chỉ inbox.read.own vẫn thấy thẻ', (t) async {
      await pump(t, const AwaitingReplyCard(), perms: {'inbox.read.own'});
      expect(find.text('Chờ phản hồi'), findsOneWidget);
    });
  });
}
