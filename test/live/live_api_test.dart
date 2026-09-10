import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/core/config/app_config.dart';
import 'package:omni_app/core/network/api_client.dart';
import 'package:omni_app/modules/plans/data/plans_api.dart';
import 'package:omni_app/modules/tasks/data/tasks_api.dart';
import 'package:omni_app/modules/team/data/team_api.dart';

/// App nói chuyện với API THẬT, không phải với một cái giả do app tự dựng.
///
/// Toàn bộ 71 tệp kiểm còn lại của app đều cắm một `HttpClientAdapter` giả.
/// Chúng chứng minh app gửi đúng hình dạng mà app TIN là đúng — và đó chính là
/// điều đã sai tám lần trong dự án này:
///
///   - `assignee_names`, `stats`, `project_name` — đoán tên trường server không gửi
///   - `/feed` thay vì `/tasks/feed` — sai đường dẫn
///   - `PATCH /tasks/{id}/checklist/{itemId}` — route chưa từng được viết
///   - `zalo_user_id` — API nhận mà không bao giờ trả về
///   - `content` thay vì `body` khi gửi bình luận — server từ chối 422
///   - chuỗi rỗng không xoá được trường — server trả 200 và không làm gì
///
/// Không lỗi nào trong tám lỗi đó bị một widget test bắt được, và về nguyên
/// tắc thì không thể: một adapter giả luôn trả lời đúng cái mà người viết test
/// nghĩ server sẽ trả lời. Cả tám đều lộ ra khi gọi HTTP thật.
///
/// Bài này gọi thật. Nó dựng một workspace mới mỗi lần chạy nên không đụng dữ
/// liệu của ai, và nó dùng CHÍNH các lớp app dùng khi chạy — `TasksApi`,
/// `PlansApi`, `TeamApi` — chứ không gọi curl rồi tự đọc JSON. Cái được kiểm
/// là đường đi từ màn hình xuống server và ngược lại.
///
/// CHẠY:
///   flutter test test/live --dart-define=OMNI_LIVE_API=http://localhost:8000
///
/// Không có biến đó thì mọi bài BỎ QUA chứ không đỏ — cùng quy ước với
/// `MongoTestCase` bên API. Bỏ qua khác hẳn xanh, và CI phải phân biệt được:
/// một bài "xanh" vì không có server là một bài nói dối.
const _base = String.fromEnvironment('OMNI_LIVE_API');

