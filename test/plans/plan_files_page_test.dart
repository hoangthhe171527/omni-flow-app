import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/modules/plans/application/plans_providers.dart';
import 'package:omni_app/modules/plans/presentation/plan_files_page.dart';
import 'package:omni_app/modules/tasks/data/tasks_api.dart';
import 'package:omni_app/modules/tasks/domain/task.dart';
import 'package:omni_app/modules/tasks/tasks.dart';

/// Tệp của một kế hoạch (Task 7): gộp `attachments[]` của mọi việc trên bảng,
/// lưới 3 cột, tên việc dưới mỗi tệp, bấm giữ để xoá khi có quyền.
void main() {
  const planId = 'p1';

  Map<String, dynamic> file(String id, String name, {String type = 'file'}) => {
    'id': id,
    'name': name,
    'url': 'https://x.vn/$id',
    'type': type,
  };

  final tasks = [
    Task.fromJson({
      'id': 't1',
      'title': 'Đàn A',
      'attachments': [file('a1', 'bao-gia.pdf'), file('a2', 'phieu.pdf')],
    }),
    Task.fromJson({
      'id': 't2',
      'title': 'Đàn B',
      'attachments': [file('a3', 'hop-dong.pdf')],
    }),
    Task.fromJson({'id': 't3', 'title': 'Đàn C'}),
    Task.fromJson({
      'id': 't4',
      'title': 'Đàn D',
      'attachments': [file('a4', 'nghiem-thu.pdf')],
    }),
  ];

  late _FilesApi api;

  Future<void> pump(
    WidgetTester tester, {
    bool canDelete = true,
    List<Task>? items,
    bool truncated = false,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    api = _FilesApi();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tasksApiProvider.overrideWithValue(api),
          planTasksProvider.overrideWith(
            (ref, id) async => (tasks: items ?? tasks, truncated: truncated),
          ),
        ],
        child: MaterialApp(
          theme: OmniTheme.light(TargetPlatform.android),
          home: PlanFilesPage(planId: planId, canDelete: canDelete),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('(b) gộp tệp từ 3 việc, lưới 3 cột, tên việc dưới tệp', (
    tester,
  ) async {
    await pump(tester);

    expect(find.text('Tệp đính kèm'), findsOneWidget);
    expect(find.byType(AttachmentThumb), findsNWidgets(4));
    expect(find.text('Đàn A'), findsNWidgets(2));
    expect(find.text('Đàn B'), findsOneWidget);
    expect(find.text('Đàn D'), findsOneWidget);
    expect(find.text('Đàn C'), findsNothing);

    // Ba ô cùng một hàng, ô thứ tư xuống hàng.
    final thumbs = find.byType(AttachmentThumb);
    final y0 = tester.getTopLeft(thumbs.at(0)).dy;
    expect(tester.getTopLeft(thumbs.at(1)).dy, y0);
    expect(tester.getTopLeft(thumbs.at(2)).dy, y0);
    expect(tester.getTopLeft(thumbs.at(3)).dy, greaterThan(y0));
    expect(tester.getSize(thumbs.at(0)).width, greaterThanOrEqualTo(44));
  });

  testWidgets('(b) bấm giữ → "Xoá tệp" → hỏi lại → deleteAttachment', (
    tester,
  ) async {
    await pump(tester);

    await tester.longPress(find.byType(AttachmentThumb).at(2));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xoá tệp'));
    await tester.pumpAndSettle();
    expect(find.text('Xoá tệp “hop-dong.pdf”?'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Xoá tệp'));
    await tester.pumpAndSettle();

    expect(api.deletes, [('t2', 'a3')]);
    expect(find.text('Đã xoá tệp.'), findsOneWidget);
  });

  testWidgets('(d) không có quyền ghi: bấm giữ không có "Xoá tệp"', (
    tester,
  ) async {
    await pump(tester, canDelete: false);

    await tester.longPress(find.byType(AttachmentThumb).first);
    await tester.pumpAndSettle();
    expect(find.text('Xoá tệp'), findsNothing);
    expect(api.deletes, isEmpty);
  });

  testWidgets('rỗng: lời nhắn trống', (tester) async {
    await pump(tester, items: [tasks[2]]);

    expect(find.text('Chưa có tệp nào'), findsOneWidget);
  });

  testWidgets('bảng bị cắt ở trần: nói rõ chỉ gồm tệp của việc đã nạp', (
    tester,
  ) async {
    await pump(tester, truncated: true);

    expect(find.textContaining('500 việc đầu'), findsOneWidget);
  });
}

class _FilesApi implements TasksApi {
  final deletes = <(String, String)>[];

  @override
  Future<Task> deleteAttachment(String taskId, String attachmentId) async {
    deletes.add((taskId, attachmentId));
    return Task.fromJson({'id': taskId, 'title': 'x'});
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
