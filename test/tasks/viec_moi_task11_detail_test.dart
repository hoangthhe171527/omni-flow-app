import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:omni_app/core/error/app_exception.dart';
import 'package:omni_app/core/storage/preferences_store.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/modules/tasks/application/task_controller.dart';
import 'package:omni_app/modules/tasks/application/tasks_providers.dart';
import 'package:omni_app/modules/tasks/data/tasks_api.dart';
import 'package:omni_app/modules/tasks/domain/task.dart';
import 'package:omni_app/modules/tasks/domain/task_copy_request.dart';
import 'package:omni_app/modules/tasks/domain/task_permissions.dart';
import 'package:omni_app/modules/tasks/domain/task_project.dart';
import 'package:omni_app/modules/tasks/domain/task_reminder.dart';
import 'package:omni_app/modules/tasks/presentation/task_detail_page.dart';
import 'package:omni_app/modules/tasks/presentation/widgets/reminder_sheet.dart';
import 'package:omni_app/modules/tasks/presentation/widgets/task_detail/copy_task_sheet.dart';
import 'package:omni_app/modules/tasks/presentation/widgets/task_detail/comment_bar.dart';
import 'package:omni_app/modules/team/team.dart';
import 'package:omni_app/security/permissions/access_policy.dart';
import 'package:omni_app/security/session/api_capabilities.dart';
import 'package:omni_app/security/session/session.dart';
import 'package:omni_app/security/session/session_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Task 11 ở chi tiết việc: việc con đủ trường + kéo thả, sao chép việc, nhắc
/// việc, tệp kèm bình luận. Mỗi mục một cặp: phiên KHÔNG khai khả năng →
/// `findsNothing`; có khai → có nút và gửi đúng. Controller THẬT, TasksApi giả.
void main() {
  setUpAll(() => initializeDateFormatting('vi_VN'));

  const me = 'u9';
  const assigner = {'tasks.read', 'tasks.write', 'tasks.projects.manage.all'};
  const caps = {
    ApiCapability.subtaskFields,
    ApiCapability.checklistMove,
    ApiCapability.taskCopy,
    ApiCapability.taskReminders,
    ApiCapability.commentAttachments,
  };

  Map<String, dynamic> json() => {
    'id': 't1',
    'title': 'YAMAHA U3E',
    'project_id': 'p1',
    'assignee_ids': ['u1'],
    'assignee_names': ['Hằng Ni'],
    'created_by': 'u0',
    'pinned': false,
    'locked': false,
    'checklist': [
      {
        'id': 'c1',
        'title': 'Lấy đàn về xưởng',
        'done': true,
        'description': 'Linh + Rubi',
        'due_date': '2026-10-10',
      },
      {'id': 'c2', 'title': 'Tháo đàn', 'done': false},
      {'id': 'c3', 'title': 'Bộ máy', 'done': false},
    ],
    'comments': [
      {
        'id': 'cm1',
        'body': '',
        'user_id': me,
        'user_name': 'Thợ Hùng',
        'attachments': [
          {
            'id': 'a1',
            'name': 'vet.jpg',
            'type': 'image',
            'user_id': me,
            'url': 'https://x.test/vet.jpg',
          },
        ],
      },
    ],
  };

  late _Api api;

  Future<void> pump(
    WidgetTester t, {
    Set<String> apiCaps = caps,
    Map<String, dynamic>? data,
    bool motion = true,
    TaskProject project = const TaskProject(ownerId: 'u0'),
  }) async {
    t.view.physicalSize = const Size(390, 1400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async => null,
    );
    api = _Api(data ?? json())..proj = project;
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          taskRealtimeSignalProvider.overrideWith(_Silent.new),
          tasksApiProvider.overrideWithValue(api),
          planCustomFieldsProvider.overrideWith((ref, id) async => const []),
          taskLabelsProvider.overrideWith((ref) async => const []),
          teamDirectoryProvider.overrideWith(
            (ref) async => const [
              TeamMember(membershipId: 'm1', userId: 'u1', name: 'Hằng Ni'),
            ],
          ),
          taskAccessProvider.overrideWithValue(
            TaskAccess.of(AccessPolicy(assigner)),
          ),
          sessionProvider.overrideWithValue(
            Session(
              status: SessionStatus.authenticated,
              user: const SessionUser(
                id: me,
                fullName: 'Thợ Hùng',
                email: 'h@t.vn',
              ),
              apiCapabilities: apiCaps,
            ),
          ),
        ],
        child: MaterialApp(
          theme: OmniTheme.light(TargetPlatform.android),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: !motion),
            child: child!,
          ),
          home: const TaskDetailPage(taskId: 't1'),
        ),
      ),
    );
    await t.pumpAndSettle();
  }

  Future<void> openMenu(WidgetTester t) async {
    await t.tap(find.byTooltip('Tuỳ chọn công việc'));
    await t.pumpAndSettle();
  }

  testWidgets('phiên KHÔNG khai khả năng: không tay kéo, không nút Hạn, '
      'không Nhắc / Sao chép, không nút ảnh, sheet tạo không mô tả / ngày', (
    t,
  ) async {
    await pump(t, apiCaps: const {});
    expect(find.bySemanticsLabel('Kéo để sắp xếp'), findsNothing);
    expect(find.bySemanticsLabel('Đặt hạn việc con'), findsNothing);
    expect(find.byTooltip('Đính kèm ảnh hoặc tệp'), findsNothing);
    await openMenu(t);
    expect(find.text('Nhắc việc'), findsNothing);
    expect(find.text('Sao chép công việc'), findsNothing);
    await t.tapAt(const Offset(10, 10));
    await t.pumpAndSettle();
    await t.tap(find.byTooltip('Thêm việc con'));
    await t.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('subtask-create-description')),
      findsNothing,
    );
    expect(find.text('Tuần sau'), findsNothing);
    expect(find.text('Ngày bắt đầu'), findsNothing);
  });

  testWidgets('có khả năng: tay kéo 24×44 mỗi dòng, ghi chú 13, nút "Hạn" '
      'nét đứt cho việc con chưa có hạn', (t) async {
    await pump(t);
    expect(find.bySemanticsLabel('Kéo để sắp xếp'), findsNWidgets(3));
    expect(
      t.getSize(find.byKey(const ValueKey('subtask-drag-handle')).first),
      const Size(24, 44),
    );
    expect(find.text('Linh + Rubi'), findsOneWidget);
    expect(t.widget<Text>(find.text('Linh + Rubi')).style?.fontSize, 13);
    expect(find.bySemanticsLabel('Đặt hạn việc con'), findsNWidgets(2));
    expect(find.bySemanticsLabel('Đổi hạn việc con'), findsOneWidget);
  });

  testWidgets('nút Hạn: chọn ngày → PATCH due_date của đúng việc con', (
    t,
  ) async {
    await pump(t);
    await t.tap(find.bySemanticsLabel('Đặt hạn việc con').first);
    await t.pumpAndSettle();
    await t.tap(find.text('OK'));
    await t.pumpAndSettle();
    expect(api.calls.last.$1, 'due');
    expect(api.calls.last.$2, ('c2', DateUtils.dateOnly(DateTime.now())));
  });

  testWidgets('sheet tạo đủ trường: mô tả, chip "Tuần sau" (+7, nền '
      '#E6F3F2) → MỘT POST mang mọi trường', (t) async {
    await pump(t);
    await t.tap(find.byTooltip('Thêm việc con'));
    await t.pumpAndSettle();
    await t.enterText(find.widgetWithText(TextField, 'Tên việc con'), 'Nỉ');
    await t.enterText(
      find.byKey(const ValueKey('subtask-create-description')),
      'Nỉ đỏ',
    );
    await t.tap(find.text('Tuần sau'));
    await t.pumpAndSettle();
    final chip = t.widget<Container>(
      find.byKey(const ValueKey('quick-chip-Tuần sau')),
    );
    expect((chip.decoration! as BoxDecoration).color, const Color(0xFFE6F3F2));
    expect(
      t.getSize(find.byKey(const ValueKey('quick-chip-Tuần sau'))).height,
      36,
    );
    final due = DateUtils.dateOnly(DateTime.now()).add(const Duration(days: 7));
    expect(find.textContaining('Hạn '), findsWidgets);
    await t.tap(find.text('Tạo'));
    await t.pumpAndSettle();
    expect(api.calls.last, ('create', ('Nỉ', 'Nỉ đỏ', null, due, null)));
  });

  testWidgets('kéo dòng 3 lên đầu: POST move after_id null, thứ tự đổi ngay; '
      'lỗi thì trả thứ tự cũ và báo', (t) async {
    await pump(t);
    Future<void> dragThirdToTop() async {
      final handle = find.byKey(const ValueKey('subtask-drag-handle')).at(2);
      final g = await t.startGesture(t.getCenter(handle));
      await t.pump(const Duration(milliseconds: 50));
      for (var i = 0; i < 20; i++) {
        await g.moveBy(const Offset(0, -20));
        await t.pump(const Duration(milliseconds: 16));
      }
      await g.up();
      await t.pumpAndSettle();
    }

    api.failMove = true;
    await dragThirdToTop();
    expect(api.calls.last, ('move', ('c3', null)));
    expect(find.text('Không đổi được.'), findsOneWidget);
    final y1 = t.getTopLeft(find.text('Bộ máy')).dy;
    expect(y1, greaterThan(t.getTopLeft(find.text('Tháo đàn')).dy));

    api.failMove = false;
    await dragThirdToTop();
    expect(api.calls.last, ('move', ('c3', null)));
    expect(
      t.getTopLeft(find.text('Bộ máy')).dy,
      lessThan(t.getTopLeft(find.text('Lấy đàn về xưởng')).dy),
    );
  });

  testWidgets('Sao chép công việc: sheet mới, Sao chép → POST copy, SnackBar '
      '"Đã tạo bản sao trong …" + "Mở" mở việc mới', (t) async {
    await pump(t);
    await openMenu(t);
    expect(find.text('Nhắc việc'), findsOneWidget);
    await t.tap(find.text('Sao chép công việc'));
    await t.pumpAndSettle();
    expect(find.byType(CopyTaskSheet), findsOneWidget);
    expect(find.text('YAMAHA U3E (bản sao)'), findsOneWidget);
    await t.tap(find.widgetWithText(FilledButton, 'Sao chép'));
    await t.pumpAndSettle();
    expect(api.calls, contains(('copy', 'YAMAHA U3E (bản sao)')));
    // Việc gốc chưa xếp nhóm, ô nhóm không đụng → không gửi section_id.
    expect(api.copyBodies.single, {
      'title': 'YAMAHA U3E (bản sao)',
      'project_id': 'p1',
      'keep_assignees': true,
      'keep_checklist': true,
    });
    // Không tự mở việc mới (R15): chỉ mở khi bấm "Mở".
    expect(api.gets, isNot(contains('t2')));
    expect(find.text('Đã tạo bản sao trong “Tân trang”.'), findsOneWidget);
    await t.tap(find.widgetWithText(SnackBarAction, 'Mở'));
    await t.pumpAndSettle();
    expect(api.gets, contains('t2'));
  });

  testWidgets('422 section_id → SnackBar câu server cho khoá section_id', (
    t,
  ) async {
    await pump(t);
    api.copyError = const ValidationException(
      'Dữ liệu không hợp lệ.',
      errors: {
        'section_id': ['Nhóm việc không thuộc kế hoạch đích.'],
      },
    );
    await openMenu(t);
    await t.tap(find.text('Sao chép công việc'));
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(FilledButton, 'Sao chép'));
    await t.pumpAndSettle();
    expect(
      find.text(
        'Nhóm việc không thuộc kế hoạch đích. Mở lại "Sao chép" để chọn nhóm khác.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Đã tạo bản sao'), findsNothing);
  });

  testWidgets('bình luận có ảnh kèm: hiện ô 72; bấm giữ ảnh của mình → Gỡ '
      'tệp → DELETE …/comments/cm1/attachments/a1', (t) async {
    await pump(t);
    final thumb = find.byKey(const ValueKey('comment-file-a1'));
    expect(thumb, findsOneWidget);
    expect(t.getSize(thumb), const Size(72, 72));
    await t.ensureVisible(thumb);
    await t.longPress(thumb);
    await t.pumpAndSettle();
    await t.tap(find.text('Gỡ tệp').last);
    await t.pumpAndSettle();
    await t.tap(find.text('Gỡ tệp').last);
    await t.pumpAndSettle();
    expect(api.calls.last, ('uncomment-file', ('cm1', 'a1')));
  });

  Future<void> subMenu(WidgetTester t, int row, String item) async {
    await t.tap(find.byTooltip('Tuỳ chọn việc con').at(row));
    await t.pumpAndSettle();
    await t.tap(find.text(item));
    await t.pumpAndSettle();
  }

  testWidgets('tắt chuyển động: không ReorderableListView, sắp xếp bằng ⋮ '
      '"Chuyển lên" / "Chuyển xuống"', (t) async {
    await pump(t, motion: false);
    expect(find.byType(ReorderableListView), findsNothing);
    expect(find.bySemanticsLabel('Kéo để sắp xếp'), findsNothing);
    await subMenu(t, 2, 'Chuyển lên');
    expect(api.calls.last, ('move', ('c3', 'c1')));
    expect(
      t.getTopLeft(find.text('Bộ máy')).dy,
      lessThan(t.getTopLeft(find.text('Tháo đàn')).dy),
    );

    // Dòng đầu không có "Chuyển lên"; dòng cuối không có "Chuyển xuống".
    await t.tap(find.byTooltip('Tuỳ chọn việc con').first);
    await t.pumpAndSettle();
    expect(find.text('Chuyển lên'), findsNothing);
    expect(find.text('Chuyển xuống'), findsOneWidget);
    await t.tap(find.text('Chuyển xuống'));
    await t.pumpAndSettle();
    expect(api.calls.last, ('move', ('c1', 'c3')));
    await t.tap(find.byTooltip('Tuỳ chọn việc con').last);
    await t.pumpAndSettle();
    expect(find.text('Chuyển xuống'), findsNothing);
    expect(find.text('Chuyển lên'), findsOneWidget);
  });

  testWidgets('bật chuyển động: ⋮ vẫn có "Chuyển lên" — đường trợ năng', (
    t,
  ) async {
    await pump(t);
    expect(find.byType(ReorderableListView), findsOneWidget);
    await subMenu(t, 1, 'Chuyển lên');
    expect(api.calls.last, ('move', ('c2', null)));
  });

  testWidgets('không có quyền sắp xếp: ⋮ không có "Chuyển lên"', (t) async {
    await pump(t, apiCaps: caps.difference({ApiCapability.checklistMove}));
    await t.tap(find.byTooltip('Tuỳ chọn việc con').at(1));
    await t.pumpAndSettle();
    expect(find.text('Chuyển lên'), findsNothing);
    expect(find.text('Chuyển xuống'), findsNothing);
  });

  testWidgets('sao chép: tên gốc dài cắt còn 244 ký tự trước " (bản sao)" '
      '(server max:255)', (t) async {
    final long = 'Đ' * 255;
    await pump(t, data: {...json(), 'title': long});
    await openMenu(t);
    await t.tap(find.text('Sao chép công việc'));
    await t.pumpAndSettle();
    final field = t.widget<TextField>(
      find.descendant(
        of: find.byType(CopyTaskSheet),
        matching: find.byType(TextField),
      ),
    );
    final text = field.controller!.text;
    expect(text, '${'Đ' * 244} (bản sao)');
    expect(text.length, lessThanOrEqualTo(255));
    expect(field.maxLength, 255);
  });

  testWidgets(
    'người xem kế hoạch: ⋯ chỉ có "Nhắc việc" và "Sao chép liên kết"',
    (t) async {
      await pump(
        t,
        project: const TaskProject(ownerId: 'u0', memberRoles: {me: 'viewer'}),
      );
      await openMenu(t);
      expect(find.text('Nhắc việc'), findsOneWidget);
      expect(find.text('Sao chép liên kết'), findsOneWidget);
      expect(find.text('Sao chép công việc'), findsNothing);
      expect(find.text('Đổi tên việc'), findsNothing);
    },
  );

  testWidgets('mô tả việc con tối đa 2000 (tạo và sửa); mô tả việc theo '
      'server (10000)', (t) async {
    await pump(t);
    await subMenu(t, 1, 'Thêm mô tả');
    expect(t.widget<TextField>(find.byType(TextField).last).maxLength, 2000);
    await t.tapAt(const Offset(10, 10));
    await t.pumpAndSettle();
    await t.tap(find.byTooltip('Thêm việc con'));
    await t.pumpAndSettle();
    expect(
      t
          .widget<TextField>(
            find.byKey(const ValueKey('subtask-create-description')),
          )
          .maxLength,
      2000,
    );
    await t.tapAt(const Offset(10, 10));
    await t.pumpAndSettle();
    await t.tap(find.byTooltip('Sửa mô tả'));
    await t.pumpAndSettle();
    expect(t.widget<TextField>(find.byType(TextField).last).maxLength, 10000);
  });

  testWidgets('đang tạo việc con: nút × xoá ngày bị tắt', (t) async {
    await pump(t);
    await t.tap(find.byTooltip('Thêm việc con'));
    await t.pumpAndSettle();
    await t.enterText(find.widgetWithText(TextField, 'Tên việc con'), 'Nỉ');
    await t.tap(find.text('Tuần sau'));
    await t.pumpAndSettle();
    final clear = find.ancestor(
      of: find.byTooltip('Xoá hạn'),
      matching: find.byType(IconButton),
    );
    expect(t.widget<IconButton>(clear).onPressed, isNotNull);
    api.gate = Completer<void>();
    await t.tap(find.text('Tạo'));
    await t.pump();
    expect(t.widget<IconButton>(clear).onPressed, isNull);
    api.gate!.complete();
    await t.pumpAndSettle();
  });

  group('ô bình luận kèm tệp', () {
    Future<void> host(
      WidgetTester t,
      CommentFilePicker pick, {
      bool canAttach = true,
    }) async {
      api = _Api(json());
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await t.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            taskRealtimeSignalProvider.overrideWith(_Silent.new),
            tasksApiProvider.overrideWithValue(api),
          ],
          child: MaterialApp(
            theme: OmniTheme.light(TargetPlatform.android),
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) {
                  final task = ref
                      .watch(taskDetailProvider('t1'))
                      .valueOrNull
                      ?.task;
                  if (task == null) return const SizedBox();
                  return Align(
                    alignment: Alignment.bottomCenter,
                    child: CommentBar(
                      task: task,
                      taskId: 't1',
                      canAttachFiles: canAttach,
                      pickFiles: pick,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
    }

    CommentUpload file(int i, {int? size = 1000}) => CommentUpload(
      path: '/khong/co/$i.jpg',
      name: '$i.jpg',
      isImage: true,
      size: size,
    );

    testWidgets('không khả năng → không nút ảnh', (t) async {
      await host(t, (_, _) async => const [], canAttach: false);
      expect(find.byTooltip('Đính kèm ảnh hoặc tệp'), findsNothing);
    });

    testWidgets('chọn 2 ảnh → xem trước; thân rỗng vẫn gửi được; gửi '
        'multipart rồi dọn', (t) async {
      CommentFileSource? asked;
      await host(t, (source, remaining) async {
        asked = source;
        expect(remaining, 10);
        return [file(1), file(2)];
      });
      expect(
        t.getSize(find.byTooltip('Đính kèm ảnh hoặc tệp')),
        const Size(44, 44),
      );
      await t.tap(find.byTooltip('Đính kèm ảnh hoặc tệp'));
      await t.pumpAndSettle();
      expect(
        find.byKey(const Key('comment-attachment-source-menu')),
        findsOneWidget,
      );
      await t.tap(find.text('Chọn ảnh có sẵn'));
      await t.pumpAndSettle();
      expect(asked, CommentFileSource.gallery);
      expect(find.bySemanticsLabel('Tệp đính kèm: 1.jpg'), findsOneWidget);
      expect(find.bySemanticsLabel('Tệp đính kèm: 2.jpg'), findsOneWidget);

      await t.tap(find.byTooltip('Bỏ 2.jpg'));
      await t.pumpAndSettle();
      expect(find.bySemanticsLabel('Tệp đính kèm: 2.jpg'), findsNothing);

      await t.tap(find.byTooltip('Gửi bình luận'));
      await t.pumpAndSettle();
      final sent = api.calls.last;
      expect(sent.$1, 'comment-files');
      final (body, names) = sent.$2! as (String, List<String>);
      expect(body, '');
      expect(names, ['1.jpg']);
      expect(find.byKey(const ValueKey('comment-files-preview')), findsNothing);
    });

    testWidgets('quá 10 tệp hoặc tệp >25MB: bỏ phần vượt và báo', (t) async {
      await host(t, (_, _) async => [for (var i = 0; i < 11; i++) file(i)]);
      await t.tap(find.byTooltip('Đính kèm ảnh hoặc tệp'));
      await t.pumpAndSettle();
      await t.tap(find.text('Chọn tệp'));
      await t.pumpAndSettle();
      expect(find.text('Tối đa 10 tệp mỗi bình luận.'), findsOneWidget);
      t
          .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger))
          .hideCurrentSnackBar();
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('Gửi bình luận'));
      await t.pumpAndSettle();
      final sent = (api.calls.last.$2! as (String, List<String>)).$2;
      expect(sent, hasLength(10));
    });

    testWidgets('cả lượt tối đa 60MB; tệp không rõ cỡ tính như 25MB', (
      t,
    ) async {
      const mb = 1024 * 1024;
      await host(
        t,
        (_, _) async => [
          file(1, size: 20 * mb),
          file(2, size: 20 * mb),
          file(3, size: 21 * mb),
          file(4, size: null),
          file(5, size: 15 * mb),
        ],
      );
      await t.tap(find.byTooltip('Đính kèm ảnh hoặc tệp'));
      await t.pumpAndSettle();
      await t.tap(find.text('Chọn tệp'));
      await t.pumpAndSettle();
      expect(find.text('Cả lượt gửi tối đa 60MB.'), findsOneWidget);
      expect(find.bySemanticsLabel('Tệp đính kèm: 3.jpg'), findsNothing);
      expect(find.bySemanticsLabel('Tệp đính kèm: 4.jpg'), findsNothing);
      expect(find.bySemanticsLabel('Tệp đính kèm: 5.jpg'), findsOneWidget);
    });

    testWidgets('tệp lớn hơn 25MB bị từ chối', (t) async {
      await host(t, (_, _) async => [file(1, size: 26 * 1024 * 1024)]);
      await t.tap(find.byTooltip('Đính kèm ảnh hoặc tệp'));
      await t.pumpAndSettle();
      await t.tap(find.text('Chụp ảnh'));
      await t.pumpAndSettle();
      expect(find.text('“1.jpg” lớn hơn 25MB.'), findsOneWidget);
      expect(find.byKey(const ValueKey('comment-files-preview')), findsNothing);
    });
  });

  group('sheet Nhắc việc', () {
    Future<void> open(
      WidgetTester t, {
      required DateTime? pickAt,
      bool canEveryone = true,
      bool canManage = false,
      List<Map<String, dynamic>> reminders = const [],
    }) async {
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      api = _Api(json())..reminderRows = [...reminders];
      await t.pumpWidget(
        ProviderScope(
          overrides: [tasksApiProvider.overrideWithValue(api)],
          child: MaterialApp(
            theme: OmniTheme.light(TargetPlatform.android),
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showReminderSheet(
                    context,
                    taskId: 't1',
                    myUserId: me,
                    canEveryone: canEveryone,
                    canManage: canManage,
                    pick: (_) async => pickAt,
                  ),
                  child: const Text('mở'),
                ),
              ),
            ),
          ),
        ),
      );
      await t.tap(find.text('mở'));
      await t.pumpAndSettle();
    }

    testWidgets('liệt kê; thêm "Mọi người trong việc" → POST audience '
        'everyone; giờ đã qua thì báo, không gửi', (t) async {
      final at = DateTime.now().add(const Duration(hours: 2));
      await open(t, pickAt: at);
      expect(find.text('Chưa có lời nhắc nào.'), findsOneWidget);
      await t.tap(find.text('Mọi người trong việc'));
      await t.pumpAndSettle();
      await t.tap(find.text('Thêm lời nhắc'));
      await t.pumpAndSettle();
      expect(api.calls.last, ('remind', (at, true)));
      expect(find.byKey(const ValueKey('reminder-r1')), findsOneWidget);
    });

    testWidgets('giờ đã qua: báo, không gửi', (t) async {
      await open(
        t,
        pickAt: DateTime.now().subtract(const Duration(minutes: 5)),
      );
      await t.tap(find.text('Thêm lời nhắc'));
      await t.pumpAndSettle();
      expect(find.text('Chọn một thời điểm sau bây giờ.'), findsOneWidget);
      expect(api.calls.where((c) => c.$1 == 'remind'), isEmpty);
    });

    testWidgets('đóng sheet khi lượt thêm còn chờ: không đụng ref đã huỷ', (
      t,
    ) async {
      await open(t, pickAt: DateTime.now().add(const Duration(hours: 2)));
      api.gate = Completer<void>();
      await t.tap(find.text('Thêm lời nhắc'));
      await t.pump();
      Navigator.of(t.element(find.text('Thêm lời nhắc'))).pop();
      await t.pumpAndSettle();
      expect(find.text('Thêm lời nhắc'), findsNothing);
      api.gate!.complete();
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(api.calls.last.$1, 'remind');
    });

    testWidgets('xoá: lời nhắc của mình có ×; "everyone" của người khác '
        'không (trừ khi quản lý); không chọn được "mọi người" nếu không sửa '
        'được việc', (t) async {
      final rows = [
        {
          'id': 'r1',
          'remind_at': '2026-12-01T01:00:00Z',
          'audience': 'me',
          'status': 'pending',
          'created_by': me,
        },
        {
          'id': 'r2',
          'remind_at': '2026-12-02T01:00:00Z',
          'audience': 'everyone',
          'status': 'pending',
          'created_by': 'u0',
          'created_by_name': 'Trần Hưng',
        },
      ];
      await open(t, pickAt: null, canEveryone: false, reminders: rows);
      expect(find.text('Mọi người trong việc'), findsNothing);
      expect(find.byTooltip('Xoá lời nhắc'), findsOneWidget);
      await t.tap(find.byTooltip('Xoá lời nhắc'));
      await t.pumpAndSettle();
      expect(api.calls.last, ('unremind', 'r1'));
      expect(find.byKey(const ValueKey('reminder-r1')), findsNothing);
    });
  });
}

