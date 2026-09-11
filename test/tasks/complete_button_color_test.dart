import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/modules/tasks/application/task_controller.dart';
import 'package:omni_app/modules/tasks/application/tasks_providers.dart';
import 'package:omni_app/modules/tasks/domain/task.dart';
import 'package:omni_app/modules/tasks/domain/task_permissions.dart';
import 'package:omni_app/modules/tasks/presentation/task_detail_page.dart';
import 'package:omni_app/security/permissions/access_policy.dart';

/// Nút "Hoàn thành công việc" mang màu THƯƠNG HIỆU, không phải màu "thành công".
///
/// Chữ trắng trên xanh lá #10B981 chỉ đạt ~2,5:1 — trượt chuẩn 4,5:1 trên đúng
/// cái nút được bấm nhiều nhất trong ngày. Và đó là màu xanh thứ hai đứng cạnh
/// mòng két thương hiệu. Bài này giữ cho nút không quay lại xanh lá.
void main() {
  setUpAll(() => initializeDateFormatting('vi_VN'));

  const perms = {'tasks.read', 'tasks.write', 'tasks.projects.manage.all'};

  Widget host(Task task) => ProviderScope(
    overrides: [
      taskDetailProvider.overrideWith(
        () => _StubDetail(TaskDetailState(task: task)),
      ),
      taskAccessProvider.overrideWithValue(
        TaskAccess.of(const AccessPolicy(perms)),
      ),
    ],
    child: MaterialApp(
      theme: OmniTheme.light(TargetPlatform.android),
      home: const TaskDetailPage(taskId: 't1'),
    ),
  );

  testWidgets('nút hoàn thành dùng màu primary, chữ onPrimary', (tester) async {
    await tester.pumpWidget(
      host(
        Task.fromJson({
          'id': 't1',
          'title': 'KAWAI HAT-5',
          'status': 'doing',
          'checklist': <Map<String, dynamic>>[],
        }),
      ),
    );
    await tester.pumpAndSettle();

    final finder = find.widgetWithText(FilledButton, 'Hoàn thành công việc');
    expect(finder, findsOneWidget);

    final button = tester.widget<FilledButton>(finder);
    final scheme = Theme.of(tester.element(finder)).colorScheme;
    final bg = button.style?.backgroundColor?.resolve({});
    final fg = button.style?.foregroundColor?.resolve({});

    expect(bg, scheme.primary, reason: 'xanh lá #10B981 chỉ đạt 2,5:1 với chữ trắng');
    expect(fg, scheme.onPrimary);
  });
}

class _StubDetail extends TaskController {
  _StubDetail(this._state);
  final TaskDetailState _state;
  @override
  Future<TaskDetailState> build(String taskId) async => _state;
}
