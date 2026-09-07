import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/modules/plans/application/plans_providers.dart';
import 'package:omni_app/modules/plans/domain/feed_entry.dart';
import 'package:omni_app/modules/plans/domain/workshop_kpi.dart';
import 'package:omni_app/modules/plans/presentation/timeline_page.dart';
import 'package:omni_app/modules/tasks/application/tasks_providers.dart';
import 'package:omni_app/modules/tasks/domain/task_permissions.dart';
import 'package:omni_app/security/permissions/access_policy.dart';

/// "Chuyện gì vừa xảy ra" cho mọi người, "tháng này xong bao nhiêu cây" cho
/// người giao việc.
void main() {
  setUpAll(() => initializeDateFormatting('vi_VN'));

  const worker = {'tasks.read', 'tasks.write'};
  const assigner = {'tasks.read', 'tasks.write', 'tasks.projects.manage.all'};

  FeedEntry entry({
    String type = 'section_id',
    String title = 'KAWAI HAT-5',
    String? user = 'Hằng Ni',
    String taskId = 't1',
    String? detail,
  }) => FeedEntry.fromJson({
    'id': 'a1',
    'type': type,
    'task_id': taskId,
    'task_title': title,
    'created_at': '2026-09-06T08:00:00Z',
    'user_name': ?user,
    'title': ?detail,
  });

  Map<String, dynamic> kpiJson({int delivered = 12, bool configured = true}) =>
      {
        'delivered': delivered,
        'reached_bonus': 0,
        'next_tier': {'count': 35, 'bonus': 3, 'remaining': 35 - delivered},
        'tiers': {'35': 3},
        'days_left': 18,
        'counting_sections': configured ? ['s4'] : <String>[],
      };

  Widget host({
    Set<String> permissions = worker,
    List<FeedEntry> feed = const [],
    Map<String, dynamic>? kpi,
  }) => ProviderScope(
    overrides: [
      workshopFeedProvider.overrideWith((ref) async => feed),
      workshopKpiProvider.overrideWith(
        (ref) async => WorkshopKpi.fromJson(kpi ?? kpiJson()),
      ),
      taskAccessProvider.overrideWithValue(
        TaskAccess.of(AccessPolicy(permissions)),
      ),
    ],
    child: MaterialApp(
      theme: OmniTheme.light(TargetPlatform.android),
      home: const TimelinePage(),
    ),
  );

  testWidgets('người nhận việc thấy dòng hoạt động, KHÔNG thấy thẻ KPI', (
    tester,
  ) async {
    await tester.pumpWidget(host(feed: [entry()]));
    await tester.pumpAndSettle();

    expect(find.text('KAWAI HAT-5'), findsOneWidget);
    expect(
      find.textContaining('cây xong tháng này'),
      findsNothing,
      reason:
          'Thưởng tính theo TEAM (§1). Bày mốc thưởng trước mặt từng thợ là '
          'đổi cách xưởng làm việc, và tài liệu nói rõ họ không làm vậy.',
    );
  });

  testWidgets('người giao việc thấy cả hai', (tester) async {
    await tester.pumpWidget(host(permissions: assigner, feed: [entry()]));
    await tester.pumpAndSettle();

    expect(find.text('12'), findsOneWidget);
    expect(find.textContaining('cây xong tháng này'), findsOneWidget);
    expect(find.text('KAWAI HAT-5'), findsOneWidget);
  });

  testWidgets('tên người đứng trước hành động, đọc thành một câu', (
    tester,
  ) async {
    await tester.pumpWidget(host(feed: [entry()]));
    await tester.pumpAndSettle();

    expect(find.text('Hằng Ni đã chuyển công đoạn'), findsOneWidget);
  });

  testWidgets('không tra được tên thì chỉ hiện hành động, không hiện UUID', (
    tester,
  ) async {
    await tester.pumpWidget(host(feed: [entry(user: null)]));
    await tester.pumpAndSettle();

    expect(find.text('đã chuyển công đoạn'), findsOneWidget);
  });

  testWidgets('loại hoạt động lạ vẫn hiện, không bị giấu', (tester) async {
    // Một client cũ gặp loại mới phải nói "có thay đổi" chứ không được im.
    await tester.pumpWidget(host(feed: [entry(type: 'điều_gì_đó_mới')]));
    await tester.pumpAndSettle();

    expect(find.text('Hằng Ni đã có thay đổi'), findsOneWidget);
  });

  testWidgets('chưa đánh dấu cột đích thì thẻ nói ra, không hiện số 0', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        permissions: assigner,
        feed: [entry()],
        kpi: kpiJson(delivered: 0, configured: false),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Chưa có kế hoạch nào đánh dấu công đoạn đích'),
      findsOneWidget,
      reason:
          'Một số 0 vì chưa cấu hình trông y hệt một số 0 vì chưa làm được cây '
          'nào, và một trong hai là tin xấu về xưởng.',
    );
  });

  testWidgets('KPI hỏng không che mất dòng hoạt động', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          workshopFeedProvider.overrideWith((ref) async => [entry()]),
          workshopKpiProvider.overrideWith(
            (ref) async => throw Exception('API sập'),
          ),
          taskAccessProvider.overrideWithValue(
            TaskAccess.of(const AccessPolicy(assigner)),
          ),
        ],
        child: MaterialApp(
          theme: OmniTheme.light(TargetPlatform.android),
          home: const TimelinePage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('KAWAI HAT-5'),
      findsOneWidget,
      reason:
          'KPI là thứ phụ trên màn này — quan trọng nhất với chủ xưởng, nhưng '
          'không đáng đánh đổi cả màn hình khi nó hỏng.',
    );
  });

  testWidgets('thợ chưa có hoạt động nào thì nói rõ là chưa có', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    expect(find.text('Chưa có hoạt động nào'), findsOneWidget);
  });

  testWidgets('tên cây đàn hiện MỘT lần cho nhiều hoạt động', (tester) async {
    // Trước đây mỗi hoạt động là một dòng mang theo tên cây đàn, nên ba người
    // đụng vào cùng một cây trong một buổi cho ba dòng lặp lại y hệt nhau.
    await tester.pumpWidget(
      host(
        feed: [
          entry(type: 'subtask_completed', detail: 'Body ngoài'),
          entry(type: 'attachment_added', user: 'luận'),
          entry(type: 'section_id', user: 'linh'),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('KAWAI HAT-5'), findsOneWidget);
    expect(find.text('Hằng Ni đã xong Body ngoài'), findsOneWidget);
    expect(find.text('luận đã gửi tệp đính kèm'), findsOneWidget);
    expect(find.text('linh đã chuyển công đoạn'), findsOneWidget);
  });

  testWidgets('cây khác nhau vẫn là thẻ khác nhau', (tester) async {
    await tester.pumpWidget(
      host(
        feed: [
          entry(taskId: 't1', title: 'KAWAI HAT-5'),
          entry(taskId: 't2', title: 'YAMAHA U1H'),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('KAWAI HAT-5'), findsOneWidget);
    expect(find.text('YAMAHA U1H'), findsOneWidget);
  });

  testWidgets('một cây bị rework dồn dập không đẩy cả xưởng khỏi màn hình', (
    tester,
  ) async {
    // Bảy hoạt động liên tiếp trên một cây. Hiện hết thì thẻ đó chiếm trọn màn
    // và những cây khác biến mất — đúng thứ màn "tổng quan" không được làm.
    await tester.pumpWidget(
      host(feed: [for (var i = 0; i < 7; i++) entry(user: 'thợ $i')]),
    );
    await tester.pumpAndSettle();

    expect(find.text('thợ 0 đã chuyển công đoạn'), findsOneWidget);
    expect(find.text('thợ 4 đã chuyển công đoạn'), findsOneWidget);
    expect(find.text('thợ 5 đã chuyển công đoạn'), findsNothing);
    expect(find.text('và 2 hoạt động nữa'), findsOneWidget);
  });
}
