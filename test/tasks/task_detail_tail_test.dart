import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:omni_app/core/error/app_exception.dart';
import 'package:omni_app/design/theme/omni_theme.dart';
import 'package:omni_app/modules/tasks/application/task_controller.dart';
import 'package:omni_app/modules/tasks/application/tasks_providers.dart';
import 'package:omni_app/modules/tasks/domain/task.dart';
import 'package:omni_app/modules/tasks/domain/task_permissions.dart';
import 'package:omni_app/modules/tasks/presentation/task_detail_page.dart';
import 'package:omni_app/security/permissions/access_policy.dart';
import 'package:omni_app/security/session/session.dart';
import 'package:omni_app/security/session/session_controller.dart';

/// Nửa dưới màn chi tiết việc (GĐ5 Task 7): Điểm kiểm tra + Tệp, Trao đổi,
/// Nhật ký gập, thanh đáy.
void main() {
  setUpAll(() => initializeDateFormatting('vi_VN'));

  const worker = {'tasks.read', 'tasks.write'};
  const assigner = {'tasks.read', 'tasks.write', 'tasks.projects.manage.all'};

  late List<(String, Object?)> recorded;
  late _TailDetail stub;

  /// testWidgets có bật ngữ nghĩa: `bySemanticsLabel` cần nó, và tay cầm phải
  /// trả TRƯỚC khi test kết thúc (addTearDown chạy quá muộn).
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

  Task task({
    String status = 'todo',
    int attachments = 0,
    List<String> viewers = const [],
    int activity = 0,
    int rating = 0,
    bool images = true,
  }) => Task.fromJson({
    'id': 't1',
    'title': 'Lên dây đàn U3',
    'status': status,
    'rating': rating,
    'checklist': <Map<String, dynamic>>[],
    'attachments': [
      for (var i = 0; i < attachments; i++)
        {
          'id': 'a$i',
          'name': 'anh-$i.jpg',
          'url': 'https://api.local/m/$i.jpg',
          'type': images ? 'image' : 'file',
        },
    ],
    'viewers': [
      for (final v in viewers) {'user_id': 'u-$v', 'name': v},
    ],
    'activity': [
      for (var i = 0; i < activity; i++)
        {'id': 'ac$i', 'type': 'created', 'user_name': 'Người $i'},
    ],
  });

  Widget host({
    required Task task,
    required Set<String> perms,
    bool reduceMotion = false,
    Object? statusError,
  }) {
    recorded = [];
    stub = _TailDetail(TaskDetailState(task: task), recorded)
      ..statusError = statusError;

    return ProviderScope(
      overrides: [
        taskDetailProvider.overrideWith(() => stub),
        taskAccessProvider.overrideWithValue(
          TaskAccess.of(AccessPolicy(perms)),
        ),
        sessionProvider.overrideWithValue(
          const Session(
            status: SessionStatus.authenticated,
            user: SessionUser(id: 'u9', fullName: 'Thợ Hùng', email: 'h@t.vn'),
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

    // Rung phản hồi là kênh nền tảng; không giả thì lời gọi treo mãi.
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async => null,
    );
    await t.pumpWidget(app);
    await t.pumpAndSettle();
  }

  tw('tiêu đề khối: ĐIỂM KIỂM TRA, TỆP ĐÍNH KÈM (3), TRAO ĐỔI + Đã xem', (
    t,
  ) async {
    await pump(
      t,
      host(
        task: task(attachments: 3, viewers: ['Lan', 'Tuấn']),
        perms: assigner,
      ),
    );
    expect(find.text('ĐIỂM KIỂM TRA'), findsOneWidget);
    expect(find.text('TỆP ĐÍNH KÈM (3)'), findsOneWidget);
    expect(find.text('TRAO ĐỔI'), findsOneWidget);
    expect(find.text('Đã xem'), findsOneWidget);
  });

  tw('chấm 4 sao (người giao việc) → setRating(4)', (t) async {
    await pump(t, host(task: task(), perms: assigner));
    final star = find.bySemanticsLabel('4 điểm');
    await t.ensureVisible(star);
    await t.pumpAndSettle();
    await t.tap(star);
    await t.pumpAndSettle();
    expect(recorded.last, ('rating', 4));
  });

  tw('người làm thấy sao chỉ đọc, chạm không ghi gì', (t) async {
    await pump(t, host(task: task(rating: 3), perms: worker));
    expect(find.text('ĐIỂM KIỂM TRA'), findsOneWidget);
    expect(find.text('3/5'), findsOneWidget);
    final star = find.bySemanticsLabel('4 điểm');
    await t.ensureVisible(star);
    await t.tap(star, warnIfMissed: false);
    await t.pumpAndSettle();
    expect(recorded.where((r) => r.$1 == 'rating'), isEmpty);
  });

  tw('chưa chấm và không được chấm: không có khối điểm', (t) async {
    await pump(t, host(task: task(), perms: worker));
    expect(find.text('ĐIỂM KIỂM TRA'), findsNothing);
    // Khối tệp vẫn ở đó, nói rõ chưa có.
    expect(find.text('Chưa có tệp'), findsOneWidget);
  });

  tw('hơn 3 tệp: ô thứ ba ghi "+n"', (t) async {
    await pump(t, host(task: task(attachments: 5), perms: worker));
    expect(find.text('TỆP ĐÍNH KÈM (5)'), findsOneWidget);
    expect(find.text('+2'), findsOneWidget);
  });

  tw('chạm "+n" mở danh sách đủ mọi tệp', (t) async {
    await pump(
      t,
      host(task: task(attachments: 5, images: false), perms: worker),
    );
    expect(find.text('anh-4.jpg'), findsNothing);
    await t.tap(find.text('+2'));
    await t.pumpAndSettle();
    expect(find.text('anh-4.jpg'), findsOneWidget);
  });

  tw('nút Gửi vô hiệu khi trống, gửi khi có chữ', (t) async {
    await pump(t, host(task: task(), perms: worker));
    final send = find.widgetWithText(FilledButton, 'Gửi');
    await t.ensureVisible(send);
    expect(t.widget<FilledButton>(send).onPressed, isNull);
    await t.enterText(
      find.widgetWithText(TextField, 'Viết trao đổi… (@ để nhắc tên)'),
      'Xong búa La 4',
    );
    await t.pump();
    expect(t.widget<FilledButton>(send).onPressed, isNotNull);
    await t.tap(send);
    await t.pumpAndSettle();
    expect(recorded.last, ('comment', 'Xong búa La 4'));
  });

  tw('Nhật ký gập mặc định, chạm mở', (t) async {
    await pump(t, host(task: task(activity: 3), perms: worker));
    final head = find.text('NHẬT KÝ (3)');
    expect(head, findsOneWidget);
    expect(find.textContaining('tạo việc'), findsNothing);
    await t.ensureVisible(head);
    await t.tap(head);
    await t.pumpAndSettle();
    expect(find.textContaining('tạo việc'), findsWidgets);
  });

  tw('không có dòng nhật ký thì ẩn', (t) async {
    await pump(t, host(task: task(), perms: worker));
    expect(find.textContaining('NHẬT KÝ'), findsNothing);
  });

  tw('Hoàn thành → toast báo quản lý; đã xong → Mở lại', (t) async {
    await pump(
      t,
      host(
        task: task(status: 'todo'),
        perms: worker,
      ),
    );
    await t.tap(find.text('Hoàn thành công việc'));
    await t.pumpAndSettle();
    expect(
      find.text('Đã báo hoàn thành. Quản lý sẽ nhận thông báo.'),
      findsOneWidget,
    );
    expect(find.text('Mở lại công việc'), findsOneWidget);
  });

  tw('Mở lại → toast "Đã mở lại công việc."', (t) async {
    await pump(
      t,
      host(
        task: task(status: 'done'),
        perms: worker,
      ),
    );
    await t.tap(find.text('Mở lại công việc'));
    await t.pumpAndSettle();
    expect(find.text('Đã mở lại công việc.'), findsOneWidget);
    expect(find.text('Hoàn thành công việc'), findsOneWidget);
  });

  tw('mất mạng khi hoàn thành → giữ thông báo lỗi cũ', (t) async {
    await pump(
      t,
      host(
        task: task(),
        perms: worker,
        statusError: const NetworkException('Không có kết nối mạng.'),
      ),
    );
    await t.tap(find.text('Hoàn thành công việc'));
    await t.pumpAndSettle();
    expect(
      find.text('Chưa lưu được. Kiểm tra mạng rồi thử lại.'),
      findsOneWidget,
    );
    expect(find.textContaining('Đã báo hoàn thành'), findsNothing);
  });

  tw('giảm chuyển động: mở Nhật ký không để lại hoạt ảnh', (t) async {
    await pump(
      t,
      host(task: task(activity: 2), perms: worker, reduceMotion: true),
    );
    final head = find.text('NHẬT KÝ (2)');
    await t.ensureVisible(head);
    await t.tap(head);
    await t.pump();
    expect(t.hasRunningAnimations, isFalse);
  });

  tw('nút máy ảnh và nút chính cao ≥ 44', (t) async {
    await pump(t, host(task: task(), perms: worker));
    expect(
      t.getSize(find.bySemanticsLabel('Chụp ảnh')).height,
      greaterThanOrEqualTo(44),
    );
    expect(
      t
          .getSize(
            find
                .ancestor(
                  of: find.text('Hoàn thành công việc'),
                  matching: find.byType(InkWell),
                )
                .first,
          )
          .height,
      greaterThanOrEqualTo(44),
    );
  });

  tw('nút máy ảnh mở menu Chụp ảnh / Chọn ảnh có sẵn', (t) async {
    await pump(t, host(task: task(), perms: worker));
    await t.tap(find.bySemanticsLabel('Chụp ảnh'));
    await t.pumpAndSettle();
    expect(find.text('Chụp ảnh'), findsOneWidget);
    expect(find.text('Chọn ảnh có sẵn'), findsOneWidget);
  });
}

class _TailDetail extends TaskController {
  _TailDetail(this._state, this._saved);

  final TaskDetailState _state;
  final List<(String, Object?)> _saved;
  Object? statusError;

  @override
  Future<TaskDetailState> build(String taskId) async => _state;

  @override
  Future<void> setRating(int rating) async => _saved.add(('rating', rating));

  @override
  Future<void> comment(
    String body, {
    List<String> mentionedUserIds = const [],
  }) async => _saved.add(('comment', body));

  @override
  Future<void> setStatus(String status) async {
    _saved.add(('status', status));
    if (statusError case final e?) throw e;
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(task: current.task.copyWith(status: status)),
    );
  }
}
