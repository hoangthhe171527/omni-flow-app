import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:omni_app/core/error/app_exception.dart';
import 'package:omni_app/design/components/components.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/design/tokens/tokens.dart';
import 'package:omni_app/modules/plans/routes.dart';
import 'package:omni_app/modules/tasks/application/task_controller.dart';
import 'package:omni_app/modules/tasks/application/tasks_providers.dart';
import 'package:omni_app/modules/tasks/domain/task.dart';
import 'package:omni_app/modules/tasks/domain/task_label.dart';
import 'package:omni_app/modules/tasks/domain/task_permissions.dart';
import 'package:omni_app/modules/tasks/presentation/task_detail_page.dart';
import 'package:omni_app/modules/tasks/presentation/widgets/task_detail/option_sheet.dart';
import 'package:omni_app/modules/team/team.dart';
import 'package:omni_app/security/permissions/access_policy.dart';
import 'package:omni_app/security/session/session.dart';
import 'package:omni_app/security/session/session_controller.dart';

/// Nửa trên màn chi tiết việc theo `TaskDetail.dc.html` (Việc mới, Task 8):
/// header kính, dải nhãn, tiêu đề có ô tích, breadcrumb, thẻ thông tin, mô tả.
void main() {
  setUpAll(() => initializeDateFormatting('vi_VN'));

  const worker = {'tasks.read', 'tasks.write'};
  const assigner = {
    'tasks.read',
    'tasks.write',
    'tasks.projects.manage.all',
    'system_options.read',
  };
  const me = 'u9';

  const catalog = [
    TaskLabel(id: 'o1', code: 'uu_tien', label: 'Ưu tiên', color: '#B42318'),
    TaskLabel(
      id: 'o2',
      code: 'cho_khach',
      label: 'Chờ khách',
      color: '#B45309',
    ),
  ];

  late List<(String, Object?)> recorded;
  late _Detail stub;
  late List<MethodCall> platformCalls;

  Map<String, dynamic> json({
    String status = 'todo',
    String? project = 'Tân trang đàn piano cơ',
    String? section = 'Khách lẻ',
    List<String> sections = const ['Tiếp nhận', 'Khách lẻ'],
    List<String> names = const [],
    List<String> ids = const [],
    String priority = 'med',
    String? due,
    String? start,
    String? description,
    List<String> labels = const [],
    List<String>? likes,
    int rating = 0,
  }) => {
    'id': 't1',
    'title': 'YAMAHA U3E 592698 – Đặng Hoài Bảo',
    'status': status,
    'project_id': 'p1',
    'project_name': ?project,
    'section_id': section == null ? null : 'sec-$section',
    'section_name': ?section,
    'plan_sections': [
      for (final s in sections) {'id': 'sec-$s', 'name': s},
    ],
    'assignee_ids': ids,
    'assignee_names': names,
    'priority': priority,
    'due_date': ?due,
    'start_date': ?start,
    'description': ?description,
    'labels': labels,
    'likes': ?likes,
    'rating': rating,
    'checklist': <Map<String, dynamic>>[],
  };

  Widget host({
    required Map<String, dynamic> data,
    Set<String> perms = assigner,
    bool reduceMotion = false,
    List<TaskLabel> labels = catalog,
  }) {
    recorded = [];
    stub = _Detail(TaskDetailState(task: Task.fromJson(data)), recorded);

    return ProviderScope(
      overrides: [
        taskDetailProvider.overrideWith(() => stub),
        taskLabelsProvider.overrideWith((ref) async => labels),
        teamDirectoryProvider.overrideWith(
          (ref) async => [
            TeamMember(membershipId: 'm1', userId: 'u1', name: 'Hằng Ni'),
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
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    platformCalls = [];
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        platformCalls.add(call);
        return null;
      },
    );
    await t.pumpWidget(app);
    await t.pumpAndSettle();
  }

  /// testWidgets có bật ngữ nghĩa, trả tay cầm trước khi bài kết thúc.
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

  group('(a) dải nhãn', () {
    tw('chip "Ưu tiên" màu nhãn, cao 28, bo 4; + mở sheet; bật "Chờ khách" '
        'gửi cả hai mã', (t) async {
      await pump(t, host(data: json(labels: ['uu_tien'])));
      final chip = find.byKey(const ValueKey('label-chip-uu_tien'));
      expect(chip, findsOneWidget);
      final box = t.widget<Container>(chip);
      final deco = box.decoration! as BoxDecoration;
      expect(deco.color, const Color(0xFFB42318));
      expect(deco.borderRadius, BorderRadius.circular(4));
      expect(t.getSize(chip).height, 28);
      final text = t.widget<Text>(
        find.descendant(of: chip, matching: find.text('Ưu tiên')),
      );
      expect(text.style?.fontSize, 13);
      expect(text.style?.fontWeight, FontWeight.w600);

      final add = find.bySemanticsLabel('Thêm nhãn');
      expect(t.getSize(add), const Size(44, 44));
      await t.tap(add);
      await t.pumpAndSettle();
      expect(find.text('Nhãn màu'), findsOneWidget);
      await t.tap(find.text('Chờ khách').last);
      await t.pumpAndSettle();
      expect(recorded.last.$1, 'labels');
      expect(recorded.last.$2, ['uu_tien', 'cho_khach']);
    });

    tw('mã lạ (không có trong danh mục) vẫn hiện bằng chữ mã', (t) async {
      await pump(t, host(data: json(labels: ['la_ma'])));
      expect(find.text('la_ma'), findsOneWidget);
    });

    tw('không quyền ghi: không có +', (t) async {
      await pump(
        t,
        host(
          data: json(labels: ['uu_tien']),
          perms: {'tasks.read'},
        ),
      );
      expect(find.bySemanticsLabel('Thêm nhãn'), findsNothing);
    });

    tw('không có danh mục nhãn (thợ, API cũ): không có +', (t) async {
      await pump(t, host(data: json(), perms: worker, labels: const []));
      expect(find.bySemanticsLabel('Thêm nhãn'), findsNothing);
    });

    tw('thợ có danh mục qua /system-options/task-labels: có +', (t) async {
      await pump(t, host(data: json(), perms: worker));
      expect(find.bySemanticsLabel('Thêm nhãn'), findsOneWidget);
    });
  });

  group('(b) tiêu đề có ô tích', () {
    tw('chữ 20 w600; ô 26 bo 6 viền 2; chạm gửi done và báo quản lý', (
      t,
    ) async {
      await pump(t, host(data: json(), perms: worker));
      final title = t.widget<Text>(find.byKey(const ValueKey('detail-title')));
      expect(title.style?.fontSize, 20);
      expect(title.style?.fontWeight, FontWeight.w600);
      final box = find.byKey(const ValueKey('title-tick-box'));
      expect(t.getSize(box), const Size(26, 26));
      final deco = t.widget<Container>(box).decoration! as BoxDecoration;
      expect(deco.borderRadius, BorderRadius.circular(6));
      expect(deco.border!.top.width, 2);
      expect(deco.border!.top.color, const Color(0xFF9AA5B8));

      final target = find.bySemanticsLabel('Đánh dấu xong');
      expect(t.getSize(target), const Size(44, 44));
      await t.tap(target);
      await t.pumpAndSettle();
      expect(recorded.last, ('status', 'done'));
      expect(
        find.text('Đã báo hoàn thành. Quản lý sẽ nhận thông báo.'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Bỏ đánh dấu xong'), findsOneWidget);
    });

    tw('đã xong: chạm gửi doing, "Đã mở lại công việc."', (t) async {
      await pump(
        t,
        host(
          data: json(status: 'done'),
          perms: worker,
        ),
      );
      await t.tap(find.bySemanticsLabel('Bỏ đánh dấu xong'));
      await t.pumpAndSettle();
      expect(recorded.last, ('status', 'doing'));
      expect(find.text('Đã mở lại công việc.'), findsOneWidget);
    });

    tw('422 thì hiện lời server, mất mạng thì nhắc mạng; ô về như cũ', (
      t,
    ) async {
      await pump(t, host(data: json(), perms: worker));
      stub.statusError = const ValidationException(
        'Không thể hoàn thành: còn công việc phụ thuộc chưa xong.',
      );
      await t.tap(find.bySemanticsLabel('Đánh dấu xong'));
      await t.pumpAndSettle();
      expect(
        find.text('Không thể hoàn thành: còn công việc phụ thuộc chưa xong.'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Đánh dấu xong'), findsOneWidget);

      stub.statusError = const NetworkException('Không có kết nối mạng.');
      await t.tap(find.bySemanticsLabel('Đánh dấu xong'));
      await t.pumpAndSettle();
      expect(
        find.text('Chưa lưu được. Kiểm tra mạng rồi thử lại.'),
        findsOneWidget,
      );
    });

    tw('giảm chuyển động: chạm ô tích không để lại khung hoạt ảnh', (t) async {
      await pump(t, host(data: json(), perms: worker, reduceMotion: true));
      await t.tap(find.bySemanticsLabel('Đánh dấu xong'));
      await t.pump();
      // (SnackBar "Đã báo hoàn thành" là của Scaffold, không phải ô tích.)
      final bounce = t.widget<ScaleTransition>(
        find.byKey(const ValueKey('title-tick-bounce')),
      );
      expect(bounce.scale.isAnimating, isFalse);
      expect(bounce.scale.value, 1);
      // Cho SnackBar hết hạn để không còn Timer treo.
      await t.pump(const Duration(seconds: 5));
      await t.pumpAndSettle();
    });

    tw('bật chuyển động: ô tích nảy 350ms', (t) async {
      await pump(t, host(data: json(), perms: worker));
      await t.tap(find.bySemanticsLabel('Đánh dấu xong'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 140));
      final bounce = t.widget<ScaleTransition>(
        find.byKey(const ValueKey('title-tick-bounce')),
      );
      expect(bounce.scale.value, greaterThan(1.1));
      await t.pumpAndSettle();
    });

    tw('chỉ đọc (tasks.read): ô tích không bấm được', (t) async {
      await pump(t, host(data: json(), perms: {'tasks.read'}));
      await t.tap(
        find.byKey(const ValueKey('title-tick-box')),
        warnIfMissed: false,
      );
      await t.pumpAndSettle();
      expect(recorded, isEmpty);
    });

    tw('không còn nút "Hoàn thành công việc" ở thanh đáy', (t) async {
      await pump(t, host(data: json(), perms: worker));
      expect(find.text('Hoàn thành công việc'), findsNothing);
      // Máy ảnh nay là "Tải tệp lên" trong thẻ Tệp (Task 9).
      expect(find.byTooltip('Tải tệp lên'), findsOneWidget);
    });
  });

  group('(c) breadcrumb', () {
    tw('tên kế hoạch › tên nhóm; người giao chạm nhóm mở sheet nhóm', (
      t,
    ) async {
      await pump(t, host(data: json()));
      final plan = find.byKey(const ValueKey('crumb-plan'));
      final section = find.byKey(const ValueKey('crumb-section'));
      expect(
        find.descendant(
          of: plan,
          matching: find.text('Tân trang đàn piano cơ'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: section, matching: find.text('Khách lẻ')),
        findsOneWidget,
      );
      expect(t.getSize(section).height, greaterThanOrEqualTo(44));
      await t.tap(section);
      await t.pumpAndSettle();
      expect(find.text('Chuyển nhóm việc'), findsOneWidget);
      await t.tap(find.text('Tiếp nhận'));
      await t.pumpAndSettle();
      expect(recorded.last, ('section', 'sec-Tiếp nhận'));
    });

    tw('kế hoạch chưa có nhóm: sheet nói rõ "kế hoạch", không ghi', (t) async {
      await pump(t, host(data: json(section: null, sections: const [])));
      await t.tap(find.byKey(const ValueKey('crumb-section')));
      await t.pumpAndSettle();
      expect(
        find.text('Kế hoạch này chưa khai báo nhóm việc nào.'),
        findsOneWidget,
      );
      expect(recorded, isEmpty);
    });
  });

  group('(d) thời gian', () {
    tw('"12/10 – Hạn 18/10"; đổi ngày bắt đầu gửi start_date', (t) async {
      await pump(
        t,
        host(
          data: json(start: '2030-10-12', due: '2030-10-18'),
        ),
      );
      expect(find.text('12/10'), findsOneWidget);
      expect(find.text('Hạn 18/10'), findsOneWidget);
      await t.tap(find.text('12/10'));
      await t.pumpAndSettle();
      expect(find.text('Thời gian'), findsWidgets);
      await t.tap(find.byKey(const ValueKey('time-start')));
      await t.pumpAndSettle();
      await t.tap(find.text('15'));
      await t.tap(find.text('OK'));
      await t.pumpAndSettle();
      await t.tap(find.text('Lưu'));
      await t.pumpAndSettle();
      expect(recorded, [('start', DateTime(2030, 10, 15))]);
    });

    tw('chip nhanh "Ngày mai" đặt hạn', (t) async {
      await pump(t, host(data: json()));
      expect(find.text('Đặt thời gian'), findsOneWidget);
      await t.tap(find.text('Đặt thời gian'));
      await t.pumpAndSettle();
      await t.tap(find.text('Ngày mai'));
      await t.pump();
      await t.tap(find.text('Lưu'));
      await t.pumpAndSettle();
      final now = DateTime.now();
      final tomorrow = DateTime(now.year, now.month, now.day + 1);
      expect(recorded, [('due', tomorrow)]);
    });

    tw('thợ: không mở sheet thời gian', (t) async {
      await pump(
        t,
        host(
          data: json(due: '2030-10-18'),
          perms: worker,
        ),
      );
      await t.tap(find.text('Hạn 18/10'));
      await t.pumpAndSettle();
      expect(find.text('Lưu'), findsNothing);
    });
  });

  group('(e) đánh giá và thích', () {
    tw('"4/5 · 3 lượt"; chạm gọi thích và số thành 4, chữ primary', (t) async {
      await pump(
        t,
        host(
          data: json(rating: 4, likes: ['a', 'b', 'c']),
          perms: worker,
        ),
      );
      expect(find.text('4/5 · 3 lượt'), findsOneWidget);
      final like = find.bySemanticsLabel('Thích việc này, 3 lượt');
      expect(t.getSize(like).height, greaterThanOrEqualTo(44));
      await t.tap(like);
      await t.pumpAndSettle();
      expect(recorded.last, ('like', me));
      expect(find.text('4/5 · 4 lượt'), findsOneWidget);
      final text = t.widget<Text>(find.text('4/5 · 4 lượt'));
      expect(
        text.style?.color,
        OmniTheme.light(TargetPlatform.android).colorScheme.primary,
      );
    });

    tw('khoá likes vắng: "0 lượt"', (t) async {
      await pump(t, host(data: json()));
      expect(find.text('0/5 · 0 lượt'), findsOneWidget);
    });

    tw('năm sao 22: bật #E8890C, tắt #D5DBE5', (t) async {
      await pump(t, host(data: json(rating: 2), perms: worker));
      final stars = t
          .widgetList<Icon>(find.byKey(const ValueKey('rating-star')))
          .toList();
      expect(stars, hasLength(5));
      expect(stars.every((s) => s.size == 22), isTrue);
      expect(stars[1].color, const Color(0xFFE8890C));
      expect(stars[2].color, const Color(0xFFD5DBE5));
    });

    tw('người giao chấm 4 sao → setRating(4)', (t) async {
      await pump(t, host(data: json(rating: 3)));
      await t.tap(find.bySemanticsLabel('4 sao'));
      await t.pumpAndSettle();
      expect(recorded.last, ('rating', 4));
    });

    tw('chạm lại sao đang chọn là xoá điểm (gửi 0)', (t) async {
      await pump(t, host(data: json(rating: 3)));
      await t.tap(find.bySemanticsLabel('3 sao'));
      await t.pumpAndSettle();
      expect(recorded.last, ('rating', 0));
    });

    tw('thợ không chấm được', (t) async {
      await pump(t, host(data: json(rating: 3), perms: worker));
      await t.tap(find.bySemanticsLabel('4 sao'), warnIfMissed: false);
      await t.pumpAndSettle();
      expect(recorded, isEmpty);
    });
  });

  group('người làm', () {
    tw('avatar 30 + vòng nét đứt; người giao chạm + mở "Ai làm việc này"', (
      t,
    ) async {
      await pump(
        t,
        host(
          data: json(names: ['Khánh'], ids: ['u1']),
        ),
      );
      expect(find.bySemanticsLabel('Người làm: Khánh'), findsOneWidget);
      // Nhóm 1: không vẽ người giao và mũi tên.
      expect(find.byIcon(Icons.arrow_forward_rounded), findsNothing);
      final add = find.bySemanticsLabel('Thêm người làm');
      expect(t.getSize(add), const Size(44, 44));
      await t.tap(add);
      await t.pumpAndSettle();
      expect(find.byKey(const Key('assign-task-menu')), findsOneWidget);
      expect(find.text('Ai làm việc này'), findsOneWidget);
    });

    tw('chưa giao ai: nói rõ', (t) async {
      await pump(t, host(data: json()));
      expect(find.text('Chưa giao ai'), findsOneWidget);
    });

    tw('thợ chưa có tên: + → "Nhận việc này" → claim', (t) async {
      await pump(t, host(data: json(), perms: worker));
      await t.tap(find.bySemanticsLabel('Thêm người làm'));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('claim-task-menu')), findsOneWidget);
      await t.tap(find.text('Nhận việc này'));
      await t.pumpAndSettle();
      expect(recorded.last, ('claim', me));
    });

    tw('thợ đã có tên: không có +', (t) async {
      await pump(
        t,
        host(
          data: json(names: ['Thợ Hùng'], ids: [me]),
          perms: worker,
        ),
      );
      expect(find.bySemanticsLabel('Thêm người làm'), findsNothing);
    });
  });

  group('ưu tiên (giữ năng lực)', () {
    tw('người giao: chạm Ưu tiên → sheet, chọn Thấp → low', (t) async {
      await pump(t, host(data: json(priority: 'high')));
      expect(find.text('Cao'), findsOneWidget);
      await t.tap(find.text('Cao'));
      await t.pumpAndSettle();
      expect(find.text('Mức ưu tiên'), findsOneWidget);
      await t.tap(find.text('Thấp'));
      await t.pumpAndSettle();
      expect(recorded.last, ('priority', 'low'));
    });

    tw('thợ + ưu tiên bình thường: không có dòng Ưu tiên', (t) async {
      await pump(t, host(data: json(), perms: worker));
      expect(find.text('Ưu tiên'), findsNothing);
    });

    tw('thợ + ưu tiên cao: thấy, không sửa được', (t) async {
      await pump(
        t,
        host(
          data: json(priority: 'high'),
          perms: worker,
        ),
      );
      await t.tap(find.text('Cao'));
      await t.pumpAndSettle();
      expect(find.text('Mức ưu tiên'), findsNothing);
    });
  });

  group('(f) mô tả', () {
    tw('Sao chép mô tả gọi Clipboard và báo', (t) async {
      await pump(t, host(data: json(description: 'Quy trình tân trang')));
      await t.tap(find.byTooltip('Sao chép mô tả'));
      await t.pumpAndSettle();
      final set = platformCalls.where((c) => c.method == 'Clipboard.setData');
      expect(set.single.arguments, {'text': 'Quy trình tân trang'});
      expect(find.text('Đã chép mô tả.'), findsOneWidget);
    });

    tw('trống: "Chưa có mô tả"; người giao Sửa mô tả → ghi', (t) async {
      await pump(t, host(data: json()));
      expect(find.text('Chưa có mô tả'), findsOneWidget);
      await t.tap(find.byTooltip('Sửa mô tả'));
      await t.pumpAndSettle();
      await t.enterText(
        find.byWidgetPredicate((w) => w is TextField && w.autofocus),
        'Thay nỉ búa',
      );
      await t.pump();
      await t.tap(find.text('Lưu'));
      await t.pumpAndSettle();
      expect(recorded.last, ('description', 'Thay nỉ búa'));
    });
  });

  group('(g) header', () {
    tw('tiêu đề trên header mờ 0, cuộn 300px thì mờ 1', (t) async {
      await pump(t, host(data: json(description: 'x\n' * 40)));
      AnimatedOpacity headerTitle() => t.widget<AnimatedOpacity>(
        find.ancestor(
          of: find.byKey(const ValueKey('header-title')),
          matching: find.byType(AnimatedOpacity),
        ),
      );
      expect(headerTitle().opacity, 0);
      await t.drag(find.byType(CustomScrollView), const Offset(0, -300));
      await t.pumpAndSettle();
      expect(headerTitle().opacity, 1);
    });

    tw('✕ 44 "Đóng"; ⋯ "Tuỳ chọn công việc" của người giao', (t) async {
      await pump(t, host(data: json()));
      expect(t.getSize(find.byTooltip('Đóng')), const Size(44, 44));
      expect(find.byTooltip('Tuỳ chọn công việc'), findsOneWidget);
    });

    tw('(h) Người theo dõi: JSON không có khoá thì không có nút', (t) async {
      await pump(t, host(data: json()));
      expect(find.bySemanticsLabel('Người theo dõi'), findsNothing);
      expect(find.byTooltip('Người theo dõi'), findsNothing);
    });

    tw('người giao: ⋯ → "Đổi tên việc" → ghi title', (t) async {
      await pump(t, host(data: json()));
      await t.tap(find.byTooltip('Tuỳ chọn công việc'));
      await t.pumpAndSettle();
      await t.tap(find.text('Đổi tên việc'));
      await t.pumpAndSettle();
      await t.enterText(
        find.byWidgetPredicate((w) => w is TextField && w.autofocus),
        'Lên dây U3 — 4521',
      );
      await t.pump();
      await t.tap(find.text('Lưu'));
      await t.pumpAndSettle();
      expect(recorded.last, ('title', 'Lên dây U3 — 4521'));
    });
  });

  group('(i) thợ', () {
    tw('không bút sửa mô tả, chạm nhóm không mở sheet, ⋯ chỉ chép liên kết', (
      t,
    ) async {
      await pump(
        t,
        host(
          data: json(description: 'Giữ phím ngà'),
          perms: worker,
          // Không danh mục nhãn (API cũ): thợ chỉ còn "Sao chép liên kết".
          labels: const [],
        ),
      );
      expect(find.byTooltip('Sửa mô tả'), findsNothing);
      expect(find.byTooltip('Sao chép mô tả'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('crumb-section')));
      await t.pumpAndSettle();
      expect(find.text('Chuyển nhóm việc'), findsNothing);
      await t.tap(find.byTooltip('Tuỳ chọn công việc'));
      await t.pumpAndSettle();
      expect(find.text('Sao chép liên kết'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('task-actions-menu')),
          matching: find.byType(OmniAnchoredMenuItem),
        ),
        findsOneWidget,
        reason: 'menu của thợ chỉ có đúng một mục',
      );
    });
  });

  // Chuyển từ task_detail_coordination_test.dart (đã xoá cùng CoordinationCard).
  testWidgets('showOptionSheet: trả chỉ số; ✓ ở mục đang chọn; dòng cao 46', (
    t,
  ) async {
    int? picked;
    await t.pumpWidget(
      MaterialApp(
        theme: OmniTheme.light(TargetPlatform.android),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async => picked = await showOptionSheet(
                context,
                title: 'Chọn',
                selected: 1,
                items: const [
                  OptionItem(label: 'A', color: Colors.red),
                  OptionItem(label: 'B', color: Colors.blue, round: true),
                ],
              ),
              child: const Text('mở'),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('mở'));
    await t.pumpAndSettle();
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    expect(
      t
          .getSize(
            find
                .ancestor(of: find.text('A'), matching: find.byType(InkWell))
                .first,
          )
          .height,
      46,
    );
    await t.tap(find.text('A'));
    await t.pumpAndSettle();
    expect(picked, 0);
  });

  testWidgets('sectionColor lặp vòng 5 màu', (t) async {
    late OmniTaskTones tones;
    await t.pumpWidget(
      MaterialApp(
        theme: OmniTheme.light(TargetPlatform.android),
        home: Builder(
          builder: (c) {
            tones = OmniTaskTones.of(c);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(tones.sectionColor(0), const Color(0xFF8A95A8));
    expect(tones.sectionColor(4), const Color(0xFF0A7D76));
    expect(tones.sectionColor(5), tones.sectionColor(0));
  });

  tw('theme tối dựng được', (t) async {
    recorded = [];
    stub = _Detail(
      TaskDetailState(task: Task.fromJson(json(labels: ['uu_tien']))),
      recorded,
    );
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          taskDetailProvider.overrideWith(() => stub),
          taskLabelsProvider.overrideWith((ref) async => catalog),
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
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    final ctx = t.element(find.byType(TaskDetailPage));
    expect(OmniTaskTones.of(ctx).star, const Color(0xFFF0A23C));
  });

  group('rà soát Task 8', () {
    /// Màn chi tiết trong GoRouter thật: `/plans/:id` (bảng) và `/tasks/:id`.
    Widget routed({
      Set<String> perms = assigner,
      String initial = '/tasks/t1',
      bool fromBoard = false,
    }) {
      recorded = [];
      stub = _Detail(TaskDetailState(task: Task.fromJson(json())), recorded);
      final router = GoRouter(
        initialLocation: fromBoard ? '/plans/p1' : initial,
        routes: [
          GoRoute(
            path: '/plans/:id',
            name: PlanRoutes.board,
            builder: (_, state) => Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => context.push('/tasks/t1'),
                  child: Text('bảng ${state.pathParameters['id']}'),
                ),
              ),
            ),
          ),
          GoRoute(
            path: '/tasks/:id',
            builder: (_, _) => const TaskDetailPage(taskId: 't1'),
          ),
        ],
      );

      return ProviderScope(
        overrides: [
          taskDetailProvider.overrideWith(() => stub),
          taskLabelsProvider.overrideWith((ref) async => catalog),
          planCustomFieldsProvider.overrideWith((ref, id) async => const []),
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

    tw('chạm tên kế hoạch: đẩy bảng của kế hoạch đó', (t) async {
      await pump(t, routed());
      await t.tap(find.byKey(const ValueKey('crumb-plan')));
      await t.pumpAndSettle();
      expect(find.text('bảng p1'), findsOneWidget);
      // Đẩy, không thay: quay lại vẫn về chi tiết.
      expect(GoRouter.of(t.element(find.text('bảng p1'))).canPop(), isTrue);
    });

    tw('mở việc TỪ bảng đó: chạm tên kế hoạch thì quay lại, không chồng', (
      t,
    ) async {
      await pump(t, routed(fromBoard: true));
      await t.tap(find.text('bảng p1'));
      await t.pumpAndSettle();
      expect(find.byType(TaskDetailPage), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('crumb-plan')));
      await t.pumpAndSettle();
      expect(find.byType(TaskDetailPage), findsNothing);
      expect(find.text('bảng p1'), findsOneWidget);
      // Đã quay lại chứ không đẩy bảng thứ hai.
      expect(GoRouter.of(t.element(find.text('bảng p1'))).canPop(), isFalse);
    });

    tw('thiếu tasks.read: tên kế hoạch không chạm được', (t) async {
      await pump(t, routed(perms: {'tasks.write'}));
      await t.tap(find.byKey(const ValueKey('crumb-plan')));
      await t.pumpAndSettle();
      expect(find.textContaining('bảng'), findsNothing);
      expect(find.byType(TaskDetailPage), findsOneWidget);
    });

    tw('mũi tên › giữa breadcrumb cỡ 14', (t) async {
      await pump(t, host(data: json()));
      final chevron = t.widget<Icon>(find.byIcon(Icons.chevron_right_rounded));
      expect(chevron.size, 14);
    });

    tw('tiêu đề: ô 26 thẳng mép thân, chữ bắt đầu ở +38 (bố cục thật)', (
      t,
    ) async {
      await pump(t, host(data: json()));
      final body = t.getTopLeft(find.byKey(const ValueKey('crumb-plan'))).dx;
      final box = t.getTopLeft(find.byKey(const ValueKey('title-tick-box'))).dx;
      final title = t.getRect(find.byKey(const ValueKey('detail-title')));
      expect(box, body);
      expect(title.left - body, 38);
      // Vùng chạm của ô vẫn 44.
      expect(
        t.getSize(find.bySemanticsLabel('Đánh dấu xong')),
        const Size(44, 44),
      );
    });

    tw('header: cuộn xuống rồi cuộn ngược lên thì tên về mờ 0', (t) async {
      await pump(t, host(data: json(description: 'x\n' * 40)));
      AnimatedOpacity headerTitle() => t.widget<AnimatedOpacity>(
        find.ancestor(
          of: find.byKey(const ValueKey('header-title')),
          matching: find.byType(AnimatedOpacity),
        ),
      );
      await t.drag(find.byType(CustomScrollView), const Offset(0, -300));
      await t.pumpAndSettle();
      expect(headerTitle().opacity, 1);
      await t.drag(find.byType(CustomScrollView), const Offset(0, 300));
      await t.pumpAndSettle();
      expect(headerTitle().opacity, 0);
    });

    tw('giảm chuyển động: tên trên header đổi tức thì (Duration.zero)', (
      t,
    ) async {
      await pump(t, host(data: json(), reduceMotion: true));
      final fade = t.widget<AnimatedOpacity>(
        find.ancestor(
          of: find.byKey(const ValueKey('header-title')),
          matching: find.byType(AnimatedOpacity),
        ),
      );
      expect(fade.duration, Duration.zero);
    });

    tw('clipboard ném lỗi: báo "Không chép được mô tả."', (t) async {
      await pump(t, host(data: json(description: 'Quy trình')));
      t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async => call.method == 'Clipboard.setData'
            ? throw PlatformException(code: 'denied')
            : null,
      );
      await t.tap(find.byTooltip('Sao chép mô tả'));
      await t.pumpAndSettle();
      expect(find.text('Không chép được mô tả.'), findsOneWidget);
      expect(find.text('Đã chép mô tả.'), findsNothing);
    });
  });
}

/// Ghi lại mọi lượt ghi; trạng thái/thích đổi như server trả về.
class _Detail extends TaskController {
  _Detail(this._state, this._saved);

  final TaskDetailState _state;
  final List<(String, Object?)> _saved;
  Object? statusError;

  @override
  Future<TaskDetailState> build(String taskId) async => _state;

  void _set(Task task) {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(current.copyWith(task: task));
  }

  Task get _task => state.valueOrNull!.task;

  @override
  Future<void> setStatus(String status) async {
    _saved.add(('status', status));
    if (statusError case final e?) throw e;
    _set(_task.copyWith(status: status));
  }

  @override
  Future<void> setLabels(List<String> labels) async {
    _saved.add(('labels', labels));
    _set(_task.copyWith(labels: labels));
  }

  @override
  Future<void> toggleLike(String userId) async {
    _saved.add(('like', userId));
    _set(_task.copyWith(likes: [..._task.likes, userId]));
  }

  @override
  Future<void> setRating(int rating) async => _saved.add(('rating', rating));

  @override
  Future<void> setStartDate(DateTime? startDate) async =>
      _saved.add(('start', startDate));

  @override
  Future<void> setDueDate(DateTime? dueDate) async =>
      _saved.add(('due', dueDate));

  @override
  Future<void> setPriority(String priority) async =>
      _saved.add(('priority', priority));

  @override
  Future<void> moveToSection(String? sectionId) async =>
      _saved.add(('section', sectionId));

  @override
  Future<void> claimSelf(String userId) async => _saved.add(('claim', userId));

  @override
  Future<void> setTitle(String title) async => _saved.add(('title', title));

  @override
  Future<void> setDescription(String description) async =>
      _saved.add(('description', description));

  @override
  Future<void> setAssignees(List<String> userIds) async =>
      _saved.add(('assign', userIds));
}
