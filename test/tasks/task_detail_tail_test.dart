import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:omni_app/security/session/session.dart';
import 'package:omni_app/security/session/session_controller.dart';

/// Nửa dưới màn chi tiết việc (Việc mới Task 9): thẻ Tệp, Bình luận,
/// Nhật ký, ô bình luận đáy.
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

  Future<void> pump(WidgetTester t, Widget app, {double width = 390}) async {
    t.view.physicalSize = Size(width, 844);
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

  tw('đầu thẻ: Tệp đính kèm + số, Bình luận, Đã xem việc này', (t) async {
    await pump(
      t,
      host(
        task: task(attachments: 3, viewers: ['Lan', 'Tuấn']),
        perms: assigner,
      ),
    );
    expect(find.text('Tệp đính kèm'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('Bình luận'), findsOneWidget);
    expect(find.text('Đã xem việc này'), findsOneWidget);
  });

  tw('chưa có tệp: thẻ tệp vẫn ở đó, nói rõ', (t) async {
    await pump(t, host(task: task(), perms: worker));
    expect(find.text('Chưa có tệp'), findsOneWidget);
  });

  tw('5 tệp: hiện đủ cả 5 ô 72, không cắt "+n"', (t) async {
    await pump(
      t,
      host(task: task(attachments: 5, images: false), perms: worker),
    );
    expect(find.text('anh-4.jpg'), findsOneWidget);
    expect(find.text('+2'), findsNothing);
    expect(
      t.getSize(find.byKey(const ValueKey('file-a0'))),
      const Size(72, 72),
    );
  });

  tw('nút Gửi bình luận vô hiệu khi trống, gửi khi có chữ', (t) async {
    await pump(t, host(task: task(), perms: worker));
    final send = find.widgetWithIcon(IconButton, Icons.send_rounded);
    expect(t.widget<IconButton>(send).onPressed, isNull);
    await t.enterText(
      find.widgetWithText(TextField, 'Bình luận, @ để nhắc tên'),
      'Xong búa La 4',
    );
    await t.pump();
    expect(t.widget<IconButton>(send).onPressed, isNotNull);
    await t.tap(send);
    await t.pumpAndSettle();
    expect(recorded.last, ('comment', 'Xong búa La 4'));
  });

  tw('Nhật ký: chưa bày ra, "Xem" mở sheet đủ dòng', (t) async {
    await pump(t, host(task: task(activity: 3), perms: worker));
    expect(find.text('Nhật ký hoạt động'), findsOneWidget);
    expect(find.textContaining('tạo việc'), findsNothing);
    final open = find.bySemanticsLabel('Xem nhật ký hoạt động');
    await t.ensureVisible(open);
    await t.tap(open);
    await t.pumpAndSettle();
    expect(find.text('Nhật ký hoạt động (3)'), findsOneWidget);
    expect(find.textContaining('tạo việc'), findsNWidgets(3));
  });

  tw('không có dòng nhật ký và chưa ai xem thì ẩn cả thẻ', (t) async {
    await pump(t, host(task: task(), perms: worker));
    expect(find.text('Nhật ký hoạt động'), findsNothing);
  });

  tw('giảm chuyển động: mở Nhật ký không để lại hoạt ảnh', (t) async {
    await pump(
      t,
      host(task: task(activity: 2), perms: worker, reduceMotion: true),
    );
    final open = find.bySemanticsLabel('Xem nhật ký hoạt động');
    await t.ensureVisible(open);
    await t.tap(open);
    await t.pump();
    expect(t.hasRunningAnimations, isFalse);
  });

  tw('"Tải tệp lên" 44 mở menu Chụp ảnh / Chọn ảnh có sẵn', (t) async {
    await pump(t, host(task: task(), perms: worker));
    final upload = find.byTooltip('Tải tệp lên');
    expect(t.getSize(upload), const Size(44, 44));
    await t.tap(upload);
    await t.pumpAndSettle();
    expect(
      find.byKey(const Key('task-attachment-source-menu')),
      findsOneWidget,
    );
    expect(find.text('Chụp ảnh'), findsOneWidget);
    expect(find.text('Chọn ảnh có sẵn'), findsOneWidget);
  });

  tw('chỉ đọc: không có "Tải tệp lên", không có ô bình luận đáy', (t) async {
    await pump(t, host(task: task(), perms: {'tasks.read'}));
    expect(find.byTooltip('Tải tệp lên'), findsNothing);
    expect(find.byKey(const ValueKey('comment-bar')), findsNothing);
  });

  for (final width in [360.0, 390.0]) {
    tw('rộng $width: đủ 5 sao trong màn, thấy "3/5 · 0 lượt"', (t) async {
      await pump(
        t,
        host(task: task(rating: 3), perms: assigner),
        width: width,
      );
      for (var n = 1; n <= 5; n++) {
        final r = t.getRect(find.bySemanticsLabel('$n sao'));
        expect(r.left, greaterThanOrEqualTo(0), reason: '$n sao');
        expect(r.right, lessThanOrEqualTo(width), reason: '$n sao');
        // Bản mẫu: sao 30×44 liền nhau (plan Việc mới, Global Constraints).
        expect(r.height, greaterThanOrEqualTo(44));
      }
      final label = t.getRect(find.text('3/5 · 0 lượt'));
      expect(label.right, lessThanOrEqualTo(width));
      expect(
        t.getRect(find.bySemanticsLabel('5 sao')).right,
        lessThanOrEqualTo(label.left),
      );
    });

    tw('rộng $width: ô tệp >= 44 và ảnh mang nhãn là tên tệp', (t) async {
      await pump(
        t,
        host(task: task(attachments: 3), perms: worker),
        width: width,
      );
      final tile = find.bySemanticsLabel('anh-0.jpg');
      await t.ensureVisible(tile);
      await t.pumpAndSettle();
      expect(tile, findsOneWidget);
      final s = t.getSize(tile);
      expect(s.width, greaterThanOrEqualTo(44));
      expect(s.height, greaterThanOrEqualTo(44));
    });
  }

  tw('bàn phím mở: ô bình luận sát bàn phím, không chừa thêm khoảng home', (
    t,
  ) async {
    await pump(t, host(task: task(), perms: worker));
    t.view.viewPadding = const FakeViewPadding(bottom: 34);
    t.view.padding = const FakeViewPadding(bottom: 34);
    await t.pumpAndSettle();
    final send = find.byTooltip('Gửi bình luận');
    final withHome = t.getRect(send).bottom;
    expect(844 - withHome, greaterThanOrEqualTo(34), reason: 'có thanh home');

    // Nền tảng báo padding đã trừ phần bàn phím che; viewPadding thì không.
    t.view.viewInsets = const FakeViewPadding(bottom: 300);
    t.view.padding = FakeViewPadding.zero;
    await t.pumpAndSettle();
    // 844 - bàn phím 300 = đáy thân; nút cách đáy đúng đệm 8.
    expect(544 - t.getRect(send).bottom, closeTo(8, 1.01));
  });

  tw('ô bình luận đáy: nền .82, KHÔNG BackdropFilter, không TaskActionBar', (
    t,
  ) async {
    await pump(t, host(task: task(), perms: worker));
    // Bỏ blur (rà soát Task 9): một BackdropFilter cố định đáy dựng lại lớp
    // mờ mỗi khung cuộn. Nền .82 vẫn che chữ cuộn bên dưới.
    expect(
      find.ancestor(
        of: find.byKey(const ValueKey('comment-bar')),
        matching: find.byType(BackdropFilter),
      ),
      findsNothing,
    );
    final bar = t.widget<DecoratedBox>(
      find.byKey(const ValueKey('comment-bar')),
    );
    expect((bar.decoration as BoxDecoration).color!.a, closeTo(0.82, 0.01));
    expect(find.bySemanticsLabel('Chụp ảnh'), findsNothing);
    // Nhóm 2: nút ảnh đính kèm bình luận chưa có khoá API.
    expect(find.byTooltip('Đính kèm ảnh hoặc tệp'), findsNothing);
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