class _Api implements TasksApi {
  _Api(this._json);

  Map<String, dynamic> _json;
  final calls = <(String, Object?)>[];
  final gets = <String>[];
  bool failMove = false;
  List<Map<String, dynamic>> reminderRows = [];
  Completer<void>? gate;
  TaskProject proj = const TaskProject(ownerId: 'u0');
  final copyBodies = <Map<String, dynamic>>[];
  AppException? copyError;

  Task _with(Map<String, dynamic> patch) {
    _json = {..._json, ...patch};
    return Task.fromJson(_json);
  }

  List<Map<String, dynamic>> get _checklist => [
    for (final c in _json['checklist'] as List) Map<String, dynamic>.of(c),
  ];

  @override
  Future<Task> get(String id) async {
    gets.add(id);
    return Task.fromJson({..._json, 'id': id});
  }

  @override
  Future<TaskProject> project(String projectId) async => proj;

  @override
  Future<Task> createSubtask(
    String taskId, {
    required String title,
    String? description,
    DateTime? startDate,
    DateTime? dueDate,
    String? assigneeId,
  }) async {
    calls.add(('create', (title, description, startDate, dueDate, assigneeId)));
    await gate?.future;
    return _with({
      'checklist': [
        ..._checklist,
        {'id': 'c9', 'title': title, 'done': false},
      ],
    });
  }

