import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/core/network/api_client.dart';
import 'package:omni_app/demo/demo_app.dart';
import 'package:omni_app/demo/demo_backend.dart';
import 'package:omni_app/demo/demo_seed.dart';
import 'package:omni_app/modules/plans/data/plans_api.dart';
import 'package:omni_app/modules/plans/domain/plan.dart';
import 'package:omni_app/modules/tasks/data/tasks_api.dart';
import 'package:omni_app/modules/tasks/domain/task_copy_request.dart';
import 'package:omni_app/modules/team/data/team_api.dart';

/// Máy chủ demo phần công việc / kế hoạch / đội nhóm: mọi lượt đọc mà màn
/// hình dùng phải parse ra dữ liệu thật (không rỗng), và lượt ghi phải hiện
/// lại ở lượt đọc sau — đi qua ĐÚNG các lớp API của app, không dựng JSON tay.
void main() {
  late TasksApi tasks;
  late PlansApi plans;
  late TeamApi team;

  setUp(() {
    final dio = Dio(BaseOptions(baseUrl: 'http://demo.local'))
      ..httpClientAdapter = DemoApiAdapter(
        buildDemoRoutes(),
        latency: Duration.zero,
      );
    final client = ApiClient(dio);
    tasks = TasksApi(client);
    plans = PlansApi(client);
    team = TeamApi(client);
  });

  group('đọc', () {
    test('Việc của tôi: bốn nhóm đều có việc, đúng nhóm', () async {
      final today = await tasks.mine(bucket: TaskBucket.today);
      final overdue = await tasks.mine(bucket: TaskBucket.overdue);
      final upcoming = await tasks.mine(bucket: TaskBucket.upcoming);
      final all = await tasks.mine(bucket: TaskBucket.all);

      expect(today.items, isNotEmpty);
      expect(today.items.every((t) => t.isDueToday), isTrue);
      expect(overdue.items, isNotEmpty);
      expect(overdue.items.every((t) => t.isOverdue), isTrue);
      expect(upcoming.items, isNotEmpty);
      expect(all.items.length, greaterThan(today.items.length));
      expect(all.items.every((t) => t.assigneeIds.contains(demoMeId)), isTrue);
      expect(all.pagination.total, all.items.length);
      expect(all.items.first.assigneeNames, isNotEmpty);
      expect(all.items.first.projectName, isNotNull);
    });

    test('việc theo người, đếm quá hạn, tìm kiếm', () async {
      final long = demoPeople[4].id;
      final byLong = await tasks.byAssignee(long);
      expect(byLong.items, isNotEmpty);
      expect(byLong.items.every((t) => !t.isDone), isTrue);
      expect(await tasks.overdueCount(long), greaterThan(0));

      final hits = await tasks.search('tu lanh');
      expect(hits.items, isNotEmpty);
      expect(
        hits.items.every((t) => t.title.toLowerCase().contains('tủ lạnh')),
        isTrue,
      );
    });

    test('chi tiết việc: việc con, bình luận, nhật ký, công đoạn', () async {
      final first = (await tasks.mine(
        bucket: TaskBucket.today,
      )).items.firstWhere((t) => t.commentCount > 0);
      final task = await tasks.get(first.id);

      expect(task.title, isNotEmpty);
      expect(task.subtasks, isNotEmpty);
      expect(task.subtasks.first.assigneeName, isNotNull);
      expect(task.comments, isNotEmpty);
      expect(task.comments.first.author, isNot('Người đã rời'));
      expect(task.activity, isNotEmpty);
      expect(task.planSections, isNotEmpty);
      expect(task.sectionName, isNotNull);
      expect(task.viewers.any((v) => v.userId == demoMeId), isTrue);

      final comments = await tasks.comments(task.id);
      expect(comments.items.length, task.commentCount);
      expect(await tasks.reminders(task.id), isEmpty);
    });

    test('kế hoạch nhìn từ module việc', () async {
      final movable = await tasks.projectsForMove();
      expect(movable.length, greaterThanOrEqualTo(4));
      expect(movable.every((p) => p.sections.isNotEmpty), isTrue);

      final warranty = movable.firstWhere((p) => p.name.contains('Bảo hành'));
      expect(await tasks.projectCustomFields(warranty.id), isNotEmpty);
      expect(await tasks.projectMemberIds(warranty.id), contains(demoMeId));
      final access = await tasks.project(warranty.id);
      expect(access.ownerId, isNotNull);

      final rows = await tasks.list(projectId: warranty.id);
      expect(rows.items, isNotEmpty);
      expect(rows.items.every((t) => t.projectId == warranty.id), isTrue);
    });

    test('nhãn việc: bản quản trị và bản cho thợ', () async {
      final labels = await tasks.taskLabels();
      expect(labels, isNotEmpty);
      expect(labels.every((l) => l.id.isNotEmpty && l.color != null), isTrue);
      expect(await tasks.taskLabelsForReaders(), hasLength(labels.length));
    });

    test('team, kế hoạch, bảng việc', () async {
      final teams = await plans.teams();
      expect(teams, hasLength(2));
      expect(teams.every((t) => t.memberIds.isNotEmpty), isTrue);

      final all = await plans.plans();
      expect(all.length, greaterThanOrEqualTo(4));
      expect(all.any((p) => p.teamId == null), isTrue);
      expect(all.any((p) => p.isFavorite == true), isTrue);
      expect(all.every((p) => p.taskCount > 0), isTrue);

      final ofTeam = await plans.plans(teamId: teams.first.id);
      expect(ofTeam, isNotEmpty);
      expect(ofTeam.every((p) => p.teamId == teams.first.id), isTrue);
      expect(ofTeam.first.teamName, teams.first.name);

      final plan = await plans.plan(all.first.id);
      expect(plan.sections, isNotEmpty);
      expect(plan.memberIds, isNotEmpty);

      final board = await loadAllTasksInPlan(plans, plan.id);
      expect(board.tasks, isNotEmpty);
      expect(board.truncated, isFalse);
      expect(
        board.tasks.every((t) => plan.sections.any((s) => s.id == t.sectionId)),
        isTrue,
      );

      expect(await plans.searchPlansNotEmpty('khuyen mai'), isTrue);
      final archived = await tasks.list(
        projectId: all.firstWhere((p) => p.teamId == null).id,
        archived: TaskArchiveScope.archived,
      );
      expect(archived.items, isNotEmpty);
      expect(archived.items.every((t) => t.archived), isTrue);
    });

    test('KPI tháng và dòng việc', () async {
      final kpi = await plans.kpi();
      expect(kpi.isConfigured, isTrue);
      expect(kpi.delivered, greaterThan(0));
      expect(kpi.tiers, isNotEmpty);
      expect(kpi.nextTier, isNotNull);

      final now = DateTime.now();
      final previous = await plans.kpi(
        month: DateTime(now.year, now.month - 1),
      );
      expect(previous.delivered, greaterThan(0));

      final feed = await plans.feed(types: kFeedCompletionTypes);
      expect(feed.entries, isNotEmpty);
      expect(feed.truncated, isFalse);
      expect(feed.entries.every((e) => e.day.isNotEmpty), isTrue);
      expect(feed.entries.first.userName, isNotNull);
    });

    test('danh bạ thành viên', () async {
      final members = await team.members();
      expect(members, hasLength(demoPeople.length));
      expect(members.every((m) => m.isSelectable), isTrue);
      expect(members.map((m) => m.name), contains(demoMe.name));
      expect(await team.userName(demoPeople[1].id), demoPeople[1].name);
    });
  });

  group('ghi trong phiên', () {
    test('tạo việc → có trong bảng; đổi trạng thái → chi tiết thấy', () async {
      final plan = (await plans.plans()).first;
      final created = await tasks.create(
        title: 'Giao máy lọc nước – anh Sơn',
        projectId: plan.id,
        sectionId: plan.sections.first.id,
        assigneeIds: [demoMeId],
        dueDate: DateTime.now(),
      );
      expect(created.id, isNotEmpty);

      final board = await loadAllTasksInPlan(plans, plan.id);
      expect(board.tasks.map((t) => t.id), contains(created.id));
      final mineToday = await tasks.mine(bucket: TaskBucket.today);
      expect(mineToday.items.map((t) => t.id), contains(created.id));

      await tasks.setStatus(created.id, 'done');
      final detail = await tasks.get(created.id);
      expect(detail.isDone, isTrue);
      expect(detail.activity.length, greaterThanOrEqualTo(2));

      final moved = await tasks.moveOnBoard(
        created.id,
        sectionId: plan.sections.last.id,
      );
      expect(moved.sectionId, plan.sections.last.id);
      expect(
        (await plans.plan(plan.id)).doneCount,
        greaterThan(plan.doneCount),
      );
    });

    test('tick việc con, bình luận, lời nhắc, sao chép', () async {
      final task = (await tasks.mine(
        bucket: TaskBucket.all,
      )).items.firstWhere((t) => t.subtasks.any((s) => !s.done));
      final open = task.subtasks.firstWhere((s) => !s.done);

      await tasks.setSubtaskDone(task.id, open.id, done: true);
      var detail = await tasks.get(task.id);
      expect(detail.doneCount, task.doneCount + 1);

      detail = await tasks.addSubtask(task.id, 'Chụp ảnh bàn giao');
      expect(detail.totalCount, task.totalCount + 1);

      await tasks.comment(
        task.id,
        'Đã xong bước này',
        mentionedUserIds: [demoPeople[1].id],
      );
      detail = await tasks.get(task.id);
      expect(detail.comments.last.body, 'Đã xong bước này');
      expect(detail.comments.last.mentionedUserNames, [demoPeople[1].name]);
      expect(detail.commentCount, task.commentCount + 1);

      await tasks.addReminder(
        task.id,
        DateTime.now().add(const Duration(hours: 2)),
      );
      expect(await tasks.reminders(task.id), hasLength(1));

      final copy = await tasks.copyTask(
        task.id,
        const TaskCopyRequest(title: 'Bản sao thử'),
      );
      expect(copy.title, 'Bản sao thử');
      expect(copy.subtasks.every((s) => !s.done), isTrue);

      final feed = await plans.feed(types: kFeedCompletionTypes);
      expect(feed.entries.first.detail, open.title);
    });

    test('tạo kế hoạch, team; yêu thích; nhãn mới', () async {
      final newTeam = await plans.createTeam(
        name: 'Team thử nghiệm',
        memberIds: {demoPeople[2].id},
      );
      expect((await plans.teams()).map((t) => t.id), contains(newTeam.id));

      final plan = await plans.createPlan(
        name: 'Trưng bày mùa hè',
        teamId: newTeam.id,
        sectionNames: ['Cần làm', 'Đang làm', 'Xong'],
      );
      expect(plan.sections, hasLength(3));
      expect(
        (await plans.plans(teamId: newTeam.id)).map((p) => p.id),
        contains(plan.id),
      );

      expect(await plans.setFavorite(plan.id, true), isTrue);
      expect((await plans.plan(plan.id)).isFavorite, isTrue);

      final edited = await plans.updatePlan(
        plan.id,
        PlanPatch(
          members: {
            demoMeId: PlanRole.owner,
            demoPeople[3].id: PlanRole.member,
          },
        ),
      );
      expect(edited.memberIds, contains(demoPeople[3].id));

      final label = await tasks.createLabel(label: 'Trả góp', color: '#2563EB');
      expect(label.code, 'tra_gop');
      expect(
        (await tasks.taskLabels()).map((l) => l.code),
        contains('tra_gop'),
      );
    });
  });
}

extension on PlansApi {
  Future<bool> searchPlansNotEmpty(String query) async =>
      (await plans(search: query)).isNotEmpty;
}
