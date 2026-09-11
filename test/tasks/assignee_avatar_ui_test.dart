import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:omni_app/design/components/omni_avatar.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/modules/tasks/application/task_controller.dart';
import 'package:omni_app/modules/tasks/application/tasks_providers.dart';
import 'package:omni_app/modules/tasks/domain/task.dart';
import 'package:omni_app/modules/tasks/domain/task_permissions.dart';
import 'package:omni_app/modules/tasks/presentation/task_detail_page.dart';
import 'package:omni_app/modules/tasks/presentation/widgets/comment_section.dart';
import 'package:omni_app/modules/tasks/presentation/widgets/subtask_row.dart';
import 'package:omni_app/modules/tasks/presentation/widgets/task_card.dart';
import 'package:omni_app/security/permissions/access_policy.dart';

/// Ảnh thật của người thay cho chữ tắt, ở bốn chỗ app đang vẽ người.
///
/// API đã gắn ảnh vào công việc; nếu bốn chỗ này vẫn dựng `OmniAvatar` không
/// có `imageUrl` thì người dùng vẫn thấy "HN" dù đã tải ảnh lên — kiểu hỏng
/// "server có, client không nối" đã lặp lại nhiều lần trong dự án này.
void main() {
  setUpAll(() => initializeDateFormatting('vi_VN'));

  const url = 'https://x/hn.png';

  Finder avatarWith(String? imageUrl) =>
      find.byWidgetPredicate((w) => w is OmniAvatar && w.imageUrl == imageUrl);

  Widget app(Widget child) => MaterialApp(
    theme: OmniTheme.light(TargetPlatform.android),
    home: Scaffold(body: child),
  );

  testWidgets('thẻ việc: người có ảnh thì ảnh, người chưa có thì chữ tắt', (
    tester,
  ) async {
    final task = Task.fromJson({
      'id': 't1',
      'title': 'KAWAI HAT-5',
      'assignee_ids': ['u1', 'u2'],
      'assignee_names': ['Hằng Ni', 'Luận'],
      'assignee_avatars': [url, null],
    });
    await tester.pumpWidget(app(TaskCard(task: task, onTap: () {})));

    expect(avatarWith(url), findsOneWidget);
    expect(
      avatarWith(null),
      findsOneWidget,
      reason: 'Luận chưa có ảnh → chữ tắt',
    );
  });

  testWidgets('công đoạn: chip người phụ trách mang ảnh', (tester) async {
    final step = Subtask.fromJson({
      'id': 's1',
      'title': 'Nắp phím',
      'done': false,
      'assignee_id': 'u1',
      'assignee_name': 'Hằng Ni',
      'assignee_avatar': url,
    });
    await tester.pumpWidget(
      app(
        SubtaskRow(
          subtask: step,
          pending: null,
          enabled: true,
          onToggle: (_) {},
          onRetry: () {},
          onDiscard: () {},
        ),
      ),
    );

    expect(avatarWith(url), findsOneWidget);
    expect(find.text('Hằng Ni'), findsOneWidget);
  });

  testWidgets('bình luận: người viết mang ảnh', (tester) async {
    final task = Task.fromJson({
      'id': 't1',
      'title': 'x',
      'comments': [
        {
          'id': 'c1',
          'body': 'QC trượt',
          'user_id': 'u1',
          'user_name': 'Hằng Ni',
          'user_avatar': url,
        },
      ],
      'comments_count': 1,
    });
    await tester.pumpWidget(
      ProviderScope(
        child: app(CommentSection(task: task, taskId: 't1', canWrite: false)),
      ),
    );

    expect(avatarWith(url), findsOneWidget);
  });

  testWidgets('thành viên đã xem: chip mang ảnh', (tester) async {
    final task = Task.fromJson({
      'id': 't1',
      'title': 'KAWAI HAT-5',
      'checklist': <Map<String, dynamic>>[],
      'viewers': [
        {
          'user_id': 'u1',
          'name': 'Hằng Ni',
          'avatar': url,
          'viewed_at': '2026-09-11T02:00:00Z',
        },
      ],
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          taskDetailProvider.overrideWith(
            () => _StubDetail(TaskDetailState(task: task)),
          ),
          taskAccessProvider.overrideWithValue(
            TaskAccess.of(const AccessPolicy({'tasks.read', 'tasks.write'})),
          ),
        ],
        child: MaterialApp(
          theme: OmniTheme.light(TargetPlatform.android),
          home: const TaskDetailPage(taskId: 't1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Thành viên đã xem'),
      200,
      scrollable: find.byType(Scrollable).first,
    );

    expect(avatarWith(url), findsOneWidget);
  });
}

class _StubDetail extends TaskController {
  _StubDetail(this._state);
  final TaskDetailState _state;
  @override
  Future<TaskDetailState> build(String taskId) async => _state;
}