  @override
  Future<Task> setSubtaskDueDate(
    String taskId,
    String subtaskId,
    DateTime? dueDate,
  ) async {
    calls.add(('due', (subtaskId, dueDate)));
    return _with({});
  }

  @override
  Future<Task> moveSubtask(
    String taskId,
    String subtaskId, {
    required String? afterId,
  }) async {
    calls.add(('move', (subtaskId, afterId)));
    if (failMove) {
      throw const RequestRejectedException('Không đổi được.', code: '422');
    }
    final list = _checklist;
    final item = list.firstWhere((c) => c['id'] == subtaskId);
    list.remove(item);
    final at = afterId == null
        ? 0
        : list.indexWhere((c) => c['id'] == afterId) + 1;
    list.insert(at, item);
    return _with({'checklist': list});
  }

  @override
  Future<List<MovablePlan>> projectsForMove() async => [
    (
      id: 'p1',
      name: 'Tân trang',
      teamId: 'T1',
      teamName: 'Xưởng',
      ownerId: null,
      memberRoles: const {},
      sections: const [
        TaskSection(id: 's1', name: 'Khách khác'),
        TaskSection(id: 's2', name: 'Thiện Piano'),
      ],
    ),
  ];

  @override
  Future<Task> copyTask(String taskId, TaskCopyRequest request) async {
    calls.add(('copy', request.title));
    copyBodies.add(request.toJson());
    if (copyError case final e?) throw e;
    return Task.fromJson({..._json, 'id': 't2', 'title': request.title});
  }

