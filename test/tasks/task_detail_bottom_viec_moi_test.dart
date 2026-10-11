import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/modules/customers/domain/customer_permissions.dart';
import 'package:omni_app/modules/customers/routes.dart';
import 'package:omni_app/modules/tasks/application/task_controller.dart';
import 'package:omni_app/modules/tasks/application/tasks_providers.dart';
import 'package:omni_app/modules/tasks/domain/custom_field.dart';
import 'package:omni_app/modules/tasks/domain/task.dart';
import 'package:omni_app/modules/tasks/domain/task_permissions.dart';
import 'package:omni_app/modules/tasks/presentation/task_detail_page.dart';
import 'package:omni_app/modules/team/team.dart';
import 'package:omni_app/security/permissions/access_policy.dart';
import 'package:omni_app/security/session/session.dart';
import 'package:omni_app/security/session/session_controller.dart';

/// Nửa dưới màn chi tiết việc theo `TaskDetail.dc.html` / `TaskSubtasks`
/// (Việc mới, Task 9): trường tuỳ chỉnh (cả dòng Khách), việc con có thanh
/// tiến độ, tệp có xoá, bình luận có xoá, ô bình luận đáy, nhật ký + đã xem.
void main() {
  setUpAll(() => initializeDateFormatting('vi_VN'));

  const worker = {'tasks.read', 'tasks.write'};
  const assigner = {'tasks.read', 'tasks.write', 'tasks.projects.manage.all'};
  const me = 'u9';

  const fields = [
    CustomFieldDef(id: 'f_hang', name: 'Hãng'),
    CustomFieldDef(id: 'f_serial', name: 'Serial'),
    CustomFieldDef(id: 'f_mau', name: 'Màu sắc'),
  ];

  late List<(String, Object?)> recorded;
  late _Detail stub;

  Map<String, dynamic> json({
    List<Map<String, dynamic>> checklist = const [],
    Map<String, dynamic> custom = const {},
    String? customerId,
    String? customerName,
    List<Map<String, dynamic>> attachments = const [],
    List<Map<String, dynamic>> comments = const [],
    List<Map<String, dynamic>> viewers = const [],
  }) => {
    'id': 't1',
    'title': 'YAMAHA U3E 592698',
    'status': 'todo',
    'project_id': 'p1',
    'project_name': 'Tân trang',
    'assignee_ids': ['u1', 'u2'],
    'assignee_names': ['Khánh', 'Trung Nguyên'],
    'checklist': checklist,
    'custom_fields': custom,
    'customer_id': ?customerId,
    'customer_name': ?customerName,
    'attachments': attachments,
    'comments': comments,
    'comments_count': comments.length,
    'viewers': viewers,
  };

  Widget host({
    required Map<String, dynamic> data,
    Set<String> perms = assigner,
    List<CustomFieldDef> defs = fields,
    bool reduceMotion = false,
  }) {
    recorded = [];
    stub = _Detail(TaskDetailState(task: Task.fromJson(data)), recorded);

    return ProviderScope(
      overrides: [
        taskDetailProvider.overrideWith(() => stub),
        planCustomFieldsProvider.overrideWith((ref, id) async => defs),
        taskLabelsProvider.overrideWith((ref) async => const []),
        teamDirectoryProvider.overrideWith(
          (ref) async => [
            TeamMember(membershipId: 'm1', userId: 'u1', name: 'Khánh'),
          ],
        ),
        projectMembersProvider.overrideWith(
          (ref, id) async => [
            TeamMember(membershipId: 'm1', userId: 'u1', name: 'Khánh'),
            TeamMember(membershipId: 'm2', userId: 'u3', name: 'Linh'),
          ],
        ),
        taskAccessProvider.overrideWithValue(
          TaskAccess.of(AccessPolicy(perms)),
        ),
        sessionProvider.overrideWithValue(
          const Session(
            status: SessionStatus.authenticated,
            user: SessionUser(id: me, fullName: 'Thợ Hùng', email: 'h@t.vn'),
          ),
        ),
      ],
      child: MaterialApp(
        theme: OmniTheme.light(TargetPlatform.android),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(disableAnimations: reduceMotion),
          child: child!,
        ),
        home: const TaskDetailPage(taskId: 't1'),
      ),
    );
  }

  Future<void> pump(WidgetTester t, Widget app) async {
    t.view.physicalSize = const Size(390, 1600);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async => null,
    );
    await t.pumpWidget(app);
    await t.pumpAndSettle();
  }

  void tw(String name, Future<void> Function(WidgetTester t) body) {
    testWidgets(name, (t) async {
      final handle = t.ensureSemantics();
      try {
        await body(t);
      } finally {
        handle.dispose();
      }
    });
  }

  group('(a)(b) trường tuỳ chỉnh', () {
    tw('hiện giá trị; sửa "Màu sắc" gửi map đủ ba khoá', (t) async {
      await pump(
        t,
        host(data: json(custom: {'f_hang': 'Yamaha', 'f_serial': '592698'})),
      );
      expect(find.text('Trường tuỳ chỉnh'), findsOneWidget);
      expect(find.text('Yamaha'), findsOneWidget);
      expect(find.text('592698'), findsOneWidget);
      // Chưa có giá trị: placeholder mờ "Nhập …".
      expect(find.text('Nhập màu sắc'), findsOneWidget);
      final row = find.byKey(const ValueKey('custom-field-f_mau'));
      expect(t.getSize(row).height, greaterThanOrEqualTo(48));

      await t.tap(find.text('Nhập màu sắc'));
      await t.pumpAndSettle();
      await t.enterText(
        find.byWidgetPredicate((w) => w is TextField && w.autofocus),
        'Đen bóng',
      );
      await t.pump();
      await t.tap(find.text('Lưu'));
      await t.pumpAndSettle();

      expect(recorded.last, ('customField', ('f_mau', 'Đen bóng')));
      // Map ghi ĐÃ GỘP: hai trường cũ vẫn còn.
      expect(stub.lastFields, {
        'f_hang': 'Yamaha',
        'f_serial': '592698',
        'f_mau': 'Đen bóng',
      });
    });

    tw('kế hoạch không có trường nào (và không có khách): không có thẻ', (
      t,
    ) async {
      await pump(t, host(data: json(), defs: const []));
      expect(find.text('Trường tuỳ chỉnh'), findsNothing);
    });

    tw('chỉ đọc: chạm trường không mở gì', (t) async {
      await pump(
        t,
        host(
          data: json(custom: {'f_hang': 'Yamaha'}),
          perms: {'tasks.read'},
        ),
      );
      await t.tap(find.text('Yamaha'));
      await t.pumpAndSettle();
      expect(find.text('Lưu'), findsNothing);
    });

    tw('dòng Khách: tên khách khi tài liệu có customer_name', (t) async {
      await pump(
        t,
        host(
          data: json(customerId: 'c1', customerName: 'Đặng Hoài Bảo'),
          defs: const [],
        ),
      );
      expect(find.text('Khách'), findsOneWidget);
      expect(find.text('Đặng Hoài Bảo'), findsOneWidget);
    });

    tw('dòng Khách không có tên: "Xem hồ sơ khách"', (t) async {
      await pump(
        t,
        host(
          data: json(customerId: 'c1'),
          defs: const [],
        ),
      );
      expect(find.text('Xem hồ sơ khách'), findsOneWidget);
    });

    tw('không có customer_id: không có dòng Khách', (t) async {
      await pump(t, host(data: json()));
      expect(find.text('Khách'), findsNothing);
    });

    test('quyền mở hồ sơ khách là bản sao đúng của CustomerPermissions', () {
      expect(TaskPermissions.openCustomer, CustomerPermissions.anyRead);
    });
  });

  group('Khách → hồ sơ khách', () {
    Widget routed(Set<String> perms) {
      final task = Task.fromJson(
        json(customerId: 'c1', customerName: 'Đặng Hoài Bảo'),
      );
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const TaskDetailPage(taskId: 't1'),
          ),
          GoRoute(
            path: '/customers/:id',
            name: CustomerRoutes.detail,
            builder: (_, state) => Text('hồ sơ ${state.pathParameters['id']}'),
          ),
        ],
      );

      return ProviderScope(
        overrides: [
          taskDetailProvider.overrideWith(
            () => _Detail(TaskDetailState(task: task), []),
          ),
          planCustomFieldsProvider.overrideWith((ref, id) async => const []),
          taskLabelsProvider.overrideWith((ref) async => const []),
          accessProvider.overrideWithValue(AccessPolicy(perms)),
          taskAccessProvider.overrideWithValue(
            TaskAccess.of(AccessPolicy(perms)),
          ),
        ],
        child: MaterialApp.router(
          theme: OmniTheme.light(TargetPlatform.android),
          routerConfig: router,
        ),
      );
    }

    tw('có quyền đọc khách: chạm tên mở CustomerRoutes.detail', (t) async {
      await pump(t, routed({...assigner, 'crm.customers.read.own'}));
      await t.tap(find.text('Đặng Hoài Bảo'));
      await t.pumpAndSettle();
      expect(find.text('hồ sơ c1'), findsOneWidget);
    });

    tw('không có quyền đọc khách: chữ thường, chạm không đi đâu', (t) async {
      await pump(t, routed(assigner));
      await t.tap(find.text('Đặng Hoài Bảo'));
      await t.pumpAndSettle();
      expect(find.textContaining('hồ sơ'), findsNothing);
    });
  });

  group('(c) việc con', () {
    List<Map<String, dynamic>> six() => [
      for (var i = 0; i < 6; i++)
        {
          'id': 'c$i',
          'title': 'Công đoạn $i',
          'done': i < 3,
          if (i == 0) 'assignee_id': 'u1',
          if (i == 0) 'assignee_name': 'Khánh',
          if (i == 1) 'due_date': '2030-10-15',
        },
    ];

    tw('3/6, thanh 50%; ô 22 bo 6; tick gửi như cũ', (t) async {
      await pump(
        t,
        host(
          data: json(checklist: six()),
          perms: worker,
        ),
      );
      expect(find.text('3/6'), findsOneWidget);
      final track = t.getSize(
        find.byKey(const ValueKey('subtask-progress-track')),
      );
      final fill = t.getSize(
        find.byKey(const ValueKey('subtask-progress-fill')),
      );
      expect(track.height, 4);
      expect(fill.width / track.width, closeTo(0.5, 0.01));

      final box = find.byKey(const ValueKey('subtask-tick-box')).last;
      expect(t.getSize(box), const Size(22, 22));
      final deco = t.widget<Container>(box).decoration! as BoxDecoration;
      expect(deco.borderRadius, BorderRadius.circular(6));

      await t.tap(find.bySemanticsLabel('Đánh dấu xong việc con').first);
      await t.pump();
      expect(recorded.last, ('toggle', ('c3', true)));
    });

    tw('hạn việc con hiện DueChip; Nhóm 2 (Hạn, tay kéo, ghi chú) ẩn', (
      t,
    ) async {
      await pump(t, host(data: json(checklist: six())));
      expect(find.text('Hạn 15/10'), findsOneWidget);
      expect(find.bySemanticsLabel('Đặt hạn việc con'), findsNothing);
      expect(find.bySemanticsLabel('Kéo để sắp xếp'), findsNothing);
      // Người chưa có: nút nét đứt "Người làm" (cao vùng chạm 44).
      final mini = find.bySemanticsLabel('Giao việc con').first;
      expect(t.getSize(mini).height, 44);
    });

    tw('giảm chuyển động: tick không để lại khung hoạt ảnh', (t) async {
      await pump(
        t,
        host(
          data: json(checklist: six()),
          perms: worker,
          reduceMotion: true,
        ),
      );
      await t.tap(find.bySemanticsLabel('Đánh dấu xong việc con').first);
      await t.pump();
      expect(t.hasRunningAnimations, isFalse);
    });
  });

  group('(f) tệp', () {
    final files = [
      {
        'id': 'a1',
        'name': 'truoc.jpg',
        'url': 'https://api.local/m/1.jpg',
        'type': 'file',
      },
      {
        'id': 'a2',
        'name': 'Báo giá.pdf',
        'url': 'https://api.local/m/2.pdf',
        'type': 'file',
      },
    ];

    tw('bấm giữ ô, Xoá tệp, xác nhận: deleteAttachment(a1)', (t) async {
      await pump(
        t,
        host(
          data: json(attachments: files),
          perms: worker,
        ),
      );
      expect(
        t.getSize(find.byKey(const ValueKey('file-a1'))),
        const Size(72, 72),
      );
      await t.longPress(find.byKey(const ValueKey('file-a1')));
      await t.pumpAndSettle();
      await t.tap(find.text('Xoá tệp'));
      await t.pumpAndSettle();
      await t.tap(find.text('Xoá tệp').last);
      await t.pumpAndSettle();
      expect(recorded.last, ('deleteAttachment', 'a1'));
    });

    tw('chỉ đọc: bấm giữ không mở gì', (t) async {
      await pump(
        t,
        host(
          data: json(attachments: files),
          perms: {'tasks.read'},
        ),
      );
      await t.longPress(find.byKey(const ValueKey('file-a1')));
      await t.pumpAndSettle();
      expect(find.text('Xoá tệp'), findsNothing);
    });
  });

  group('(g) bình luận', () {
    final comments = [
      {
        'id': 'k1',
        'body': 'Của tôi',
        'user_id': me,
        'user_name': 'Thợ Hùng',
        'created_at': '2026-09-11T07:00:00Z',
      },
      {
        'id': 'k2',
        'body': 'Của người khác',
        'user_id': 'u1',
        'user_name': 'Khánh',
        'created_at': '2026-09-11T07:05:00Z',
      },
    ];

    tw('thợ: bấm giữ bình luận của mình → Xoá; của người khác → không có', (
      t,
    ) async {
      await pump(
        t,
        host(
          data: json(comments: comments),
          perms: worker,
        ),
      );
      await t.longPress(find.text('Của người khác'));
      await t.pumpAndSettle();
      expect(find.text('Xoá bình luận'), findsNothing);

      await t.longPress(find.text('Của tôi'));
      await t.pumpAndSettle();
      await t.tap(find.text('Xoá bình luận'));
      await t.pumpAndSettle();
      await t.tap(find.text('Xoá bình luận').last);
      await t.pumpAndSettle();
      expect(recorded.last, ('deleteComment', 'k1'));
    });

    tw('người giao việc xoá được bình luận của người khác', (t) async {
      await pump(t, host(data: json(comments: comments)));
      await t.longPress(find.text('Của người khác'));
      await t.pumpAndSettle();
      expect(find.text('Xoá bình luận'), findsOneWidget);
    });

    tw('avatar 30, bong bóng bo 8, "Tên · giờ"', (t) async {
      await pump(t, host(data: json(comments: comments)));
      expect(find.textContaining('Khánh · '), findsOneWidget);
    });
  });

  group('(h) ô bình luận đáy', () {
    tw('gửi {body, mentioned_user_ids} như cũ; xoá ô khi xong', (t) async {
      await pump(t, host(data: json(), perms: worker));
      final field = find.widgetWithText(TextField, 'Bình luận, @ để nhắc tên');
      expect(field, findsOneWidget);
      await t.enterText(field, '@Kh');
      await t.pump();
      await t.tap(find.byKey(const ValueKey('mention:u1')));
      await t.pump();
      await t.enterText(
        field,
        '${t.widget<TextField>(field).controller!.text}duyệt giúp',
      );
      await t.pump();
      await t.tap(find.byTooltip('Gửi bình luận'));
      await t.pumpAndSettle();
      final (kind, payload) = recorded.last;
      final (body, ids) = payload! as (String, List<String>);
      expect(kind, 'comment');
      expect(body, '@Khánh duyệt giúp');
      expect(ids, ['u1']);
    });

    tw('Nhóm 2: không có nút ảnh, không mặt cười', (t) async {
      await pump(t, host(data: json(), perms: worker));
      expect(find.byTooltip('Đính kèm ảnh hoặc tệp'), findsNothing);
      expect(find.byIcon(Icons.sentiment_satisfied_alt_rounded), findsNothing);
    });
  });

  group('nhật ký + đã xem', () {
    tw('"Đã xem việc này" kèm avatar 24 chồng', (t) async {
      await pump(
        t,
        host(
          data: json(
            viewers: [
              {'user_id': 'u1', 'name': 'Khánh'},
              {'user_id': 'u2', 'name': 'Linh'},
            ],
          ),
        ),
      );
      expect(find.text('Nhật ký hoạt động'), findsOneWidget);
      expect(find.text('Đã xem việc này'), findsOneWidget);
      expect(find.bySemanticsLabel('Đã xem: Khánh, Linh'), findsOneWidget);
    });
  });

  tw('(l) không còn TaskActionBar / nút Chụp ảnh ở đáy', (t) async {
    await pump(t, host(data: json()));
    expect(find.bySemanticsLabel('Chụp ảnh'), findsNothing);
    expect(find.byTooltip('Tải tệp lên'), findsOneWidget);
  });

  tw('theme tối dựng được', (t) async {
    await pump(
      t,
      ProviderScope(
        overrides: [
          taskDetailProvider.overrideWith(
            () => _Detail(
              TaskDetailState(task: Task.fromJson(json(checklist: []))),
              [],
            ),
          ),
          planCustomFieldsProvider.overrideWith((ref, id) async => fields),
          taskLabelsProvider.overrideWith((ref) async => const []),
          taskAccessProvider.overrideWithValue(
            TaskAccess.of(const AccessPolicy(assigner)),
          ),
        ],
        child: MaterialApp(
          theme: OmniTheme.dark(TargetPlatform.android),
          home: const TaskDetailPage(taskId: 't1'),
        ),
      ),
    );
    expect(t.takeException(), isNull);
    expect(find.text('Trường tuỳ chỉnh'), findsOneWidget);
  });
}

class _Detail extends TaskController {
  _Detail(this._state, this._saved);

  final TaskDetailState _state;
  final List<(String, Object?)> _saved;
  Map<String, Object?>? lastFields;

  @override
  Future<TaskDetailState> build(String taskId) async => _state;

  Task get _task => state.valueOrNull!.task;

  void _set(Task task) {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(current.copyWith(task: task));
  }

  @override
  Future<void> setCustomField(String fieldId, Object? value) async {
    _saved.add(('customField', (fieldId, value)));
    lastFields = {..._task.customFields, fieldId: value};
  }

  @override
  Future<void> toggleSubtask(String subtaskId, {required bool done}) async =>
      _saved.add(('toggle', (subtaskId, done)));

  @override
  Future<void> deleteAttachment(String attachmentId) async =>
      _saved.add(('deleteAttachment', attachmentId));

  @override
  Future<void> deleteComment(String commentId) async =>
      _saved.add(('deleteComment', commentId));

  @override
  Future<void> comment(
    String body, {
    List<String> mentionedUserIds = const [],
  }) async => _saved.add(('comment', (body, mentionedUserIds)));

  @override
  Future<void> setStatus(String status) async {
    _saved.add(('status', status));
    _set(_task.copyWith(status: status));
  }
}
