// Bộ chụp màn hình THẬT để soát UI — không phải bài kiểm hồi quy.
//
// Bị BỎ QUA trong bộ kiểm thường (tag `screenshots`, xem dart_test.yaml): ảnh
// đổi mỗi khi UI đổi, và một pixel lệch không phải là một lỗi. Chạy tay khi
// muốn nhìn app bằng mắt:
//
//   flutter test test/_screenshots --run-skipped --update-goldens
//
// Ảnh ra: test/_screenshots/goldens/*.png (780×1688, tức 390×844 @2x) — thư
// mục này nằm trong .gitignore, mỗi người tự dựng.
//
// Nạp font Inter thật từ assets và MaterialIcons từ SDK, nếu không golden vẽ
// chữ bằng font Ahem (toàn ô vuông) và không đọc được gì về kiểu chữ. Dữ liệu
// mẫu chép từ tool/ui_preview.dart — cố ý có ca xấu: việc trễ, tên dài hai
// dòng, ảnh (trong test không có mạng nên ảnh hiện ô giữ chỗ "ảnh vỡ").
@Tags(['screenshots'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:omni_app/core/network/api_envelope.dart';
import 'package:omni_app/design/components/components.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/modules/auth/presentation/login_page.dart';
import 'package:omni_app/modules/notifications/application/notifications_providers.dart';
import 'package:omni_app/modules/notifications/data/notifications_api.dart';
import 'package:omni_app/modules/notifications/domain/app_notification.dart';
import 'package:omni_app/modules/notifications/presentation/notifications_page.dart';
import 'package:omni_app/modules/plans/application/plans_providers.dart';
import 'package:omni_app/modules/plans/domain/feed_entry.dart';
import 'package:omni_app/modules/plans/domain/plan.dart';
import 'package:omni_app/modules/plans/domain/team.dart';
import 'package:omni_app/modules/plans/domain/workshop_kpi.dart';
import 'package:omni_app/modules/plans/presentation/create_plan_page.dart';
import 'package:omni_app/modules/plans/presentation/create_team_page.dart';
import 'package:omni_app/modules/plans/presentation/plan_board_page.dart';
import 'package:omni_app/modules/plans/presentation/teams_page.dart';
import 'package:omni_app/modules/plans/presentation/timeline_page.dart';
import 'package:omni_app/modules/settings/presentation/widgets/account_menu_button.dart';
import 'package:omni_app/modules/tasks/application/task_controller.dart';
import 'package:omni_app/modules/tasks/application/tasks_providers.dart';
import 'package:omni_app/modules/tasks/data/tasks_api.dart';
import 'package:omni_app/modules/tasks/domain/task.dart';
import 'package:omni_app/modules/tasks/domain/task_permissions.dart';
import 'package:omni_app/modules/tasks/presentation/my_tasks_page.dart';
import 'package:omni_app/modules/tasks/presentation/task_detail_page.dart';
import 'package:omni_app/security/permissions/access_policy.dart';
import 'package:omni_app/security/session/session.dart';
import 'package:omni_app/security/session/session_controller.dart';

String _iso(Duration offset) => DateTime.now().add(offset).toIso8601String();

String _day(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

const _assigner = {'tasks.read', 'tasks.write', 'tasks.projects.manage.all'};

final _session = Session(
  status: SessionStatus.authenticated,
  user: const SessionUser(
    id: 'u-1',
    fullName: 'Hằng Ni',
    email: 'hangni@tnp.vn',
  ),
  tenant: const SessionTenant(id: 't-1', name: 'Xưởng piano TNP'),
);

final _tasks = <Map<String, dynamic>>[
  {
    'id': 't-1',
    'title': 'KAWAI HAT-5 · 2308512',
    'project_name': 'Phục chế tháng 9',
    'status': 'doing',
    'due_date': _iso(const Duration(days: -3)),
    'assignee_ids': ['u-1', 'u-2'],
    'assignee_names': ['Hằng Ni', 'Luận'],
    'description':
        'Khách yêu cầu giữ nguyên màu vecni gốc. Kiểm tra kỹ phần chốt trước '
        'khi lắp lại bộ máy.',
    'checklist': [
      {'id': 's-1', 'title': 'Tháo bộ máy', 'done': true, 'assignee_id': 'u-2', 'assignee_name': 'Luận'},
      {'id': 's-2', 'title': 'Vệ sinh khung sườn', 'done': true},
      {'id': 's-3', 'title': 'Nắp phím', 'done': false, 'assignee_id': 'u-1', 'assignee_name': 'Hằng Ni'},
      {'id': 's-4', 'title': 'Lên dây và cân chỉnh lực phím', 'done': false},
    ],
    'attachments': [
      {'id': 'a1', 'name': 'body-truoc.jpg', 'url': 'https://x/a.jpg', 'type': 'image', 'size': 128000},
      {'id': 'a2', 'name': 'bao-gia.pdf', 'url': 'https://x/b.pdf', 'type': 'file', 'size': 52000},
    ],
    'viewers': [
      {'user_id': 'Hằng Ni', 'viewed_at': _iso(const Duration(hours: -2))},
      {'user_id': 'Luận', 'viewed_at': _iso(const Duration(minutes: -20))},
    ],
  },
  {
    'id': 't-2',
    'title': 'YAMAHA U3 · 1874203 — thay dạ búa toàn bộ và cân lại bàn phím',
    'project_name': 'Phục chế tháng 9',
    'status': 'todo',
    'due_date': _iso(const Duration(hours: 5)),
    'assignee_names': ['Hằng Ni'],
    'checklist': [
      {'id': 's-5', 'title': 'Tháo dạ búa cũ', 'done': false},
      {'id': 's-6', 'title': 'Dán dạ mới', 'done': false},
    ],
  },
  {
    'id': 't-3',
    'title': 'Giao đàn cho khách — chị Trang, Q7',
    'project_name': 'Giao nhận',
    'status': 'todo',
    'assignee_names': ['Luận'],
    'checklist': <Map<String, dynamic>>[],
  },
  {
    'id': 't-4',
    'title': 'ROLAND FP-30 · kiểm tra bo mạch',
    'project_name': 'Bảo hành',
    'status': 'done',
    'due_date': _iso(const Duration(days: -1)),
    'assignee_names': ['Luận'],
    'checklist': [
      {'id': 's-7', 'title': 'Đo nguồn', 'done': true},
      {'id': 's-8', 'title': 'Thay tụ', 'done': true},
    ],
  },
];

final _notifications = <Map<String, dynamic>>[
  {'id': 'n-1', 'notification_type': 'TASK_ASSIGNED', 'title': 'Bạn có việc mới', 'content': '«KAWAI HAT-5 · 2308512» — hạn 3 ngày trước', 'related_entity_type': 'task', 'related_entity_id': 't-1', 'created_at': _iso(const Duration(minutes: -8))},
  {'id': 'n-2', 'notification_type': 'TASK_STAGE_OPEN', 'title': 'Công đoạn đang trống', 'content': 'Nắp phím đang trống — «KAWAI HAT-5 · 2308512»', 'related_entity_type': 'task', 'related_entity_id': 't-1', 'created_at': _iso(const Duration(hours: -1))},
  {'id': 'n-3', 'notification_type': 'TASK_PROGRESS', 'title': 'Tiến độ công việc', 'content': 'Body ngoài xong — «KAWAI HAT-5»', 'related_entity_type': 'task', 'related_entity_id': 't-1', 'created_at': _iso(const Duration(hours: -3))},
  {'id': 'n-4', 'notification_type': 'TASK_OVERDUE', 'title': 'Việc quá hạn', 'content': '«YAMAHA U3 · 1874203» đã quá hạn', 'related_entity_type': 'task', 'related_entity_id': 't-2', 'read_at': _iso(const Duration(hours: -20)), 'created_at': _iso(const Duration(days: -1))},
];

class _StubTasksApi implements TasksApi {
  @override
  Future<Paged<Task>> mine({required TaskBucket bucket, int page = 1, int perPage = 20}) async {
    final tasks = _tasks.map(Task.fromJson).toList();
    return Paged(
      items: switch (bucket) {
        TaskBucket.today => tasks.where((t) => t.isDueToday).toList(),
        TaskBucket.overdue => tasks.where((t) => t.isOverdue).toList(),
        TaskBucket.upcoming => tasks.where((t) => !t.isOverdue && !t.isDueToday && !t.isDone).toList(),
        TaskBucket.open => tasks.where((t) => !t.isDone).toList(),
        TaskBucket.all => tasks,
      },
      pagination: const ApiPagination(currentPage: 1, lastPage: 1, perPage: 20, total: 4),
    );
  }

  @override
  noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _StubNotificationsApi implements NotificationsApi {
  @override
  Future<Paged<AppNotification>> list({int page = 1, int perPage = 20, bool unreadOnly = false}) async => Paged(
    items: _notifications.map(AppNotification.fromJson).toList(),
    pagination: const ApiPagination(currentPage: 1, lastPage: 1, perPage: 20, total: 4),
  );

  @override
  noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _StubDetail extends TaskController {
  _StubDetail(this._state);
  final TaskDetailState _state;
  @override
  Future<TaskDetailState> build(String taskId) async => _state;
}

FeedEntry _feed({
  required String id,
  FeedKind kind = FeedKind.subtaskCompleted,
  String? detail = 'Body ngoài',
  String taskTitle = 'KAWAI HAT-5 · 2308512',
  String userName = 'Hằng Ni',
  List<String> photos = const [],
  int hoursAgo = 1,
  int daysAgo = 0,
}) => FeedEntry(
  id: id,
  kind: kind,
  taskId: 't-1',
  taskTitle: taskTitle,
  at: DateTime.now().subtract(Duration(hours: hoursAgo, days: daysAgo)),
  userName: userName,
  detail: detail,
  planName: 'Phục chế tháng 9',
  photos: photos,
  day: _day(DateTime.now().subtract(Duration(days: daysAgo))),
);

final _feedRows = [
  _feed(id: 'f1', photos: const ['https://x/1.jpg', 'https://x/2.jpg']),
  _feed(id: 'f2', detail: 'Lên dây', userName: 'Tuấn', hoursAgo: 2),
  _feed(id: 'f3', kind: FeedKind.pianoDone, detail: null, taskTitle: 'YAMAHA U3 · 4402881', hoursAgo: 3),
  _feed(id: 'f4', detail: 'Sơn lót', userName: 'Minh', taskTitle: 'KAWAI K-300 · 9911027', hoursAgo: 5),
  _feed(id: 'f5', detail: 'Vệ sinh khung', userName: 'Luận', hoursAgo: 3, daysAgo: 1),
  _feed(id: 'f6', detail: 'Tháo máy', userName: 'Luận', taskTitle: 'PETROF P125 · 7730115', hoursAgo: 6, daysAgo: 1),
];

const _kpiJson = {
  'delivered': 28,
  'reached_bonus': 0,
  'days_left': 20,
  'tiers': [{'count': 35, 'bonus': 5}],
  'counting_sections': ['s4'],
  'rework': 1,
  'next_tier': {'count': 35, 'bonus': 5, 'remaining': 7},
};

Plan _plan(String id, String name, {String? cover, int overdue = 0}) => Plan.fromJson({
  'id': id,
  'name': name,
  'team_id': 't1',
  'cover': ?cover,
  'sections': [
    {'id': 's1', 'name': 'Nhập xưởng', 'order': 0},
    {'id': 's2', 'name': 'Tháo máy', 'order': 1},
    {'id': 's3', 'name': 'Phục chế', 'order': 2},
    {'id': 's4', 'name': 'Hoàn thiện', 'order': 3, 'counts_for_kpi': true},
  ],
  'stats': {'total': 12, 'done': 5, 'overdue': overdue},
});

Future<void> _loadInter() async {
  final loader = FontLoader('Inter');
  for (final f in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
    final bytes = File('assets/fonts/Inter-$f.ttf').readAsBytesSync();
    loader.addFont(Future.value(ByteData.view(bytes.buffer)));
  }
  await loader.load();

  // Icon Material không được nạp trong môi trường test → mọi icon vẽ thành ô
  // vuông. Nạp thẳng từ SDK để ảnh chụp phản ánh đúng thứ người dùng thấy.
  final icons = File(
    'D:/_tools/flutter/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
  );
  if (icons.existsSync()) {
    final iconLoader = FontLoader('MaterialIcons');
    final bytes = icons.readAsBytesSync();
    iconLoader.addFont(Future.value(ByteData.view(bytes.buffer)));
    await iconLoader.load();
  }
}

void main() {
  setUpAll(() async {
    await _loadInter();
    await initializeDateFormatting('vi_VN');
  });

  Widget app(Widget home, {bool dark = false, Set<String> perms = _assigner, List<Override> extra = const []}) {
    return ProviderScope(
      overrides: [
        sessionProvider.overrideWithValue(_session),
        taskAccessProvider.overrideWithValue(TaskAccess.of(AccessPolicy(perms))),
        accessProvider.overrideWithValue(AccessPolicy(perms)),
        tasksApiProvider.overrideWithValue(_StubTasksApi()),
        notificationsApiProvider.overrideWithValue(_StubNotificationsApi()),
        notificationRealtimeProvider.overrideWithValue(null),
        workshopFeedProvider.overrideWith((ref) async => (entries: _feedRows, truncated: false)),
        workshopKpiProvider.overrideWith((ref) async => WorkshopKpi.fromJson(_kpiJson)),
        kpiPreviousDeliveredProvider.overrideWith((ref) async => 22),
        teamsWithPlansProvider.overrideWith((ref) async => [
          TeamWithPlans(
            team: const Team(id: 't1', name: 'Tổ phục chế', memberIds: ['u1', 'u2', 'u3']),
            plans: [
              _plan('p1', 'Phục chế tháng 9', cover: 'teal-1', overdue: 3),
              _plan('p2', 'Đàn điện — bảo hành', cover: 'amber-2'),
            ],
          ),
          const TeamWithPlans(team: Team(id: 't2', name: 'Tổ giao nhận', memberIds: ['u4']), plans: []),
        ]),
        ...extra,
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: OmniTheme.light(TargetPlatform.android),
        darkTheme: OmniTheme.dark(TargetPlatform.android),
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        locale: const Locale('vi'),
        home: OmniAccountSlot(builder: (_) => const AccountMenuButton(), child: home),
      ),
    );
  }

  /// [scrollTo]: cuộn cho tới khi widget này lên SÁT MÉP TRÊN rồi mới chụp —
  /// cho phần nằm dưới nếp gấp của một màn dài (trao đổi, nhật ký).
  Future<void> shoot(WidgetTester tester, Widget w, String name, {Finder? scrollTo}) async {
    tester.view.physicalSize = const Size(780, 1688);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(w);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    if (scrollTo != null) {
      await tester.scrollUntilVisible(scrollTo, 200, scrollable: find.byType(Scrollable).first);
      await Scrollable.ensureVisible(tester.element(scrollTo), alignment: 0);
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
    }
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/$name.png'));
  }

  testWidgets('01 dong viec', (t) => shoot(t, app(const TimelinePage()), '01-dong-viec'));
  testWidgets('01b dong viec dark', (t) => shoot(t, app(const TimelinePage(), dark: true), '01b-dong-viec-dark'));
  testWidgets('01c dong viec tho', (t) => shoot(t, app(const TimelinePage(), perms: {'tasks.read', 'tasks.write'}), '01c-dong-viec-tho'));
  testWidgets('02 viec cua toi', (t) => shoot(t, app(const MyTasksPage()), '02-viec-cua-toi'));
  testWidgets('03 chi tiet viec', (t) => shoot(
    t,
    app(const TaskDetailPage(taskId: 't-1'), extra: [
      taskDetailProvider.overrideWith(() => _StubDetail(TaskDetailState(task: Task.fromJson(_tasks[0])))),
    ]),
    '03-chi-tiet-viec',
  ));
  testWidgets('03b chi tiet viec - trao doi', (t) => shoot(
    t,
    app(const TaskDetailPage(taskId: 't-1'), extra: [
      taskDetailProvider.overrideWith(() => _StubDetail(TaskDetailState(task: Task.fromJson({
        ..._tasks[0],
        'comments_count': 5,
        'comments': [
          {
            'id': 'c-1',
            'body': 'QC không đạt: mặt búa số 32–40 chưa đều, còn vệt keo ở cụm giữa. Kéo về Đang phục chế, nhờ Luận xem lại.',
            'user_name': 'Nguyễn Thị Hằng Ni',
            'mentioned_user_names': ['Luận'],
            'created_at': _iso(const Duration(hours: -3)),
          },
          {
            'id': 'c-2',
            'body': 'Đã nhận, chiều làm lại.',
            'user_name': 'Luận',
            'created_at': _iso(const Duration(minutes: -40)),
          },
          {
            'id': 'c-3',
            'body': 'Ảnh sau khi sửa đã gửi.',
            'user_name': 'Luận',
            'created_at': _iso(const Duration(minutes: -5)),
          },
        ],
      })))),
    ]),
    '03b-chi-tiet-viec-trao-doi',
    scrollTo: find.text('Trao đổi'),
  ));
  testWidgets('04 team du an', (t) => shoot(t, app(const TeamsPage()), '04-team-du-an'));
  testWidgets('05 bang du an', (t) => shoot(
    t,
    app(const PlanBoardPage(planId: 'p1'), extra: [
      planProvider('p1').overrideWith((ref) async => _plan('p1', 'Phục chế tháng 9', cover: 'teal-1')),
      planTasksProvider('p1').overrideWith((ref) async => (
        tasks: [
          Task.fromJson({..._tasks[0], 'section_id': 's1'}),
          Task.fromJson({..._tasks[1], 'section_id': 's1'}),
          Task.fromJson({..._tasks[3], 'section_id': 's1'}),
        ],
        truncated: false,
      )),
    ]),
    '05-bang-du-an',
  ));
  testWidgets('06 tao du an', (t) => shoot(t, app(const CreatePlanPage(teamId: 't1')), '06-tao-du-an'));
  testWidgets('07 tao team', (t) => shoot(t, app(const CreateTeamPage()), '07-tao-team'));
  testWidgets('08 thong bao', (t) => shoot(t, app(const NotificationsPage()), '08-thong-bao'));
  testWidgets('09 dang nhap', (t) => shoot(t, app(const LoginPage()), '09-dang-nhap'));
}