  @override
  Future<List<TaskReminder>> reminders(String taskId) async =>
      reminderRows.map(TaskReminder.fromJson).toList();

  @override
  Future<TaskReminder> addReminder(
    String taskId,
    DateTime at, {
    bool everyone = false,
  }) async {
    calls.add(('remind', (at, everyone)));
    await gate?.future;
    final row = {
      'id': 'r1',
      'remind_at': at.toUtc().toIso8601String(),
      'audience': everyone ? 'everyone' : 'me',
      'status': 'pending',
      'created_by': 'u9',
    };
    reminderRows.add(row);
    return TaskReminder.fromJson(row);
  }

  @override
  Future<void> deleteReminder(String taskId, String reminderId) async {
    calls.add(('unremind', reminderId));
    reminderRows.removeWhere((r) => r['id'] == reminderId);
  }

  @override
  Future<Task> commentWithFiles(
    String taskId,
    String body, {
    List<String> mentionedUserIds = const [],
    required List<CommentUpload> files,
  }) async {
    calls.add(('comment-files', (body, [for (final f in files) f.name])));
    return _with({});
  }

  @override
  Future<Task> deleteCommentAttachment(
    String taskId,
    String commentId,
    String attachmentId,
  ) async {
    calls.add(('uncomment-file', (commentId, attachmentId)));
    return _with({});
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Silent extends TaskRealtimeSignal {
  @override
  int build() => 0;
}
