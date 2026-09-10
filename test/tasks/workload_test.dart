import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/core/config/app_config.dart';
import 'package:omni_app/core/network/api_envelope.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/modules/tasks/data/tasks_api.dart';
import 'package:omni_app/modules/tasks/domain/task.dart';
import 'package:omni_app/modules/tasks/presentation/workload_page.dart';
import 'package:omni_app/modules/team/team.dart';

/// "Người này đang gánh bao nhiêu cây, và trễ cái nào."
///
/// Câu hỏi quản đốc hỏi nhiều nhất khi đứng giữa xưởng, và app chưa có chỗ nào
/// trả lời: "Việc của tôi" chỉ nói về người đang đăng nhập, còn bảng dự án
/// nói về cây đàn chứ không nói về người. Muốn biết một người đang ôm mấy việc
/// thì phải mở từng cột, đọc từng thẻ, đếm trong đầu.
void main() {
  Widget host(TasksApi api, {List<TeamMember> roster = const []}) =>
      ProviderScope(
        overrides: [
          tasksApiProvider.overrideWithValue(api),
          teamMembersProvider.overrideWith((ref) async => roster),
        ],
        child: MaterialApp(
          theme: OmniTheme.light(TargetPlatform.android),
          home: const WorkloadPage(userId: 'u-hang-ni'),
        ),
      );

  testWidgets('hỏi SERVER "chưa xong", không hỏi "tất cả"', (tester) async {
    // Bốn nhóm việc cũ đều lọc theo HẠN, mà phần lớn công đoạn ở xưởng không
    // đặt hạn riêng — chúng chạy theo bảng tháng (§B0). Hỏi nhầm nhóm ở đây
    // cho ra một con số nhỏ hơn sự thật, và nó trông y hệt một con số đúng.
    final api = _RecordingTasksApi(total: 3);
    await tester.pumpWidget(host(api));
    await tester.pumpAndSettle();

    expect(api.askedFor, 'u-hang-ni');
    expect(api.askedBucket, TaskBucket.open);
  });

  testWidgets('hai con số đều do server đếm, không đếm trên danh sách', (
    tester,
  ) async {
    // Danh sách có phân trang. Một con số đếm từ trang một là con số của
    // trang một — và trên màn hình nó trông y hệt một con số của tất cả.
    final api = _RecordingTasksApi(total: 47, overdue: 5, itemsOnPage: 2);
    await tester.pumpWidget(host(api));
    await tester.pumpAndSettle();

    expect(find.text('47'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
  });

  testWidgets('nói ra khi danh sách chỉ hiện được một phần', (tester) async {
    // Con số 47 ở trên và hai thẻ ở dưới mâu thuẫn nhau ngay trên một màn
    // hình. Không nói ra thì người đọc tin cái đếm được bằng mắt.
    final api = _RecordingTasksApi(total: 47, itemsOnPage: 2);
    await tester.pumpWidget(host(api));
    await tester.pumpAndSettle();

    expect(find.textContaining('2 việc đầu'), findsOneWidget);
  });

  testWidgets('không nói thừa khi đã hiện đủ', (tester) async {
    final api = _RecordingTasksApi(total: 2, itemsOnPage: 2);
    await tester.pumpWidget(host(api));
    await tester.pumpAndSettle();

    expect(find.textContaining('việc đầu'), findsNothing);
  });

  testWidgets('việc trễ nằm trên việc chưa đặt hạn', (tester) async {
    // Đây là màn hình để QUYẾT ĐỊNH — chuyển bớt việc cho ai, hay để yên — và
    // cái quyết định đó bắt đầu từ những cây đang trễ. Ở xưởng phần lớn công
    // đoạn không đặt hạn, nên để chúng lên trước là chôn đúng phần cần đọc
    // dưới phần bình thường.
    final api = _RecordingTasksApi.withTasks([
      Task.fromJson({'id': 't1', 'title': 'Chua dat han'}),
      Task.fromJson({'id': 't2', 'title': 'Da tre', 'due_date': '2020-01-01'}),
    ]);
    await tester.pumpWidget(host(api));
    await tester.pumpAndSettle();

    final late_ = tester.getTopLeft(find.text('Da tre')).dy;
    final undated = tester.getTopLeft(find.text('Chua dat han')).dy;

    expect(late_, lessThan(undated));
  });

  testWidgets('không có việc nào thì nói là rảnh, không hiện thẻ số 0', (
    tester,
  ) async {
    final api = _RecordingTasksApi(total: 0, itemsOnPage: 0);
    await tester.pumpWidget(host(api));
    await tester.pumpAndSettle();

    expect(find.textContaining('Không có việc nào đang mở'), findsOneWidget);
  });

  testWidgets('tiêu đề là TÊN người, không phải id', (tester) async {
    // Một UUID trên thanh tiêu đề không nói cho ai điều gì — và quản đốc mở
    // màn này ra là để nghĩ về một con người cụ thể.
    final api = _RecordingTasksApi(total: 1);
    await tester.pumpWidget(
      host(
        api,
        roster: const [
          TeamMember(
            membershipId: 'm1',
            userId: 'u-hang-ni',
            name: 'Hằng Ni',
            jobTitle: 'Thợ máy',
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Hằng Ni'), findsOneWidget);
    expect(find.text('Thợ máy'), findsOneWidget);
    expect(find.textContaining('u-hang-ni'), findsNothing);
  });
}

class _RecordingTasksApi implements TasksApi {
  _RecordingTasksApi({this.total = 0, this.overdue = 0, int itemsOnPage = 1})
    : tasks = [
        for (var i = 0; i < itemsOnPage; i++)
          Task.fromJson({'id': 't$i', 'title': 'Cay dan $i'}),
      ];

  _RecordingTasksApi.withTasks(this.tasks) : total = 0, overdue = 0;

  final int total;
  final int overdue;
  final List<Task> tasks;

  String? askedFor;
  TaskBucket? askedBucket;

  @override
  Future<Paged<Task>> byAssignee(
    String userId, {
    TaskBucket bucket = TaskBucket.open,
    int page = 1,
    int perPage = AppConfig.defaultPerPage,
  }) async {
    askedFor = userId;
    askedBucket = bucket;

    return Paged(
      items: tasks,
      pagination: ApiPagination(
        currentPage: 1,
        lastPage: 1,
        perPage: perPage,
        total: total == 0 ? tasks.length : total,
      ),
    );
  }

  @override
  Future<int> overdueCount(String userId) async => overdue;

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