void main() {
  if (_base.isEmpty) {
    test('API thật chưa được khai — bỏ qua', () {}, skip: 'Đặt --dart-define=OMNI_LIVE_API=http://localhost:8000 để chạy.');

    return;
  }

  late ApiClient client;
  late TasksApi tasks;
  late PlansApi plans;
  late TeamApi team;
  late String tenantId;

  setUpAll(() async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    final raw = Dio(BaseOptions(baseUrl: _base, headers: {'Accept': 'application/json'}));

    final registered = await raw.post<Map<String, dynamic>>(
      '${AppConfig.apiPrefix}/auth/register',
      data: {
        'company_name': 'Live $stamp',
        'full_name': 'Quan doc',
        'email': 'live$stamp@viomni.test',
        'password': 'Matkhau!2026',
        'password_confirmation': 'Matkhau!2026',
      },
    );
    final token = (registered.data!['data'] as Map)['access_token'] as String;

    final tenants = await raw.get<Map<String, dynamic>>(
      '${AppConfig.apiPrefix}/auth/tenants',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    tenantId = (((tenants.data!['data'] as List).first as Map)['tenant'] as Map)['id'] as String;

    // Cùng hai header mà `dio_provider` gắn khi app chạy thật.
    client = ApiClient(
      Dio(
        BaseOptions(
          baseUrl: _base,
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
            'X-Tenant-Id': tenantId,
          },
        ),
      ),
    );
    tasks = TasksApi(client);
    plans = PlansApi(client);
    team = TeamApi(client);
  });

  group('kế hoạch và công việc', () {
    test('tạo kế hoạch rồi đọc lại thấy đúng nhóm việc', () async {
      final plan = await plans.createPlan(
        name: 'Phuc che dan co',
        sectionNames: const ['Nhap xuong', 'Cho QC', 'Hoan thien'],
        gatedSectionNames: const {'Cho QC'},
      );

      expect(plan.id, isNotEmpty);
      expect(plan.sections.map((s) => s.name), ['Nhap xuong', 'Cho QC', 'Hoan thien']);

      // Cờ cổng QC phải sống sót qua vòng ghi–đọc. Mất nó là mất §B3, và mất
      // im lặng: bảng vẫn hiện đủ ba cột.
      final gated = plan.sections.firstWhere((s) => s.name == 'Cho QC');
      expect(gated.requiresChecklist, isTrue);
    });

    test('tạo việc, giao người, đọc lại thấy TÊN chứ không phải id', () async {
      final plan = await plans.createPlan(
        name: 'Ke hoach giao viec',
        sectionNames: const ['Cho lam', 'Dang lam'],
      );

      final created = await tasks.create(title: 'SCHWESTER No.53', projectId: plan.id);
      expect(created.id, isNotEmpty);

      final members = await team.members();
      expect(members, isNotEmpty, reason: 'Workspace mới phải có ít nhất người lập.');

      final assigned = await tasks.setAssignees(created.id, [members.first.userId]);

      // Đây là một trong ba trường app từng đoán sai: `assignee_names` chưa
      // từng được server sinh ra, và không gì báo — danh sách chỉ trống mãi.
      expect(
        assigned.assigneeNames,
        isNotEmpty,
        reason: 'API phải giải sẵn tên người làm; app không có quyền tra ngược.',
      );
      expect(assigned.assigneeNames.first, isNotEmpty);
    });

    test('tick việc con đi qua endpoint từng mục và LƯU được', () async {
      final plan = await plans.createPlan(name: 'Ke hoach tick', sectionNames: const ['A', 'B']);
      final task = await tasks.create(title: 'KAWAI HAT-5', projectId: plan.id);

      // Việc con đầu tiên: id do SERVER sinh.
      final withItem = await tasks.addSubtask(task.id, 'Body ngoai');
      expect(withItem.subtasks, hasLength(1));
      final itemId = withItem.subtasks.first.id;
      expect(itemId, isNotEmpty);

      final ticked = await tasks.setSubtaskDone(task.id, itemId, done: true);
      expect(ticked.subtasks.first.done, isTrue);

      // ĐỌC LẠI: phản hồi của lượt ghi có thể đúng trong khi đĩa không đổi.
      final reread = await tasks.get(task.id);
      expect(reread.subtasks.first.done, isTrue);
    });

    test('xoá hạn bằng chuỗi rỗng thật sự xoá', () async {
      // Bốn trường từng không xoá được, và cả bốn trả 200 kèm dữ liệu y nguyên:
      // middleware của Laravel biến chuỗi rỗng thành null trước khi tới
      // controller. Không một widget test nào chạm được vào chuyện đó.
      final task = await tasks.create(title: 'Thu xoa han');

      final withDue = await tasks.setDueDate(task.id, DateTime(2026, 12, 1));
      expect(withDue.dueDate, isNotNull);

      await tasks.setDueDate(task.id, null);
      expect((await tasks.get(task.id)).dueDate, isNull);
    });

    test('bình luận gửi được và mang theo TÊN người viết', () async {
      final task = await tasks.create(title: 'Thu binh luan');

      // Khoá là `body`, không phải `content` — bản cũ gửi `content` và nhận
      // 422 cho MỌI bình luận, suốt nhiều tháng, vì không màn hình nào gọi tới.
      final commented = await tasks.comment(task.id, 'Body con xuoc, lam lai');

      expect(commented.comments, isNotEmpty);
      expect(
        commented.comments.first.author,
        isNot('Người đã rời'),
        reason: 'API phải giải sẵn tên người viết vào từng bình luận.',
      );
    });
  });

  group('quản đốc đứng giữa xưởng', () {
    test('tải việc của một người đếm cả việc CHƯA đặt hạn', () async {
      // Nhóm `open` là nhóm thứ năm, thêm cùng lúc với màn này. Bốn nhóm cũ
      // đều lọc theo HẠN, mà phần lớn công đoạn ở xưởng không đặt hạn riêng —
      // chúng chạy theo bảng tháng (§B0). Lệch một chữ giữa Dart và PHP thì
      // server im lặng rơi về "tất cả", và con số lớn hơn sự thật.
      final members = await team.members();
      final me = members.first;

      final task = await tasks.create(title: 'Cay chua dat han');
      await tasks.setAssignees(task.id, [me.userId]);

      final load = await tasks.byAssignee(me.userId);
      expect(
        load.items.map((t) => t.id),
        contains(task.id),
        reason: 'Việc chưa đặt hạn vẫn là việc đang gánh.',
      );

      // Xong rồi thì thôi là tải của ai. Không có nhánh này thì sau vài tháng
      // con số chỉ nói lên người đó vào làm từ bao giờ.
      await tasks.setStatus(task.id, 'done');
      final after = await tasks.byAssignee(me.userId);
      expect(after.items.map((t) => t.id), isNot(contains(task.id)));
    });

    test('tìm ra cây đàn theo số máy nằm trong tiêu đề', () async {
      final stamp = DateTime.now().microsecondsSinceEpoch.toString();
      await tasks.create(title: 'SCHWESTER No.53 — SN $stamp');

      final hits = await tasks.search(stamp);
      expect(hits.items, isNotEmpty, reason: 'Server so khớp theo đoạn trên `title`.');
      expect(hits.items.first.title, contains(stamp));
    });

    test('nhật ký của một công việc mang TÊN người, không mang UUID', () async {
      // Dòng thời gian toàn xưởng có tên người từ lâu; `activity` nhúng trong
      // một công việc thì chưa ai giải — nên app không hiện nổi nhật ký, mà
      // đó là chỗ duy nhất trả lời "ai đã kéo cây này về lại".
      final task = await tasks.create(title: 'Cay co nhat ky');

      final reread = await tasks.get(task.id);
      expect(reread.activity, isNotEmpty, reason: 'Tạo việc phải để lại một dòng.');
      expect(
        reread.activity.first.userName,
        isNotNull,
        reason: 'API phải giải sẵn tên; app không có quyền tra ngược.',
      );
    });
  });

  group('dòng thời gian và KPI', () {
    test('dòng thời gian gọi đúng /tasks/feed và có bản ghi', () async {
      // Đường dẫn từng thiếu tiền tố `/tasks` và gọi vào một đường không tồn
      // tại. Màn hình chỉ hiện rỗng — "chưa có hoạt động nào" và 404 trông y
      // hệt nhau.
      final plan = await plans.createPlan(name: 'Ke hoach feed', sectionNames: const ['A', 'B']);
      await tasks.create(title: 'Cay dan cho feed', projectId: plan.id);

      final feed = await plans.feed();
      expect(feed, isNotEmpty, reason: 'Vừa tạo một việc thì dòng thời gian phải có bản ghi.');
      expect(feed.first.taskTitle, isNotEmpty);
    });

    test('KPI đọc được, và nói rõ khi chưa cấu hình', () async {
      final kpi = await plans.kpi();

      // Workspace mới chưa đánh dấu cột đích nào. Con số 0 ở đây phải phân
      // biệt được với "tháng này chưa ai làm xong việc nào" — nếu không thì
      // cuối tháng có người đọc nhầm nó để trả thưởng.
      expect(kpi.isConfigured, isFalse);
      expect(kpi.delivered, 0);
    });

    test('tháng ĐÃ QUA không còn ngày nào để chạy', () async {
      // `diffInDays(absolute: true)` bên API không biết chiều, nên xem lại
      // tháng trước từng trả về một số dương — và app chia nó ra thành "nhịp
      // cần thiết" cho một tháng đã hết ngày.
      final now = DateTime.now();
      final past = await plans.kpi(month: DateTime(now.year, now.month - 1));

      expect(past.daysLeft, 0);
      expect(past.perDayNeeded, isNull, reason: 'Không khuyên nhịp cho quá khứ.');

      // Tháng đang chạy vẫn phải đếm ngược — sửa quá khứ mà hỏng hiện tại là
      // mất đúng phần §B4 dùng.
      expect((await plans.kpi()).daysLeft, greaterThan(0));
    });
  });

  group('nhân sự', () {
    test('liên kết Zalo ghi rồi ĐỌC LẠI được, và gỡ được', () async {
      // API nhận trường này từ lâu nhưng không bao giờ TRẢ nó về, nên app hiện
      // "Chưa liên kết" vĩnh viễn cho cả người đã liên kết.
      final members = await team.members();
      final me = members.first;

      await team.setZaloUserId(me.membershipId, '79000012345');
      final linked = (await team.members()).firstWhere((m) => m.membershipId == me.membershipId);
      expect(linked.zaloUserId, '79000012345');

      await team.setZaloUserId(me.membershipId, '');
      final cleared = (await team.members()).firstWhere((m) => m.membershipId == me.membershipId);
      expect(cleared.zaloUserId ?? '', isEmpty);
    });
  });

  tearDownAll(() {
    // Không dọn workspace: API không có đường xoá tenant, và mỗi lần chạy dùng
    // một workspace riêng nên không ai bị ảnh hưởng. Chỉ nói ra để người đọc
    // biết đây là lựa chọn, không phải quên.
    stdout.writeln('Workspace kiểm thử để lại trong tenant $tenantId.');
  });
}
