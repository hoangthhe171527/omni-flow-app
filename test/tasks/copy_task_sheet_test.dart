import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:omni_app/core/error/app_exception.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/modules/tasks/data/tasks_api.dart';
import 'package:omni_app/modules/tasks/domain/custom_field.dart';
import 'package:omni_app/modules/tasks/domain/task.dart';
import 'package:omni_app/modules/tasks/domain/task_project.dart';
import 'package:omni_app/modules/tasks/presentation/widgets/task_detail/copy_task_sheet.dart';
import 'package:omni_app/modules/team/team.dart';
import 'package:omni_app/security/session/api_capabilities.dart';
import 'package:omni_app/security/session/session.dart';
import 'package:omni_app/security/session/session_controller.dart';

/// Sheet "Sao chép công việc" (`AppCopy.dc.html`, Task 4 góp ý bảng kế hoạch).
///
/// Mỗi khoá mới (`start_date`, `due_date`, `assignee_ids`,
/// `keep_custom_fields`) chỉ được đặt khi phiên khai `tasks.copy_options`; API
/// cũ thì body chỉ có năm khoá cũ. Body so bằng `request.toJson()` — đúng map
/// `TasksApi.copyTask` gửi đi (hợp đồng dio ở `gop_y_bang_contract_test`).
void main() {
  setUpAll(() => initializeDateFormatting('vi_VN'));

  const oldCaps = {ApiCapability.taskCopy};
  const newCaps = {ApiCapability.taskCopy, ApiCapability.taskCopyOptions};

  final plans = <MovablePlan>[
    (
      id: 'pA',
      name: 'Tân trang',
      teamId: 'T1',
      teamName: 'Xưởng',
      sections: [
        TaskSection(id: 'a1', name: 'Khách khác'),
        TaskSection(id: 'a2', name: 'Thiện Piano'),
      ],
    ),
    (id: 'pC', name: 'Riêng', teamId: null, teamName: null, sections: []),
    (
      id: 'pB',
      name: 'Bảo hành',
      teamId: 'T1',
      teamName: 'Xưởng',
      sections: [TaskSection(id: 'b1', name: 'Chờ')],
    ),
    (
      id: 'pD',
      name: 'Kho tổng',
      teamId: 'T2',
      teamName: 'Kho',
      sections: [TaskSection(id: 'd1', name: 'Nhập')],
    ),
  ];

  final projects = <String, TaskProject>{
    'pA': const TaskProject(
      ownerId: 'u1',
      memberIds: ['u2'],
      customFields: [
        CustomFieldDef(id: 'fA1', name: 'Hãng'),
        CustomFieldDef(id: 'fA2', name: 'Serial'),
      ],
    ),
    'pB': const TaskProject(
      ownerId: 'u2',
      memberIds: ['u3'],
      customFields: [
        CustomFieldDef(id: 'fB1', name: 'hãng '),
        CustomFieldDef(id: 'fB2', name: 'Model'),
      ],
    ),
    'pC': const TaskProject(),
    'pD': const TaskProject(ownerId: 'u3'),
  };

  Map<String, dynamic> taskJson() => {
    'id': 't1',
    'title': 'YAMAHA U1E',
    'project_id': 'pA',
    'section_id': 'a2',
    'assignee_ids': ['u1'],
    'assignee_names': ['Hằng Ni'],
    'custom_fields': {'fA1': 'Yamaha'},
    'checklist': [
      {'id': 'c1', 'title': 'Tháo đàn', 'done': true},
      {'id': 'c2', 'title': 'Bộ máy', 'done': false},
    ],
    'start_date': '2026-10-12',
    'due_date': '2026-10-31',
  };

  late _Api api;
  TaskCopyResult? result;

  Future<void> open(
    WidgetTester t, {
    Set<String> caps = newCaps,
    Map<String, dynamic>? data,
    bool failLoad = false,
  }) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    api = _Api(plans, projects)..failNext = failLoad;
    result = null;
    final task = Task.fromJson(data ?? taskJson());
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          tasksApiProvider.overrideWithValue(api),
          teamDirectoryProvider.overrideWith(
            (ref) async => const [
              TeamMember(membershipId: 'm1', userId: 'u1', name: 'Hằng Ni'),
              TeamMember(membershipId: 'm2', userId: 'u2', name: 'Bảo Khánh'),
              TeamMember(membershipId: 'm3', userId: 'u3', name: 'Linh'),
            ],
          ),
          sessionProvider.overrideWithValue(
            Session(
              status: SessionStatus.authenticated,
              user: const SessionUser(id: 'u9', fullName: 'Thợ', email: 'a@b'),
              apiCapabilities: caps,
            ),
          ),
        ],
        child: MaterialApp(
          theme: OmniTheme.light(TargetPlatform.android),
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () async =>
                      result = await showCopyTaskSheet(context, task: task),
                  child: const Text('Mở sheet'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.text('Mở sheet'));
    await t.pumpAndSettle();
  }

  Future<void> tapIt(WidgetTester t, Finder f) async {
    await t.ensureVisible(f);
    await t.pumpAndSettle();
    await t.tap(f);
    await t.pumpAndSettle();
  }

  Future<Map<String, dynamic>> submit(WidgetTester t) async {
    await tapIt(t, find.widgetWithText(FilledButton, 'Sao chép'));
    expect(result, isNotNull, reason: 'sheet phải trả kết quả');
    return result!.request.toJson();
  }

  Future<void> pick(WidgetTester t, String key, String item) async {
    await tapIt(t, find.byKey(ValueKey(key)));
    await t.tap(find.text(item).last);
    await t.pumpAndSettle();
  }

  Finder inField(String key, String text) =>
      find.descendant(of: find.byKey(ValueKey(key)), matching: find.text(text));

  Future<void> pickDay(WidgetTester t, String key, String day) async {
    await tapIt(t, find.byKey(ValueKey(key)));
    await t.tap(find.text(day));
    await t.pump();
    await t.tap(find.text('OK'));
    await t.pumpAndSettle();
  }

  FilledButton copyButton(WidgetTester t) =>
      t.widget<FilledButton>(find.widgetWithText(FilledButton, 'Sao chép'));

  test(
    'sameCopyDay: hai null là bằng nhau; khác ngày / một bên null là khác',
    () {
      expect(sameCopyDay(null, null), isTrue);
      expect(sameCopyDay(DateTime(2026, 10, 12), null), isFalse);
      expect(sameCopyDay(null, DateTime(2026, 10, 12)), isFalse);
      expect(
        sameCopyDay(DateTime(2026, 10, 12, 9), DateTime(2026, 10, 12)),
        isTrue,
      );
      expect(
        sameCopyDay(DateTime(2026, 10, 12), DateTime(2026, 10, 13)),
        isFalse,
      );
    },
  );

  testWidgets('API cũ: không có ô ngày, không có "Người thực hiện"/"Trường tuỳ '
      'chỉnh"; có "Giữ người thực hiện"; Sao chép ngay → body đúng {title, '
      'project_id: A, keep_assignees: true, keep_checklist: true} (KHÔNG '
      'section_id — cùng nhóm gốc)', (t) async {
    await open(t, caps: oldCaps);
    expect(find.text('Sao chép công việc'), findsOneWidget);
    expect(find.text('Từ ngày'), findsNothing);
    expect(find.text('Đến ngày'), findsNothing);
    expect(find.text('Người thực hiện'), findsNothing);
    expect(find.text('Trường tuỳ chỉnh'), findsNothing);
    expect(find.text('Giữ người thực hiện'), findsOneWidget);
    expect(find.text('Chép cả việc con'), findsOneWidget);
    expect(inField('copy-team', 'Xưởng'), findsOneWidget);
    expect(inField('copy-plan', 'Tân trang'), findsOneWidget);
    expect(inField('copy-section', 'Thiện Piano'), findsOneWidget);

    final body = await submit(t);
    expect(body, {
      'title': 'YAMAHA U1E (bản sao)',
      'project_id': 'pA',
      'keep_assignees': true,
      'keep_checklist': true,
    });
    expect(result!.placeName, 'Thiện Piano');
  });

  testWidgets('API cũ: tắt "Giữ người thực hiện" → keep_assignees: false', (
    t,
  ) async {
    await open(t, caps: oldCaps);
    await tapIt(t, find.text('Giữ người thực hiện'));
    final body = await submit(t);
    expect(body['keep_assignees'], false);
    expect(body.containsKey('assignee_ids'), isFalse);
  });

  testWidgets('API mới, không đổi gì → body không có start_date/due_date/'
      'assignee_ids; keep_custom_fields: true', (t) async {
    await open(t);
    expect(find.text('Từ ngày'), findsOneWidget);
    expect(find.text('12/10/2026'), findsOneWidget);
    expect(find.text('31/10/2026'), findsOneWidget);
    expect(find.text('Giữ người thực hiện'), findsNothing);
    expect(find.text('Như việc gốc: Hằng Ni.'), findsOneWidget);

    final body = await submit(t);
    expect(body, {
      'title': 'YAMAHA U1E (bản sao)',
      'project_id': 'pA',
      'keep_assignees': true,
      'keep_checklist': true,
      'keep_custom_fields': true,
    });
  });

  testWidgets('đổi Đến ngày → chỉ có due_date "YYYY-MM-DD"; xoá Từ ngày → '
      'start_date: null CÓ khoá', (t) async {
    await open(t);
    await pickDay(t, 'copy-due', '20');
    expect(find.text('20/10/2026'), findsOneWidget);
    var body = result?.request.toJson();
    expect(body, isNull);

    await tapIt(t, find.byTooltip('Xoá ngày bắt đầu'));
    expect(find.text('12/10/2026'), findsNothing);
    body = await submit(t);
    expect(body['due_date'], '2026-10-20');
    expect(body.containsKey('start_date'), isTrue);
    expect(body['start_date'], isNull);
  });

  testWidgets('chỉ đổi Đến ngày → không có khoá start_date', (t) async {
    await open(t);
    await pickDay(t, 'copy-due', '20');
    final body = await submit(t);
    expect(body['due_date'], '2026-10-20');
    expect(body.containsKey('start_date'), isFalse);
  });

  testWidgets('Đến ngày < Từ ngày → lỗi "Ngày kết thúc phải từ ngày bắt đầu '
      'trở đi." và "Sao chép" tắt', (t) async {
    await open(t);
    expect(copyButton(t).onPressed, isNotNull);
    await pickDay(t, 'copy-due', '5');
    expect(
      find.text('Ngày kết thúc phải từ ngày bắt đầu trở đi.'),
      findsOneWidget,
    );
    expect(copyButton(t).onPressed, isNull);
  });

  testWidgets('đổi kế hoạch sang B → Nhóm việc = b1, gửi section_id b1; ghi '
      'chú trường khớp "(Hãng)"', (t) async {
    await open(t);
    expect(find.textContaining('Khác kế hoạch'), findsNothing);
    await pick(t, 'copy-plan', 'Bảo hành');
    expect(inField('copy-section', 'Chờ'), findsOneWidget);
    expect(
      find.text(
        'Khác kế hoạch: chỉ chép trường có cùng tên ở kế hoạch đích (Hãng).',
      ),
      findsOneWidget,
    );
    final body = await submit(t);
    expect(body['project_id'], 'pB');
    expect(body['section_id'], 'b1');
    expect(body['keep_custom_fields'], true);
    expect(result!.placeName, 'Chờ');
  });

  testWidgets('cùng kế hoạch, đổi nhóm → gửi section_id', (t) async {
    await open(t);
    await pick(t, 'copy-section', 'Khách khác');
    final body = await submit(t);
    expect(body['section_id'], 'a1');
    expect(result!.placeName, 'Khách khác');
  });

  testWidgets('khác kế hoạch, không trường nào khớp → câu "không chép trường '
      'nào"', (t) async {
    await open(t);
    await pick(t, 'copy-team', 'Kho');
    expect(
      find.text(
        'Kế hoạch đích không có trường cùng tên — sẽ không chép trường nào.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('đổi team → kế hoạch đầu của team; "Chưa thuộc team" chứa C, '
      'nằm cuối', (t) async {
    await open(t);
    await tapIt(t, find.byKey(const ValueKey('copy-team')));
    final yXuong = t.getTopLeft(find.text('Xưởng').last).dy;
    final yKho = t.getTopLeft(find.text('Kho').last).dy;
    final yNone = t.getTopLeft(find.text('Chưa thuộc team').last).dy;
    expect(yXuong, lessThan(yKho));
    expect(yKho, lessThan(yNone));
    await t.tap(find.text('Kho').last);
    await t.pumpAndSettle();
    expect(inField('copy-plan', 'Kho tổng'), findsOneWidget);
    expect(inField('copy-section', 'Nhập'), findsOneWidget);

    await pick(t, 'copy-team', 'Chưa thuộc team');
    expect(inField('copy-plan', 'Riêng'), findsOneWidget);
    await tapIt(t, find.byKey(const ValueKey('copy-plan')));
    // Chỉ kế hoạch của "Chưa thuộc team" trong danh sách.
    expect(find.text('Tân trang'), findsNothing);
    expect(find.text('Bảo hành'), findsNothing);
  });

  testWidgets('kế hoạch C (không nhóm) → ô nhóm tắt "Chưa xếp nhóm", body '
      'không có section_id', (t) async {
    await open(t);
    await pick(t, 'copy-team', 'Chưa thuộc team');
    expect(inField('copy-section', 'Chưa xếp nhóm'), findsOneWidget);
    final field = t.widget<DropdownButtonFormField<String>>(
      find.byKey(const ValueKey('copy-section')),
    );
    expect(field.onChanged, isNull);
    final body = await submit(t);
    expect(body['project_id'], 'pC');
    expect(body.containsKey('section_id'), isFalse);
    expect(result!.placeName, 'Riêng');
  });

  testWidgets('"Chọn người khác" → chip u1; bỏ u1 → assignee_ids: [] (không '
      'có keep_assignees)', (t) async {
    await open(t);
    await tapIt(t, find.text('Chọn người khác'));
    expect(find.byTooltip('Bỏ Hằng Ni'), findsOneWidget);
    expect(find.text('+ Thêm người'), findsOneWidget);
    await tapIt(t, find.byTooltip('Bỏ Hằng Ni'));
    expect(find.byTooltip('Bỏ Hằng Ni'), findsNothing);
    final body = await submit(t);
    expect(body['assignee_ids'], <String>[]);
    expect(body.containsKey('keep_assignees'), isFalse);
  });

  testWidgets('"+ Thêm người" chỉ liệt kê thành viên kế hoạch đích '
      '(allowedIds); đổi sang B thì u1 bị bỏ khỏi chip', (t) async {
    await open(t);
    await tapIt(t, find.text('Chọn người khác'));
    await tapIt(t, find.text('+ Thêm người'));
    expect(find.text('Người thực hiện bản sao'), findsOneWidget);
    expect(find.widgetWithText(CheckboxListTile, 'Bảo Khánh'), findsOneWidget);
    expect(find.widgetWithText(CheckboxListTile, 'Hằng Ni'), findsOneWidget);
    expect(find.widgetWithText(CheckboxListTile, 'Linh'), findsNothing);
    await t.tap(find.widgetWithText(CheckboxListTile, 'Bảo Khánh'));
    await t.pump();
    await t.tap(find.text('Chọn 2 người'));
    await t.pumpAndSettle();
    expect(find.byTooltip('Bỏ Bảo Khánh'), findsOneWidget);
    expect(find.byTooltip('Bỏ Hằng Ni'), findsOneWidget);

    await pick(t, 'copy-plan', 'Bảo hành');
    expect(find.byTooltip('Bỏ Hằng Ni'), findsNothing);
    expect(find.byTooltip('Bỏ Bảo Khánh'), findsOneWidget);
    final body = await submit(t);
    expect(body['assignee_ids'], ['u2']);
  });

  testWidgets('"Không chép" → keep_custom_fields: false', (t) async {
    await open(t);
    await tapIt(t, find.text('Không chép'));
    final body = await submit(t);
    expect(body['keep_custom_fields'], false);
  });

  testWidgets('việc không có trường → không có khối và không có khoá', (
    t,
  ) async {
    await open(t, data: {...taskJson(), 'custom_fields': <String, dynamic>{}});
    expect(find.text('Trường tuỳ chỉnh'), findsNothing);
    final body = await submit(t);
    expect(body.containsKey('keep_custom_fields'), isFalse);
  });

  testWidgets('việc không có việc con → không có công tắc, keep_checklist: '
      'true', (t) async {
    await open(t, data: {...taskJson(), 'checklist': <Object>[]});
    expect(find.text('Chép cả việc con'), findsNothing);
    final body = await submit(t);
    expect(body['keep_checklist'], true);
  });

  testWidgets('tắt "Chép cả việc con" → keep_checklist: false', (t) async {
    await open(t);
    expect(find.text('2 việc con, bỏ đánh dấu đã xong'), findsOneWidget);
    await tapIt(t, find.text('Chép cả việc con'));
    final body = await submit(t);
    expect(body['keep_checklist'], false);
  });

  testWidgets('tên trống → "Sao chép" tắt', (t) async {
    await open(t);
    await t.enterText(find.byType(TextField).first, '   ');
    await t.pump();
    expect(copyButton(t).onPressed, isNull);
  });

  testWidgets('Huỷ → trả null', (t) async {
    await open(t);
    await tapIt(t, find.widgetWithText(OutlinedButton, 'Huỷ'));
    expect(result, isNull);
    expect(find.text('Sao chép công việc'), findsNothing);
  });

  testWidgets('mọi nút chạm ≥ 44×44 (×, xoá ngày, bỏ người, công tắc, '
      'Huỷ/Sao chép cao 48)', (t) async {
    await open(t);
    void atLeast44(Finder f) {
      final s = t.getSize(f);
      expect(s.width, greaterThanOrEqualTo(44), reason: '$f');
      expect(s.height, greaterThanOrEqualTo(44), reason: '$f');
    }

    atLeast44(find.byTooltip('Đóng'));
    atLeast44(find.byTooltip('Xoá ngày bắt đầu'));
    atLeast44(find.byTooltip('Xoá ngày kết thúc'));
    atLeast44(find.byType(Switch));
    expect(
      t.getSize(find.widgetWithText(OutlinedButton, 'Huỷ')).height,
      greaterThanOrEqualTo(48),
    );
    expect(
      t.getSize(find.widgetWithText(FilledButton, 'Sao chép')).height,
      greaterThanOrEqualTo(48),
    );
    expect(t.getSize(find.byKey(const ValueKey('copy-due'))).height, 44);
    await tapIt(t, find.text('Chọn người khác'));
    atLeast44(find.byTooltip('Bỏ Hằng Ni'));
    expect(
      t.getSize(find.byKey(const ValueKey('copy-add-person'))).height,
      greaterThanOrEqualTo(44),
    );
  });

  testWidgets('lỗi tải kế hoạch → "Thử lại" gọi lại projectsForMove', (
    t,
  ) async {
    await open(t, failLoad: true);
    expect(find.text('Chưa tải được danh sách kế hoạch.'), findsOneWidget);
    expect(api.loads, 1);
    expect(copyButton(t).onPressed, isNull);
    await tapIt(t, find.text('Thử lại'));
    expect(api.loads, 2);
    expect(inField('copy-plan', 'Tân trang'), findsOneWidget);
  });
}

class _Api implements TasksApi {
  _Api(this._plans, this._projects);

  final List<MovablePlan> _plans;
  final Map<String, TaskProject> _projects;
  bool failNext = false;
  int loads = 0;

  @override
  Future<List<MovablePlan>> projectsForMove() async {
    loads++;
    if (failNext) {
      failNext = false;
      throw const NetworkException('Mất mạng.');
    }
    return _plans;
  }

  @override
  Future<TaskProject> project(String projectId) async =>
      _projects[projectId] ?? const TaskProject();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
